#!/usr/bin/env bash

# Install the Google Cloud CLI (gcloud, bq, gsutil) from the package
# repository of Google. Runs as root while the dev container is built; the
# image is the Dockerfile of cloud-labs-local.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set -o errexit -o nounset -o pipefail
# apt-get must not ask questions while the image is built
export DEBIAN_FRONTEND=noninteractive

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# The signing key of the package repository, converted into the binary format
# that apt expects
curl --fail --silent --show-error --location https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
# A list file in sources.list.d adds the package repository; signed-by names the
# key for its packages
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg]" \
    "https://packages.cloud.google.com/apt cloud-sdk main" \
    >/etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update
# --no-install-recommends: only what the package really needs. Removing the
# package lists afterwards keeps the image small.
apt-get install --yes --no-install-recommends google-cloud-cli
rm --recursive --force /var/lib/apt/lists/*
