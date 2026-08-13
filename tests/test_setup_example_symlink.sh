#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/build-me-godot-setup-link.XXXXXX)

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT

example="$test_root/godot-addons-example-project"
mkdir -p "$example/addons"
cp "$project_root/project.godot" "$example/project.godot"

plan_output=$("$project_root/utils/check-local-requirements.sh" plan --json --example-project "$example" || true)
jq -e '.actions[] | select(.id == "link.example.addon") | select(.ready == true)' <<<"$plan_output" >/dev/null
jq -e '.actions[] | select(.id == "link.example.addon") | .details.source | endswith("/addons/build_me_godot")' <<<"$plan_output" >/dev/null
jq -e '.actions[] | select(.id == "link.example.addon") | .details.expected_plugin | endswith("/addons/build_me_godot/plugin.cfg")' <<<"$plan_output" >/dev/null

apply_output=$("$project_root/utils/check-local-requirements.sh" apply link.example.addon --yes --json --example-project "$example")
jq -e '.changed_paths | index("'"$example"'/addons/build_me_godot")' <<<"$apply_output" >/dev/null
test -L "$example/addons/build_me_godot"
test "$(readlink -f "$example/addons/build_me_godot")" = "$project_root/addons/build_me_godot"
test -f "$example/addons/build_me_godot/plugin.cfg"

check_output=$("$project_root/utils/check-local-requirements.sh" check --json --example-project "$example" || true)
jq -e '.checks[] | select(.id == "example.addon.symlink" and .status == "ok")' <<<"$check_output" >/dev/null
