#!/bin/bash
set -e

# Perform single-user install since daemon has to run as root, and this is not always possible
sh "$1/install-nix" --no-daemon --no-modify-profile

# Execute installation steps as non-root user so privs are correct if daemon not used
. $HOME/.nix-profile/etc/profile.d/nix.sh

# Install list of packages in profile if specified.
if [ ! -z "${PACKAGES}" ] && [ "${PACKAGES}" != "none" ]; then
    nix-env --install ${PACKAGES}
fi

# Install deriviation (blah.nix) in profile if specified
if [ ! -z "${DERIVATIONPATH}" ] && [ "${DERIVATIONPATH}" != "none" ]; then
    if [ ! -e "${DERIVATIONPATH}" ]; then
        echo "The file ${DERIVATIONPATH} does not exist! Skipping.."
    else 
            nix-env -f "${DERIVATIONPATH}" -i
    fi
fi

# Install Nix flake in profile if specified
if [ ! -z "${FLAKEURI}" ] && [ "${FLAKEURI}" != "none" ]; then
    nix profile install "${FLAKEURI}"
fi

nix-collect-garbage --delete-old
nix-store --optimise
