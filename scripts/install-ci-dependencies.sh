#!/usr/bin/env bash
set -euo pipefail

readonly POPPLER_VERSION="24.02.0-1ubuntu9.9"
readonly QPDF_VERSION="11.9.0-1.1build1"

sudo apt-get update
sudo apt-get install -y \
  "poppler-utils=${POPPLER_VERSION}" \
  "qpdf=${QPDF_VERSION}"
