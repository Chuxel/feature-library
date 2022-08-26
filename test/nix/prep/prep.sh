#!/bin/bash
set -e
cd "$(dirname ${BASH_SOURCE[0]})"
docker build -f Dockerfile --target root-with-sudo -t root-with-sudo .
docker build -f Dockerfile --target root-without-sudo -t root-without-sudo .
docker build -f Dockerfile --target nonroot-with-sudo -t nonroot-with-sudo .
docker build -f Dockerfile --target nonroot-without-sudo -t nonroot-without-sudo .