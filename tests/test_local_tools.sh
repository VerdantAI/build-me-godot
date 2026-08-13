#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)

set +e
output=$(godot --no-header --headless --path "$project_root" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    check --capability blender_humanoid_build --format json --deep-check)
code=$?
set -e

[[ "$code" -eq 1 ]]
jq -e '.checks | any(.id == "blender.executable" and .status == "pass")' <<<"$output" >/dev/null
jq -e '.checks | any(.id == "blender.builder.deep_probe" and .status == "pass" and (.detected.missing_operators | length == 0))' <<<"$output" >/dev/null
jq -e '.checks | any(.id == "animation.asset" and .status == "unknown")' <<<"$output" >/dev/null

set +e
gator_output=$(godot --no-header --headless --path "$project_root" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    check --capability last_mile_refinement --format json)
gator_code=$?
set -e

[[ "$gator_code" -eq 0 ]]
jq -e '.checks | any(.id == "gator.addon" and .importance == "optional" and (.status == "warning" or .status == "pass"))' <<<"$gator_output" >/dev/null
