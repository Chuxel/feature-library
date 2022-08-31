#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")"

set -e
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root.'
    exit 1
fi

# Import common utils
. ./utils.sh

check_command curl curl ca-certificates
check_command gpg gnupg2
check_command dirmngr dirmngr
check_packages apt-transport-https

pgpkg_name="postgresql"
if [ "${CLIENTONLY}" = "true" ]; then
    if type psql >/dev/null 2>&1; then
        echo "PostgreSQL client is already installed. Skipping."
        exit 0
    fi
    pgpkg_name="postgresql-client"
else
    if type pg_lsclusters >/dev/null 2>&1; then
        echo "PostgreSQL is already installed. Skipping."
        exit 0
    fi
fi
if [ "${VERSION}" != "latest" ]; then
    apt_cache_version_soft_match version "${pgpkg_name}"
    pgpkg_name="${pgpkg_name}=${version}"
fi

. /etc/os-release
curl -sSLf https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/postgresql.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install -y "${pgpkg_name}"

echo "Done!"