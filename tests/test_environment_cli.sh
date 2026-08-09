#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/build-me-godot-environment.XXXXXX)
mock_port=$((20000 + RANDOM % 20000))
mock_pid=""

cleanup() {
    if [[ -n "$mock_pid" ]]; then
        kill "$mock_pid" 2>/dev/null || true
    fi
    rm -rf "$test_root"
}
trap cleanup EXIT

install -d "$test_root/project/addons" "$test_root/comfyui/custom_nodes"
cp -a "$project_root/addons/build_me_godot" "$test_root/project/addons/"
cp "$project_root/project.godot" "$test_root/project/"

python3 "$project_root/tests/mock_comfyui.py" --port "$mock_port" &
mock_pid=$!

for _attempt in {1..30}; do
    if curl --silent --fail "http://127.0.0.1:${mock_port}/system_stats" >/dev/null; then
        break
    fi
    sleep 0.1
done

printf '[local_models]\ncomfyui_url="http://127.0.0.1:%s"\ncomfyui_root="%s"\n' \
    "$mock_port" "$test_root/comfyui" > "$test_root/project/build_me_godot.local.cfg"

set +e
local_plan_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    plan --capability canonical_generation --format json)
local_plan_code=$?
set -e
[[ "$local_plan_code" -eq 1 ]]
jq -e '.install_plan.actions | any(.id == "install.comfyui.turnaround_helper" and .mode == "safe_local")' <<<"$local_plan_output" >/dev/null

set +e
plan_output=$(BUILD_ME_GODOT_COMFYUI_ROOT="$test_root/environment-override" \
    godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    plan --capability canonical_generation --format json \
    --comfyui-url "http://127.0.0.1:${mock_port}" \
    --comfyui-root "$test_root/comfyui")
plan_code=$?
set -e
[[ "$plan_code" -eq 1 ]]
jq -e '.install_plan.actions | any(.id == "install.comfyui.turnaround_helper" and .mode == "safe_local")' <<<"$plan_output" >/dev/null
jq -e --arg target "$test_root/comfyui/custom_nodes/character_turnaround_output.py" '.install_plan.actions[] | select(.id == "install.comfyui.turnaround_helper") | .target == $target' <<<"$plan_output" >/dev/null
jq -e '.install_plan.actions[] | select(.id == "install.comfyui.turnaround_helper") | (.rationale | length > 0) and (.prerequisites | length > 0) and (.verification_checks | length > 0) and .reversible and (.license == "MIT")' <<<"$plan_output" >/dev/null
jq -e '.environment.schema_version == 1 and (.environment.checks | map(.id) == (map(.id) | sort))' <<<"$plan_output" >/dev/null

support_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    check --capability blender_humanoid_build --format json \
    --animation-asset "$HOME/private/animations.glb" --support-report || true)
jq -e --arg home "$HOME" '.schema_version == 1 and ([.. | strings] | all(contains($home) | not))' <<<"$support_output" >/dev/null

apply_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    apply --capability canonical_generation --format json \
    --comfyui-url "http://127.0.0.1:${mock_port}" \
    --comfyui-root "$test_root/comfyui" \
    --action install.comfyui.turnaround_helper)
jq -e '.result.ok == true and .result.verification == true and .result.restart_required == true' <<<"$apply_output" >/dev/null
test -f "$test_root/comfyui/custom_nodes/character_turnaround_output.py"

set +e
godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/environment_cli.gd -- \
    apply --capability project_workspace --format json >/dev/null 2>&1
missing_action_code=$?
set -e
[[ "$missing_action_code" -eq 2 ]]

test ! -e "$test_root/project/build_me_godot"
