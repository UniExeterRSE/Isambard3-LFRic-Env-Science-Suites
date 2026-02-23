#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="${WORKING_DIR:-$ROOT_DIR/working_dir}"

RUNTIME_DIRS=(
  "$WORKING_DIR"
  "$ROOT_DIR/spack"
  "$ROOT_DIR/lfric_apps"
  "$ROOT_DIR/lfric_core"
  "$ROOT_DIR/simit-spack-main"
  "$ROOT_DIR/uoe-umlfric-spack"
)

RUNTIME_FILES=(
  "$ROOT_DIR/driver.log"
)

for path in "${RUNTIME_FILES[@]}"; do
  if [ -e "$path" ]; then
    rm -f "$path"
  fi
done

for path in "${RUNTIME_DIRS[@]}"; do
  if [ -d "$path" ]; then
    rm -rf "$path"
  fi
done
