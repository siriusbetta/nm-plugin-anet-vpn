#!/bin/bash

cd plasma-nm
git checkout v6.3.4
cd ..

mkdir -p ~/tmp-build
TMPDIR=~/tmp-build podman build -f Containerfile-debian -t kde-debian-dev .

TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-debian-dev \
  sh -c "rm -rf build && cmake -B build && cmake --build build"

cd plasma-nm
git switch -
cd ..
