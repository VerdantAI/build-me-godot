#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/build-me-godot-character-cli.XXXXXX)

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT

install -d "$test_root/project/addons"
cp -a "$project_root/addons/build_me_godot" "$test_root/project/addons/"
cp "$project_root/project.godot" "$test_root/project/"

draft_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    draft \
    --character-id field_engineer \
    --display-name "Field Engineer" \
    --role "construction engineer" \
    --style "realistic game character" \
    --prompt "full body field engineer" \
    --negative-prompt "cropped" \
    --primary-rigged-mesh "res://characters/primary.glb" \
    --secondary-rigged-mesh "res://characters/secondary.glb" \
    --animation-asset "res://animations/humanoid.glb")

jq -e '.schema_version == 1 and .command == "draft"' <<<"$draft_output" >/dev/null
jq -e '.manifest.character_id == "field_engineer"' <<<"$draft_output" >/dev/null
jq -e '.manifest.metadata.role == "construction engineer"' <<<"$draft_output" >/dev/null
jq -e '.manifest.rigged_meshes.primary == "res://characters/primary.glb"' <<<"$draft_output" >/dev/null
jq -e '.manifest.project_context.animation_library == "res://animations/humanoid.glb"' <<<"$draft_output" >/dev/null

inspect_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    inspect --character-id field_engineer)

jq -e '.schema_version == 1 and .command == "inspect"' <<<"$inspect_output" >/dev/null
jq -e '.manifest.prompt == "full body field engineer"' <<<"$inspect_output" >/dev/null
jq -e '.manifest.assets.character_scene == "" and (.manifest.assets.animations | length == 0)' <<<"$inspect_output" >/dev/null
jq -e '.available_actions | index("queue")' <<<"$inspect_output" >/dev/null

import_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    import-workflow \
    --character-id field_engineer \
    --workflow-path res://addons/build_me_godot/workflows/character_turnaround_open.json)

jq -e '.schema_version == 1 and .command == "import-workflow"' <<<"$import_output" >/dev/null
jq -e '.manifest.prompt | startswith("Full-body game character reference")' <<<"$import_output" >/dev/null
jq -e '.manifest.negative_prompt | contains("cropped head")' <<<"$import_output" >/dev/null
jq -e '.manifest.seed == 424242' <<<"$import_output" >/dev/null

queue_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    queue \
    --character-id field_engineer \
    --workflow-path res://addons/build_me_godot/workflows/canonical_only_api.json)

jq -e '.schema_version == 1 and .command == "queue"' <<<"$queue_output" >/dev/null
jq -e '.manifest.generation.runs[0].version == "v1"' <<<"$queue_output" >/dev/null
jq -e '.manifest.generation.runs[0].status == "pending"' <<<"$queue_output" >/dev/null
jq -e '.manifest.generation.runs[0].positive_prompt | startswith("Full-body game character reference")' <<<"$queue_output" >/dev/null
jq -e '.manifest.generation.runs[0].workflow_snapshot.path == "res://build_me_godot/characters/field_engineer/workflows/v1_api.json"' <<<"$queue_output" >/dev/null
jq -e '.manifest.generation.runs[0].workflow_snapshot.sha256 | length > 0' <<<"$queue_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/workflows/v1_api.json"

manifest_path="$test_root/project/build_me_godot/characters/field_engineer/character.json"
jq '.generation.runs[0].status = "completed" |
    .generation.runs[0].outputs = {"contact_sheet": "res://build_me_godot/characters/field_engineer/references/v1/contact_sheet.png"}' \
    "$manifest_path" > "$manifest_path.tmp"
mv "$manifest_path.tmp" "$manifest_path"

approve_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    approve --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "approve"' <<<"$approve_output" >/dev/null
jq -e '.manifest.stage == "reference_approved"' <<<"$approve_output" >/dev/null
jq -e '.manifest.generation.selected_version == "v1"' <<<"$approve_output" >/dev/null
jq -e '.available_actions | index("continue:v1")' <<<"$approve_output" >/dev/null

continue_output=$(godot --no-header --headless --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    continue --character-id field_engineer --version v1 --warnings-acknowledged true)

jq -e '.schema_version == 1 and .command == "continue"' <<<"$continue_output" >/dev/null
jq -e '.manifest.stage == "pipeline_enabled"' <<<"$continue_output" >/dev/null
jq -e '.manifest.pipeline.approved_version == "v1"' <<<"$continue_output" >/dev/null
jq -e '.manifest.pipeline.warnings_acknowledged == true' <<<"$continue_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/blender/v1/reference_inputs.json")' <<<"$continue_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/blender/v1/reference_inputs.json"
