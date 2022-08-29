#!/bin/bash
# Move to the same directory as this script
cd "$(dirname "${BASH_SOURCE[0]}")"

set -e
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root.'
    exit 1
fi

# Import common utils
. ./utils.sh

# Verify pre-reqs
check_command curl curl ca-certificates
check_command gpg gnupg2
check_command dirmngr dirmngr
check_packages apt-transport-https

# Install Chrome
if ! type google-chrome > /dev/null 2>&1; then
    echo "Installing Google Chrome..."
    apt-get update
    curl -sSL "https://dl.google.com/linux/direct/google-chrome-stable_current_$(dpkg --print-architecture).deb" -o /tmp/chrome.deb
    apt-get -y install /tmp/chrome.deb
    rm -f /tmp/chrome.deb
fi

echo "Done!"