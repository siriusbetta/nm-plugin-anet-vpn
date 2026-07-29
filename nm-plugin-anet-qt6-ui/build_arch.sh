#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PLASMA_NM_DIR="$SCRIPT_DIR/plasma-nm"
TMPDIR_VALUE=${TMPDIR:-$HOME/tmp-build}

original_commit=$(git -C "$PLASMA_NM_DIR" rev-parse HEAD)
original_branch=$(git -C "$PLASMA_NM_DIR" symbolic-ref --quiet --short HEAD || true)

restore_plasma_nm()
{
  if [ -n "$original_branch" ]; then
    git -C "$PLASMA_NM_DIR" checkout "$original_branch"
  else
    git -C "$PLASMA_NM_DIR" checkout --detach "$original_commit"
  fi
}
trap restore_plasma_nm EXIT

git -C "$PLASMA_NM_DIR" checkout master

mkdir -p "$TMPDIR_VALUE"

TMPDIR="$TMPDIR_VALUE" podman build \
  -f "$SCRIPT_DIR/Containerfile-arch" \
  -t kde-arch-dev \
  "$SCRIPT_DIR"

image_os_id="$(
  podman run --rm --network=none kde-arch-dev \
    sh -c '. /etc/os-release && printf "%s" "$ID"'
)"
if [ "$image_os_id" != "arch" ]; then
  printf 'Unexpected builder OS: %s (expected arch)\n' "$image_os_id" >&2
  exit 1
fi

TMPDIR="$TMPDIR_VALUE" podman run --rm \
  -v "$SCRIPT_DIR:/src:Z" \
  kde-arch-dev \
  sh -c "rm -rf build && cmake -B build && cmake --build build"
