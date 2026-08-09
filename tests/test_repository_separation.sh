#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"

if rg -n -i 'burb-sweeper|burb_miner|/home/.*/Verdant/burb' addons/build_me_godot \
    --glob '!ATTRIBUTIONS.md' --glob '!LICENSES.md'; then
    echo "Build Me Godot runtime/package files contain a Burb project dependency" >&2
    exit 1
fi

test ! -e addons/build_me_godot/templates/burb_sweeper.json
test -f addons/build_me_godot/templates/field_engineer.json
