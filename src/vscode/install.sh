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
check_command gpg gnupg2
check_command dirmngr dirmngr
check_packages apt-transport-https

curl -sSL ${MICROSOFT_GPG_KEYS_URI} | gpg --dearmor > /usr/share/keyrings/microsoft-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update

# Install VS Code
to_install=""
if [ "${VSCODEEDITION}" != "insiders" ] && [ ! -e /usr/local/code ]; then
    to_install="code"
fi

if [ "${VSCODEEDITION}" != "stable" ]&& [ ! -e /usr/local/code-insiders ]; ; then
    to_install="${to_install} code-insiders"
fi
apt-get -y install ${to_install}

echo "Done!"