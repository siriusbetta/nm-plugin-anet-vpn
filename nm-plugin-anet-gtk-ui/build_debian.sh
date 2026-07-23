#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

TMPDIR_VALUE=${TMPDIR:-$HOME/tmp-build}
mkdir -p "$TMPDIR_VALUE"

podman build \
    -f Containerfile-debian \
    -t anet-gtk-debian-dev .

podman run --rm \
    -v "$SCRIPT_DIR:/src:Z" \
    anet-gtk-debian-dev \
    sh -c 'rm -rf build && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j2'
