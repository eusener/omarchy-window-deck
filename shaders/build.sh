#!/usr/bin/env bash
# Compiles the Window Deck shaders. Needs qt6-shadertools (qsb) only to build;
# the .qsb files are committed so the plugin runs without it.
set -euo pipefail
cd "$(dirname "$0")"
qsb=/usr/lib/qt6/bin/qsb
for src in *.frag; do
  "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$src.qsb" "$src"
done
