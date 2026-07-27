#!/bin/bash

cd plasma-nm
git checkout master 
cd ..

mkdir -p ~/tmp-build

TMPDIR=~/tmp-build podman build -f Containerfile-arch -t kde-arch-dev .

image_os_id="$(
  podman run --rm --network=none kde-arch-dev \
    sh -c '. /etc/os-release && printf "%s" "$ID"'
)"
if [ "$image_os_id" != "arch" ]; then
  printf 'Unexpected builder OS: %s (expected arch)\n' "$image_os_id" >&2
  exit 1
fi

TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-arch-dev \
  sh -c "rm -rf build && cmake -B build && cmake --build build"

cd plasma-nm
git switch -
cd ..
