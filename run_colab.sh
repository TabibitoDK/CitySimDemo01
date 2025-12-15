#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_colab.sh /content/CitySimDemo01

CASE_DIR="${1:-/content/CitySimDemo01}"

if [ ! -d "$CASE_DIR/system" ] || [ ! -f "$CASE_DIR/system/blockMeshDict" ]; then
  echo "Case not found at: $CASE_DIR" >&2
  exit 1
fi

source /opt/openfoam9/etc/bashrc
export FOAM_CASE="$CASE_DIR"

cd "$CASE_DIR"

surfaceFeatures -case "$CASE_DIR"
blockMesh -case "$CASE_DIR"
snappyHexMesh -overwrite -case "$CASE_DIR"
checkMesh -allTopology -allGeometry -case "$CASE_DIR"
simpleFoam -case "$CASE_DIR"
