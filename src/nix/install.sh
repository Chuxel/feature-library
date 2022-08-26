#!/bin/bash
set -e

VERSION="${VERSION:-"latest"}"
USERNAME="${USERNAME:-"automatic"}"
NIX_GPG_KEYS="B541D55301270E0BCF15CA5D8170B4726D7198DE"
GPG_KEY_SERVERS="keyserver hkp://keyserver.ubuntu.com:80
keyserver hkps://keys.openpgp.org
keyserver hkp://keyserver.pgp.com"

if [ -e "/nix" ]; then
    echo "(!) Nix is already installed! Aborting."
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Import common utils
. ./utils.sh

# Verify dependencies
check_command curl curl ca-certificates 
check_command gpg2 gnupg2
check_command dirmngr dirmngr
check_command xz xz-utils
check_command git git

# Determine version
find_version_from_git_tags VERSION https://github.com/NixOS/nix "tags/"

# Need a non-root user to install nix - create a dummy one if there's no non-root user
detect_user USERNAME
if [ "${USERNAME}" = "root" ]; then
    USERNAME=nix
    groupadd -g 40000 nix
    useradd -s /bin/bash -u 40000 -g 40000 -m nix
fi

# Create a nixuser group to help deal with UID/GID changes, make that the default group for the user we will install as
groupadd --system -r nixusers
original_group="$(id -g "${USERNAME}")"
original_uid="$(id -u "${USERNAME}")"
usermod -g nixusers "${USERNAME}"

# Adapted from https://nixos.org/download.html#nix-verify-installation
orig_cwd="$(pwd)"
mkdir -p /nix /tmp/nix
chown ${USERNAME} /nix
cd /tmp/nix
receive_gpg_keys NIX_GPG_KEYS
curl -sSLf -o ./install-nix https://releases.nixos.org/nix/nix-${VERSION}/install
curl -sSLf -o ./install-nix.asc https://releases.nixos.org/nix/nix-${VERSION}/install.asc
gpg2 --verify ./install-nix.asc
cd "${orig_cwd}"
# Install and post-install processing -- more complicated due to the need to support both root and non-root user
su ${USERNAME} -c "$(cat << EOF 
    set -e
    sh /tmp/nix/install-nix --no-daemon --no-modify-profile
    ln -s /nix/var/nix/profiles/per-user/${USERNAME}/profile /nix/var/nix/profiles/default

    . /home/${USERNAME}/.nix-profile/etc/profile.d/nix.sh
    if [ ! -z "${PACKAGES}" ] && [ "${PACKAGES}" != "none" ]; then
        nix-env --install ${PACKAGES//,/ }
    fi
    nix-collect-garbage --delete-old
    nix-store --optimise
EOF
)"
chown "${USERNAME}:nixusers" /nix
rm -rf /tmp/nix
# Restore default group we used to install 
usermod -a -G nixusers -g "${original_group}" "${USERNAME}"

# Set nix config
mkdir -p /etc/nix
cat << EOF >> /etc/nix/nix.conf
sandbox = false
trusted-users = ${USERNAME}
EOF

# Setup nixbld group, dir to allow root to function if preferred
if ! grep -e "^nixbld:" /etc/group > /dev/null 2>&1; then
    groupadd -g 30000 nixbld

fi
for i in $(seq 1 10); do
    nixbuild_user="nixbld${i}"
    if ! id "${nixbuild_user}" > /dev/null 2>&1; then
        useradd --system --home-dir /var/empty --gid 30000 --groups nixbld --no-user-group --shell /usr/sbin/nologin --uid $((30000 + i)) "${nixbuild_user}"
    fi
done

# Setup channels for root user to avoid conflicts, but link profile
cp -R /home/${USERNAME}/.nix-channels /home/${USERNAME}/.nix-defexpr /home/${USERNAME}/.nix-channels /root/
cp  /home/${USERNAME}/.nix-channels /root/.nix-channels
ln -s /nix/var/nix/profiles/default /root/.nix-profile

# Setup rcs and profiles to source nix script
snippet=' 
if [ "${PATH#*$HOME/.nix-profile/bin}" = "${PATH}" ]; then if [ -z "$USER" ]; then USER=$(whoami); fi; . /nix/var/nix/profiles/default/etc/profile.d/nix.sh; fi
'
update_rc_file /etc/bash.bashrc "${snippet}"
update_rc_file /etc/zsh/zshenv "${snippet}"
update_rc_file /etc/profile.d/nix.sh "${snippet}"
chmod +x /etc/profile.d/nix.sh

# Add optional entrypoint script to attempt to tweak privs for user nix profile if needed
# This is not ideal, but the only option w/o https://github.com/devcontainers/spec/issues/25
echo "Setting up entrypoint..."
cat << EOF > /usr/local/share/nix-init.sh
#!/bin/bash
# Nix is very picky about privs under /nix/var, so make sure they are correct in the event the 
# user's UID changes. The group privs should be enough for the contents of /nix/store, but update other dirs
if [ "\$(stat -c '%U' /nix/var/nix/profiles/per-user/${USERNAME})" != "${USERNAME}" ]; then
    if [ "\$(id -u)" = "0" ]; then
        chown ${USERNAME} /nix /nix/store /nix/store/.links
        find /nix/var -uid ${original_uid} -execdir chown ${USERNAME} "{}" \+ &
    elif type sudo > /dev/null 2>&1; then 
        sudo chown ${USERNAME} /nix /nix/store /nix/store/.links
        sudo find /nix/var -uid ${original_uid} -execdir chown ${USERNAME} "{}" \+ &
    else
        echo "WARNING: Unable to change nix profile privledges for ${USERNAME}. Try running the container as root."
    fi
fi
exec "\$@"
EOF
chmod +x /usr/local/share/nix-init.sh

echo "Done!"