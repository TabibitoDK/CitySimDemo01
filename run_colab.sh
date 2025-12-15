#!/usr/bin/env bash
set -eo pipefail

# Usage: ./run_colab.sh [/content/CitySimDemo01]
# If no argument is given, the script directory is used as the case root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_DIR="${1:-$SCRIPT_DIR}"

# Resolve common nesting issues: if blockMeshDict is not found at CASE_DIR,
# but is present one level deeper (e.g. CASE_DIR/CitySimDemo01/system), use that.
if [ ! -f "$CASE_DIR/system/blockMeshDict" ]; then
  if [ -d "$CASE_DIR/CitySimDemo01/system" ] && [ -f "$CASE_DIR/CitySimDemo01/system/blockMeshDict" ]; then
    CASE_DIR="$CASE_DIR/CitySimDemo01"
  fi
fi

if [ ! -f "$CASE_DIR/system/blockMeshDict" ]; then
  echo "Case not found: expected $CASE_DIR/system/blockMeshDict" >&2
  exit 1
fi

# Ensure geometry sits under constant/geometry; if user uploaded geometry at root, move it.
if [ ! -f "$CASE_DIR/constant/geometry/city_buildings.stl" ] && [ -f "$CASE_DIR/geometry/city_buildings.stl" ]; then
  mkdir -p "$CASE_DIR/constant/geometry"
  mv "$CASE_DIR/geometry/city_buildings.stl" "$CASE_DIR/constant/geometry/"
fi

(
  set +u
  source /opt/openfoam9/etc/bashrc
)
export FOAM_CASE="$CASE_DIR"

cd "$CASE_DIR"

surfaceFeatures -case "$CASE_DIR"
blockMesh -case "$CASE_DIR"
snappyHexMesh -overwrite -case "$CASE_DIR"
checkMesh -allTopology -allGeometry -case "$CASE_DIR"
simpleFoam -case "$CASE_DIR"
