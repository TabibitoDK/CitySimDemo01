#!/usr/bin/env bash
set -eo pipefail

# Usage: ./run_colab.sh [/content/CitySimDemo01]
# If no argument is given, the script directory is used as the case root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_DIR="${1:-$SCRIPT_DIR}"

# Resolve common nesting issues.
if [ ! -f "$CASE_DIR/system/blockMeshDict" ]; then
  if [ -d "$CASE_DIR/CitySimDemo01/system" ] && [ -f "$CASE_DIR/CitySimDemo01/system/blockMeshDict" ]; then
    CASE_DIR="$CASE_DIR/CitySimDemo01"
  else
    # Try to auto-discover within one extra level.
    CANDIDATE="$(find "$CASE_DIR" -maxdepth 2 -type f -name blockMeshDict | head -n1 || true)"
    if [ -n "$CANDIDATE" ]; then
      CASE_DIR="$(cd "$(dirname "$CANDIDATE")/.." && pwd)"
    fi
  fi
fi

if [ ! -f "$CASE_DIR/system/blockMeshDict" ]; then
  echo "Case not found: expected $CASE_DIR/system/blockMeshDict" >&2
  exit 1
fi

echo "Using case: $CASE_DIR"
ls -l "$CASE_DIR/system" || true

# Ensure geometry sits under constant/geometry; if user uploaded geometry at root, move it.
if [ ! -f "$CASE_DIR/constant/geometry/city_buildings.stl" ] && [ -f "$CASE_DIR/geometry/city_buildings.stl" ]; then
  mkdir -p "$CASE_DIR/constant/geometry"
  mv "$CASE_DIR/geometry/city_buildings.stl" "$CASE_DIR/constant/geometry/"
fi

# Handle accidental double-nesting from some zip layouts: constant/geometry/constant/geometry/...
if [ ! -f "$CASE_DIR/constant/geometry/city_buildings.stl" ] && [ -f "$CASE_DIR/constant/geometry/constant/geometry/city_buildings.stl" ]; then
  mkdir -p "$CASE_DIR/constant/geometry"
  mv "$CASE_DIR/constant/geometry/constant/geometry/city_buildings.stl" "$CASE_DIR/constant/geometry/"
fi

if [ ! -f /opt/openfoam9/etc/bashrc ]; then
  echo "OpenFOAM not installed at /opt/openfoam9. Please install openfoam9 first." >&2
  exit 1
fi

(
  set +u
  source /opt/openfoam9/etc/bashrc
)
export FOAM_CASE="$CASE_DIR"

cd "$CASE_DIR"

if [ "${NO_LAYERS:-0}" = "1" ]; then
  echo "NO_LAYERS=1: disabling snappyHexMesh layers (addLayers false;)"
  # Keep it simple: flip the top-level addLayers switch.
  sed -i -E 's/^(addLayers[[:space:]]+)true;/\\1false;/' "$CASE_DIR/system/snappyHexMeshDict" || true
fi

surfaceFeatures -case "$CASE_DIR" -dict system/surfaceFeaturesDict
blockMesh -case "$CASE_DIR"
snappyHexMesh -overwrite -case "$CASE_DIR"
checkMesh -allTopology -allGeometry -case "$CASE_DIR"
if [ "${INIT_POTENTIAL:-0}" = "1" ]; then
  echo "INIT_POTENTIAL=1: running potentialFoam initialization"
  potentialFoam -case "$CASE_DIR" -writep
fi
simpleFoam -case "$CASE_DIR"
