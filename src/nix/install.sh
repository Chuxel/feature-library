#!/bin/bash
# Move to the same directory as this script
cd "$(dirname "${BASH_SOURCE[0]}")"

set -e

# Option defaults
VERSION="${VERSION:-"latest"}"
PACKAGES="${PACKAGES:-""}"
STARTDAEMON="${STARTDAEMON:-"true"}"
USERNAME="${USERNAME:-"automatic"}"

# Nix keys for securly verifying installer download signature
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
apt_get_update_if_exists
check_command curl "curl ca-certificates" "curl ca-certificates" "curl ca-certificates"
check_command gpg2 gnupg2 gnupg gnupg2
check_command dirmngr dirmngr dirmngr dirmngr
check_command xz xz-utils xz xz
check_command git git git git

# Determine version
find_version_from_git_tags VERSION https://github.com/NixOS/nix "tags/"

# Need a non-root user to install nix - create a dummy one if there's no non-root user
detect_user USERNAME
if [ "${USERNAME}" = "root" ]; then
    USERNAME=nix
    groupadd -g 40000 nix
    useradd -s /bin/bash -u 40000 -g 40000 -m nix
fi

# Create a nix-user group to narrow down which users will be able to access nix.
# See https://nixos.org/manual/nix/stable/installation/single-user.html#single-user-mode
# and https://nixos.org/manual/nix/stable/installation/multi-user.html#restricting-access
groupadd --system -r nix-users
# Create nix dir per https://nixos.org/manual/nix/stable/installation/installing-binary.html#single-user-installation
mkdir /nix
chown ${USERNAME} /nix 
# Create temp dir owned by the non-root user
orig_cwd="$(pwd)"
tmpdir="$(su ${USERNAME} -c 'mktemp -d')"
cd "${tmpdir}"
# Download and verify install per https://nixos.org/download.html#nix-verify-installation
receive_gpg_keys NIX_GPG_KEYS
curl -sSLf -o ./install-nix https://releases.nixos.org/nix/nix-${VERSION}/install
curl -sSLf -o ./install-nix.asc https://releases.nixos.org/nix/nix-${VERSION}/install.asc
gpg2 --verify ./install-nix.asc
# Perform single-user install since multi-user fails w/o systemd.
original_group="$(id -g "${USERNAME}")"
usermod -g nix-users "${USERNAME}"
su ${USERNAME} -c "$(cat << EOF 
    set -e
    sh ./install-nix --no-daemon --no-modify-profile

    # Execute installation steps as non-root user so privs are correct if daemon not used
    . /home/${USERNAME}/.nix-profile/etc/profile.d/nix.sh
    if [ ! -z "${PACKAGES}" ] && [ "${PACKAGES}" != "none" ]; then
        nix-env --install ${PACKAGES}
    fi

    nix-collect-garbage --delete-old
    nix-store --optimise
EOF
)"
usermod -a -G nix-users -g "${original_group}" "${USERNAME}"
# Clean up
cd "${orig_cwd}"
rm -rf "${tmpdir}"

# Set nix config
mkdir -p /etc/nix
cat << EOF >> /etc/nix/nix.conf
sandbox = false
EOF

# Setup nixbld group, set socket security so we can use w/daemon if preferred - As dscribed in
# https://nixos.org/manual/nix/stable/installation/installing-binary.html#multi-user-installation 
# and https://nixos.org/manual/nix/stable/installation/multi-user.html
if ! grep -e "^nixbld:" /etc/group > /dev/null 2>&1; then
    groupadd -g 30000 nixbld

fi
for i in $(seq 1 32); do
    nixbuild_user="nixbld${i}"
    if ! id "${nixbuild_user}" > /dev/null 2>&1; then
        useradd --system --home-dir /var/empty --gid 30000 --groups nixbld --no-user-group --shell /usr/sbin/nologin --uid $((30000 + i)) "${nixbuild_user}"
    fi
done
mkdir -p /nix/var/nix/daemon-socket
chgrp nix-users /nix/var/nix/daemon-socket
chmod ug=rwx,o= /nix/var/nix/daemon-socket

# Setup default (root) profile, channel - use real profile path so next derivation created makes the profiles unique
ln -s "$(realpath /nix/var/nix/profiles/per-user/${USERNAME}/profile)" /nix/var/nix/profiles/default
cp -R /home/${USERNAME}/.nix-channels /home/${USERNAME}/.nix-defexpr /root/
ln -s /nix/var/nix/profiles/default /root/.nix-profile

# Setup rcs and profiles to source nix script - default path is set automatically by feature, so just need profile specific one
snippet='
if [ "${PATH#*$HOME/.nix-profile/bin}" = "${PATH}" ]; then if [ -z "$USER" ]; then USER=$(whoami); fi; . $HOME/.nix-profile/etc/profile.d/nix.sh; fi
'
update_rc_file /etc/bash.bashrc "${snippet}"
update_rc_file /etc/zsh/zshenv "${snippet}"
update_rc_file /etc/profile.d/nix.sh "${snippet}"
chmod +x /etc/profile.d/nix.sh

# Set up init script to attempt to start up the daemon and fall back on single user mode if all else
# fails. Using the daemon avoids problems if for some reason the user's UID hasn been changed to
# ensure bind mounts have proper permissions on Linux, but is otherwise optional in this case.
echo "Setting up entrypoint..."
if [ "${STARTDAEMON}" = "true" ]; then
cat << 'EOF' > /usr/local/share/nix-init.sh
#!/bin/bash
# Attempt to start daemon, but don't bomb if it fails - we'll assume single user mode then
set +e 
if ! pidof nix-daemon > /dev/null 2>&1; then
    if [ "$(id -u)" = "0" ]; then
        ( /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 ) &
    elif type sudo > /dev/null 2>&1; then
        ( sudo -n /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 ) &
    fi
fi
exec "$@"
EOF
else
cat << 'EOF' > /usr/local/share/nix-init.sh
#!/bin/bash
exec "$@"
EOF
fi
chmod +x /usr/local/share/nix-init.sh

echo "Done!"