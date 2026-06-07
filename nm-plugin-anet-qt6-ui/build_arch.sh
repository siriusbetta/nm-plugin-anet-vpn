#!/bin/bash

cd plasma-nm
git checkout master 
cd ..

mkdir -p ~/tmp-build
TMPDIR=~/tmp-build podman build --no-cache -f Containerfile-arch -t kde-arch-dev .

TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-arch-dev \
  sh -c "rm -rf build && cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ && cmake --build build"
#  sh -c "rm -rf build && cmake -B build && cmake --build build"
cd plasma-nm
git switch -
cd ..
