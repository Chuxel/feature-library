#!/bin/bash
set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "nix-env" type nix-env
check "install" nix-env --install vim
check "vim_installed" type vim
check "node_installed" node --version
check "dotnet_installed" dotnet --version

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults