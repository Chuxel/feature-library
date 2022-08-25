#!/bin/bash
set -e
cd "$(dirname ${BASH_SOURCE[0]})"
docker build -f Dockerfile --target nonroot -t base-nonroot .
docker build -f Dockerfile --target root -t base-root .