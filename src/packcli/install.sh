#!/bin/bash
# Move to the same directory as this script
cd "$(dirname "${BASH_SOURCE[0]}")"

set -e
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root.'
    exit 1
fi

MICROSOFT_GPG_KEYS_URI="https://packages.microsoft.com/keys/microsoft.asc"

# Import common utils
. ./utils.sh

# Verify pre-reqs
check_command curl curl ca-certificates
check_command tar tar
check_command git git
check_command sha256sum coreutils

# Figure out the correct version to download
target_path="/usr/local"
pack_cli_version="${VERSION}"
repo_url="https://github.com/buildpacks/pack"
find_version_from_git_tags pack_cli_version "${repo_url}"

# Skip if already run with same args - handle caching
marker_path="${target_path}/etc/dev-container-features/markers/github.com/chuxel/devcontainer-features/${FEATURE_ID}-${SCRIPT_NAME}.marker"
if ! check_marker "${marker_path}" "${target_path}" "${pack_cli_version}"; then
    echo "Pack CLI ${pack_cli_version} already installed. Skipping..."
    exit 0
fi

echo "Downloading the Pack CLI..."
filename="pack-v${pack_cli_version}-linux.tgz"
dl_url="${repo_url}/releases/download/v${pack_cli_version}/${filename}"

mkdir -p /tmp/pack-cli "${target_path}/bin"
curl -sSL "${dl_url}" > /tmp/pack-cli/${filename}
curl -sSL "${dl_url}.sha256" > /tmp/pack-cli/${filename}.sha256
cd /tmp/pack-cli

sha256sum --ignore-missing -c "${filename}.sha256"
tar -f "${filename}" -C "${target_path}/bin" --no-same-owner -xzv pack

rm -rf /tmp/pack-cli

# Mark as complete
update_marker "${marker_path}" "${target_path}" "${pack_cli_version}"

echo "Done!"