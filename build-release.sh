#!/bin/zsh
# Copyright 2026 FreeDial contributors. Licensed under the Apache License, Version 2.0.
#
# Build a universal (Apple silicon + Intel) FreeDial.app and package it for a release.
# Needs the Xcode command line tools. Writes dist/FreeDial.zip and dist/FreeDial.zip.sha256.
set -eu
here=${0:A:h}
version=$(<"$here/VERSION")
work=$here/build
dist=$here/dist

rm -rf "$work" "$dist"
mkdir -p "$work" "$dist"

for arch in arm64 x86_64; do
  echo "Compiling $arch..."
  swiftc -O -target $arch-apple-macos12.0 "$here/src/main.swift" -o "$work/FreeDial-$arch"
done
lipo -create -output "$work/FreeDial" "$work/FreeDial-arm64" "$work/FreeDial-x86_64"

"$here/scripts/assemble-app.sh" "$work/FreeDial" "$work" "$version"

# ditto keeps the bundle's signature and metadata intact inside the zip.
ditto -c -k --keepParent "$work/FreeDial.app" "$dist/FreeDial.zip"
(cd "$dist" && shasum -a 256 FreeDial.zip > FreeDial.zip.sha256)

echo "Built FreeDial $version:"
lipo -archs "$work/FreeDial.app/Contents/MacOS/FreeDial"
cat "$dist/FreeDial.zip.sha256"
