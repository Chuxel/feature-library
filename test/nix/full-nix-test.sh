#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
set -e 
failed=""

run_test() {
    test=$1
    user=$2
    image=$3
    echo "*** ${test} ***"
    set +e
    if ! devcontainer features test -u ${user} -i ${image} .; then
        failed="${failed}${test}\n"
    fi
    set -e 
}

./test/nix/prep/prep.sh

run_test "Container as root w/o non-root user" root ubuntu
run_test "Container as root w/non-root user w/sudo" root root-with-sudo 
# Currently fails due to bug in test framework https://github.com/devcontainers/cli/issues/139
run_test "Container as root, remoteUser as vscode w/sudo" vscode root-with-sudo 
# Currently fails due to bug in test framework https://github.com/devcontainers/cli/issues/139
run_test "Container as root, remoteUser as vscode w/o sudo" vscode root-without-sudo 
# Currently fails due to bug in test framework https://github.com/devcontainers/cli/issues/139
run_test "Container as vscode, remoteUser as vscode w/sudo" vscode nonroot-with-sudo
# This scenario will fail due to https://github.com/devcontainers/spec/issues/25 not being available yet
#run_test "Container as vscode, remoteUser as vscode w/o sudo" vscode nonroot-without-sudo

if [ "${failed}" != "" ]; then
    echo -e "\n*** WARNING: At least one test failed ***\n${failed}"
    exit 1
fi

