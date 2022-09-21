#!/bin/bash
set -e
echo "(*) Executing post-installation steps..."

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
