#!/bin/bash
# Attempt to start daemon, but don't bomb if it fails - we'll assume single user mode then
set +e 
if ! pidof nix-daemon > /dev/null 2>&1; then
    if [ "$(id -u)" = "0" ]; then
        ( . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 ) &
    elif type sudo > /dev/null 2>&1; then
        sudo -n sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1' &
    fi
fi
exec "$@"
