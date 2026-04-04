#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "SourceMod artifact directory not found at $ARTIFACT_DIR" >&2
  exit 1
fi

python3 - "$ARTIFACT_DIR" <<'PY'
import os
import sys

artifact_dir = sys.argv[1]
sm_dir = os.path.join(artifact_dir, "addons", "sourcemod")

expected_files = [
    os.path.join(sm_dir, "plugins", "lilac.smx"),
    os.path.join(sm_dir, "scripting", "lilac.sp"),
    os.path.join(sm_dir, "scripting", "lilac", "lilac_globals.sp"),
    os.path.join(sm_dir, "scripting", "include", "lilac.inc"),
    os.path.join(sm_dir, "translations", "lilac.phrases.txt"),
    os.path.join(artifact_dir, "compile.log"),
]

for path in expected_files:
    if not os.path.isfile(path):
        raise SystemExit(f"Missing artifact file: {path}")

include_dir = os.path.join(sm_dir, "scripting", "include")
include_entries = sorted(
    entry for entry in os.listdir(include_dir)
    if os.path.isfile(os.path.join(include_dir, entry))
)
if include_entries != ["lilac.inc"]:
    raise SystemExit(f"Unexpected public includes: {include_entries}")

print("ARTIFACT_VALIDATION_OK")
PY
