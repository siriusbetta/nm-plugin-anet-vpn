#!/bin/bash

cd plasma-nm
git checkout master 
cd ..

mkdir -p ~/tmp-build
TMPDIR=~/tmp-build podman build -f Containerfile-arch -t kde-arch-dev .

TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-arch-dev \
  sh -c "rm -rf build && cmake -B build && cmake --build build"

cd plasma-nm
git switch -
cd ..
