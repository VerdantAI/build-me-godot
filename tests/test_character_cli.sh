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
install -d "$test_root/project/characters" "$test_root/project/animations"
printf 'primary rigged mesh fixture' > "$test_root/project/characters/primary.glb"
printf 'secondary rigged mesh fixture' > "$test_root/project/characters/secondary.glb"
printf 'animation fixture' > "$test_root/project/animations/humanoid.glb"
install -d "${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Build Me Godot Development/logs"

draft_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
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

inspect_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    inspect --character-id field_engineer)

jq -e '.schema_version == 1 and .command == "inspect"' <<<"$inspect_output" >/dev/null
jq -e '.manifest.prompt == "full body field engineer"' <<<"$inspect_output" >/dev/null
jq -e '.manifest.assets.character_scene == "" and (.manifest.assets.animations | length == 0)' <<<"$inspect_output" >/dev/null
jq -e '.available_actions | index("queue")' <<<"$inspect_output" >/dev/null

import_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    import-workflow \
    --character-id field_engineer \
    --workflow-path res://addons/build_me_godot/workflows/character_turnaround_open.json)

jq -e '.schema_version == 1 and .command == "import-workflow"' <<<"$import_output" >/dev/null
jq -e '.manifest.prompt | startswith("Full-body game character reference")' <<<"$import_output" >/dev/null
jq -e '.manifest.negative_prompt | contains("cropped head")' <<<"$import_output" >/dev/null
jq -e '.manifest.seed == 424242' <<<"$import_output" >/dev/null

queue_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
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
    .generation.runs[0].outputs = {"front": "res://build_me_godot/characters/field_engineer/references/v1/front.png", "contact_sheet": "res://build_me_godot/characters/field_engineer/references/v1/contact_sheet.png"}' \
    "$manifest_path" > "$manifest_path.tmp"
mv "$manifest_path.tmp" "$manifest_path"
install -d "$test_root/project/build_me_godot/characters/field_engineer/references/v1"
printf 'fake front image bytes' > "$test_root/project/build_me_godot/characters/field_engineer/references/v1/front.png"
printf 'fake contact sheet bytes' > "$test_root/project/build_me_godot/characters/field_engineer/references/v1/contact_sheet.png"

mock_provider="$test_root/mock_triposr_provider.sh"
cat > "$mock_provider" <<'MOCK_PROVIDER'
#!/usr/bin/env bash
set -euo pipefail
output=""
metadata=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        --metadata-output) metadata="$2"; shift 2 ;;
        *) shift ;;
    esac
done
mkdir -p "$(dirname "$output")" "$(dirname "$metadata")"
printf 'mock glb bytes' > "$output"
printf '{"provider":"mock_triposr"}\n' > "$metadata"
MOCK_PROVIDER
chmod +x "$mock_provider"

approve_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    approve --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "approve"' <<<"$approve_output" >/dev/null
jq -e '.manifest.stage == "reference_approved"' <<<"$approve_output" >/dev/null
jq -e '.manifest.generation.selected_version == "v1"' <<<"$approve_output" >/dev/null
jq -e '.available_actions | index("continue:v1")' <<<"$approve_output" >/dev/null
jq -e '.available_actions | index("prepare-conformance:v1")' <<<"$approve_output" >/dev/null
jq -e '.available_actions | index("create-recipe:v1")' <<<"$approve_output" >/dev/null

recipe_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    create-recipe \
    --character-id field_engineer \
    --version v1 \
    --game-mode-profile-id 3d_isometric_party \
    --texture-budget medium)

jq -e '.schema_version == 1 and .command == "create-recipe"' <<<"$recipe_output" >/dev/null
jq -e '.manifest.stage == "recipe_draft"' <<<"$recipe_output" >/dev/null
jq -e '.recipe_path == "res://build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json"' <<<"$recipe_output" >/dev/null
jq -e '.recipe.reference_version == "v1" and .recipe.game_mode_profile_id == "3d_isometric_party"' <<<"$recipe_output" >/dev/null
jq -e '.recipe.body.provider == "project_rigged_meshes"' <<<"$recipe_output" >/dev/null
jq -e '.recipe.source.reference_outputs.front == "res://build_me_godot/characters/field_engineer/references/v1/front.png"' <<<"$recipe_output" >/dev/null
jq -e '.recipe.equipment | any(.part_id == "role_prop" or .socket == "hand_r" or .socket == "hand_l")' <<<"$recipe_output" >/dev/null
jq -e '.recipe_validation.status == "pass" or .recipe_validation.status == "warning"' <<<"$recipe_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json")' <<<"$recipe_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json"

inspect_recipe_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    inspect-recipe --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "inspect-recipe"' <<<"$inspect_recipe_output" >/dev/null
jq -e '.recipe_path == "res://build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json"' <<<"$inspect_recipe_output" >/dev/null

validate_recipe_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    validate-recipe --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "validate-recipe"' <<<"$validate_recipe_output" >/dev/null
jq -e '.recipe_validation.status == "pass" or .recipe_validation.status == "warning"' <<<"$validate_recipe_output" >/dev/null

set +e
invalid_recipe_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    create-recipe \
    --character-id field_engineer \
    --version v1 \
    --recipe-version bad_proxy_body \
    --body-provider triposr)
invalid_recipe_code=$?
set -e
[[ "$invalid_recipe_code" -eq 0 ]]
jq -e '.recipe_validation.status == "failed"' <<<"$invalid_recipe_output" >/dev/null

set +e
approve_invalid_recipe_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    approve-recipe --character-id field_engineer --version bad_proxy_body 2>&1)
approve_invalid_recipe_code=$?
set -e
[[ "$approve_invalid_recipe_code" -eq 2 ]]
grep -q "validation failed" <<<"$approve_invalid_recipe_output"

approve_recipe_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    approve-recipe --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "approve-recipe"' <<<"$approve_recipe_output" >/dev/null
jq -e '.manifest.stage == "recipe_approved"' <<<"$approve_recipe_output" >/dev/null
jq -e '.manifest.recipes.selected_version == "v1"' <<<"$approve_recipe_output" >/dev/null
jq -e '.available_actions | index("register-assembly:v1")' <<<"$approve_recipe_output" >/dev/null

assembly_dir="$test_root/project/build_me_godot/characters/field_engineer/assembly/v1"
install -d "$assembly_dir"
printf 'fake glb bytes' > "$assembly_dir/field_engineer_v1_isometric_assembly.glb"
cat > "$assembly_dir/assembly_report.json" <<'JSON'
{
  "schema_version": 1,
  "status": "assembled",
  "character_id": "field_engineer",
  "recipe_version": "v1",
  "recipe_path": "res://build_me_godot/characters/field_engineer/recipes/v1/character_recipe.json",
  "warnings": [],
  "body_source": "res://characters/primary.glb",
  "body_objects": ["Armature", "Body"],
  "reference_images": ["res://build_me_godot/characters/field_engineer/references/v1/front.png"],
  "sockets": [
    {"name": "hand_r", "parent_bone": "RightHand", "required": true},
    {"name": "hand_l", "parent_bone": "LeftHand", "required": true}
  ],
  "equipment": [
    {"part_id": "tool", "socket": "hand_r", "representation": "primitive", "object": "EQUIP_tool"}
  ],
  "outputs": {
    "blender_work_file": "res://build_me_godot/characters/field_engineer/assembly/v1/field_engineer_v1_isometric_assembly.blend",
    "godot_import_asset": "res://build_me_godot/characters/field_engineer/assembly/v1/field_engineer_v1_isometric_assembly.glb",
    "assembly_report": "res://build_me_godot/characters/field_engineer/assembly/v1/assembly_report.json"
  }
}
JSON

register_assembly_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    register-assembly \
    --character-id field_engineer \
    --version v1 \
    --assembly-report res://build_me_godot/characters/field_engineer/assembly/v1/assembly_report.json)

jq -e '.schema_version == 1 and .command == "register-assembly"' <<<"$register_assembly_output" >/dev/null
jq -e '.manifest.stage == "assembly_registered"' <<<"$register_assembly_output" >/dev/null
jq -e '.manifest.assets.character_scene == "res://build_me_godot/characters/field_engineer/field_engineer.tscn"' <<<"$register_assembly_output" >/dev/null
jq -e '.manifest.assets.godot_import_asset == "res://build_me_godot/characters/field_engineer/assembly/v1/field_engineer_v1_isometric_assembly.glb"' <<<"$register_assembly_output" >/dev/null
jq -e '.manifest.assets.animations | index("res://addons/build_me_godot/examples/quaternius_ik_rigged/UAL1_Standard.animation_library.tres")' <<<"$register_assembly_output" >/dev/null
jq -e '.manifest.assets.preview_readability.status == "pending"' <<<"$register_assembly_output" >/dev/null
jq -e '.registration_report.status == "registered"' <<<"$register_assembly_output" >/dev/null
jq -e '.registration_report.animations | index("res://addons/build_me_godot/examples/quaternius_ik_rigged/UAL1_Standard.animation_library.tres")' <<<"$register_assembly_output" >/dev/null
jq -e '.checkpoint_path == "res://build_me_godot/characters/field_engineer/checkpoints/v1/checkpoint_index.json"' <<<"$register_assembly_output" >/dev/null
jq -e '.checkpoint_index.stages.base_body.status == "valid"' <<<"$register_assembly_output" >/dev/null
jq -e '.checkpoint_index.stages.assembly.status == "valid"' <<<"$register_assembly_output" >/dev/null
jq -e '.checkpoint_index.stages.animation_smoke.status == "valid"' <<<"$register_assembly_output" >/dev/null
jq -e '.checkpoint_index.stages.readability.status == "pending"' <<<"$register_assembly_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/field_engineer.tscn"
test -f "$test_root/project/build_me_godot/characters/field_engineer/reports/v1/isometric_character_registration.json"
test -f "$test_root/project/build_me_godot/characters/field_engineer/checkpoints/v1/checkpoint_index.json"
grep -q 'type="AnimationPlayer"' "$test_root/project/build_me_godot/characters/field_engineer/field_engineer.tscn"
grep -q 'root_node = NodePath("../Model")' "$test_root/project/build_me_godot/characters/field_engineer/field_engineer.tscn"
grep -q 'UAL1_Standard.animation_library.tres' "$test_root/project/build_me_godot/characters/field_engineer/field_engineer.tscn"

checkpoint_status_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    checkpoint-status --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "checkpoint-status"' <<<"$checkpoint_status_output" >/dev/null
jq -e '.checkpoint_index.stages.godot_scene.status == "valid"' <<<"$checkpoint_status_output" >/dev/null
jq -e '.checkpoint_index.stages.animation_smoke.status == "valid"' <<<"$checkpoint_status_output" >/dev/null

invalidate_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    invalidate-stage \
    --character-id field_engineer \
    --version v1 \
    --stage godot_scene \
    --reason "fixture invalidation")

jq -e '.schema_version == 1 and .command == "invalidate-stage"' <<<"$invalidate_output" >/dev/null
jq -e '.checkpoint_index.stages.godot_scene.status == "stale"' <<<"$invalidate_output" >/dev/null
jq -e '.checkpoint_index.stages.animation_smoke.status == "stale"' <<<"$invalidate_output" >/dev/null

explain_stale_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    explain-stale --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "explain-stale"' <<<"$explain_stale_output" >/dev/null
jq -e '.stale_explanations | any(.stage == "godot_scene" and .status == "stale")' <<<"$explain_stale_output" >/dev/null

mark_reviewed_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    mark-reviewed --character-id field_engineer --version v1 --stage godot_scene)

jq -e '.schema_version == 1 and .command == "mark-reviewed"' <<<"$mark_reviewed_output" >/dev/null
jq -e '.checkpoint_index.stages.godot_scene.reviewed == true' <<<"$mark_reviewed_output" >/dev/null

resume_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    resume-from-stage --character-id field_engineer --version v1 --stage godot_scene)

jq -e '.schema_version == 1 and .command == "resume-from-stage"' <<<"$resume_output" >/dev/null
jq -e '.manifest.stage == "assembly_registered"' <<<"$resume_output" >/dev/null
jq -e '.checkpoint_index.stages.assembly.status == "valid"' <<<"$resume_output" >/dev/null
jq -e '.checkpoint_index.stages.godot_scene.status == "valid"' <<<"$resume_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/references/v1/front.png") | not' <<<"$resume_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/assembly/v1/field_engineer_v1_isometric_assembly.glb") | not' <<<"$resume_output" >/dev/null

godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    draft \
    --character-id second_character \
    --display-name "Second Character" \
    --role "reuse test" \
    --style "isometric fixture" \
    --prompt "second character" \
    --primary-rigged-mesh "res://characters/primary.glb" \
    --secondary-rigged-mesh "res://characters/secondary.glb" \
    --animation-asset "res://animations/humanoid.glb" >/dev/null

reuse_base_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    reuse-base-checkpoint \
    --character-id second_character \
    --version v1 \
    --source-character-id field_engineer \
    --source-version v1)

jq -e '.schema_version == 1 and .command == "reuse-base-checkpoint"' <<<"$reuse_base_output" >/dev/null
jq -e '.checkpoint_index.stages.base_body.status == "valid"' <<<"$reuse_base_output" >/dev/null
jq -e '.checkpoint_index.stages.animation_smoke.status == "valid"' <<<"$reuse_base_output" >/dev/null
jq -e '.checkpoint_index.stages.base_body.reused_from.character_id == "field_engineer"' <<<"$reuse_base_output" >/dev/null

set +e
missing_provenance_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    prepare-conformance \
    --character-id field_engineer \
    --version v1 \
    --proxy-mesh res://build_me_godot/characters/field_engineer/conformance/v1/proxy_meshes/front_proxy.glb \
    --proxy-license-record user_supplied 2>&1)
missing_provenance_code=$?
set -e
[[ "$missing_provenance_code" -eq 2 ]]
grep -q "proxy-provenance" <<<"$missing_provenance_output"

set +e
invalid_proxy_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    prepare-conformance \
    --character-id field_engineer \
    --version v1 \
    --proxy-mesh res://addons/build_me_godot/proxy.glb \
    --proxy-license-record user_supplied \
    --proxy-provenance '{"source":"manual-test"}' 2>&1)
invalid_proxy_code=$?
set -e
[[ "$invalid_proxy_code" -eq 2 ]]
grep -q "addon" <<<"$invalid_proxy_output"

set +e
rejected_provider_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    prepare-conformance \
    --character-id field_engineer \
    --version v1 \
    --provider-id stable_fast_3d 2>&1)
rejected_provider_code=$?
set -e
[[ "$rejected_provider_code" -eq 2 ]]
grep -q "Rejected" <<<"$rejected_provider_output"

prepare_provider_conformance_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    prepare-conformance \
    --character-id field_engineer \
    --version v1 \
    --reconstruction-command "$mock_provider")

jq -e '.schema_version == 1 and .command == "prepare-conformance"' <<<"$prepare_provider_conformance_output" >/dev/null
jq -e '.conformance_plan.providers | any(.provider_id == "triposr" and .status == "configured")' <<<"$prepare_provider_conformance_output" >/dev/null
jq -e '.available_actions | index("generate-proxy:v1")' <<<"$prepare_provider_conformance_output" >/dev/null

generate_proxy_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    generate-proxy \
    --character-id field_engineer \
    --version v1 \
    --provider triposr)

jq -e '.schema_version == 1 and .command == "generate-proxy"' <<<"$generate_proxy_output" >/dev/null
jq -e '.manifest.stage == "conformance_proxy_generated"' <<<"$generate_proxy_output" >/dev/null
jq -e '.conformance_plan.status == "conformance_proxy_generated"' <<<"$generate_proxy_output" >/dev/null
jq -e '.conformance_plan.providers | any(.provider_id == "triposr" and .status == "generated" and .outputs.front_proxy_glb == "res://build_me_godot/characters/field_engineer/conformance/v1/proxy_meshes/triposr_front.glb")' <<<"$generate_proxy_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/conformance/v1/proxy_meshes/triposr_front.glb")' <<<"$generate_proxy_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/conformance/v1/proxy_meshes/triposr_front.glb"
test -f "$test_root/project/build_me_godot/characters/field_engineer/conformance/v1/reports/triposr_front_proxy_generation.json"

prepare_conformance_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    prepare-conformance \
    --character-id field_engineer \
    --version v1 \
    --proxy-mesh res://build_me_godot/characters/field_engineer/conformance/v1/proxy_meshes/front_proxy.glb \
    --proxy-license-record user_supplied \
    --proxy-provenance '{"source":"manual-test"}')

jq -e '.schema_version == 1 and .command == "prepare-conformance"' <<<"$prepare_conformance_output" >/dev/null
jq -e '.manifest.stage == "conformance_prepared"' <<<"$prepare_conformance_output" >/dev/null
jq -e '.conformance_plan.reference_version == "v1"' <<<"$prepare_conformance_output" >/dev/null
jq -e '.conformance_plan.validation_constraints.source_meshes_immutable == true' <<<"$prepare_conformance_output" >/dev/null
jq -e '.conformance_plan.providers | any(.provider_id == "external_proxy_mesh" and .status == "provided")' <<<"$prepare_conformance_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/conformance/v1/conformance_plan.json")' <<<"$prepare_conformance_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/conformance/v1/conformance_plan.json"
test -f "$test_root/project/build_me_godot/characters/field_engineer/conformance/v1/provider_inputs.json"
test -f "$test_root/project/build_me_godot/characters/field_engineer/conformance/v1/reports/validation.json"

inspect_conformance_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    inspect-conformance --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "inspect-conformance"' <<<"$inspect_conformance_output" >/dev/null
jq -e '.conformance_plan_path == "res://build_me_godot/characters/field_engineer/conformance/v1/conformance_plan.json"' <<<"$inspect_conformance_output" >/dev/null
jq -e '.conformance_plan.field_engineer_targets.avoid | index("fused_tools")' <<<"$inspect_conformance_output" >/dev/null

support_conformance_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    inspect-conformance --character-id field_engineer --version v1 --support-report)

jq -e '.manifest.prompt == "<redacted>" and .conformance_plan.source_references.contact_sheet == "res://build_me_godot/characters/field_engineer/references/v1/contact_sheet.png"' <<<"$support_conformance_output" >/dev/null
if grep -q "Full-body game character reference" <<<"$support_conformance_output"; then
    exit 1
fi

approve_conformance_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    approve-conformance --character-id field_engineer --version v1)

jq -e '.schema_version == 1 and .command == "approve-conformance"' <<<"$approve_conformance_output" >/dev/null
jq -e '.manifest.stage == "conformance_approved" and .manifest.conformance.approved == true' <<<"$approve_conformance_output" >/dev/null

continue_output=$(godot --no-header --headless --log-file "$test_root/godot.log" --path "$test_root/project" \
    --script res://addons/build_me_godot/cli/character_cli.gd -- \
    continue --character-id field_engineer --version v1 --warnings-acknowledged true)

jq -e '.schema_version == 1 and .command == "continue"' <<<"$continue_output" >/dev/null
jq -e '.manifest.stage == "pipeline_enabled"' <<<"$continue_output" >/dev/null
jq -e '.manifest.pipeline.approved_version == "v1"' <<<"$continue_output" >/dev/null
jq -e '.manifest.pipeline.warnings_acknowledged == true' <<<"$continue_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/blender/v1/reference_inputs.json")' <<<"$continue_output" >/dev/null
jq -e '.changed_paths | index("res://build_me_godot/characters/field_engineer/blender/v1/mesh_guidance.json")' <<<"$continue_output" >/dev/null
jq -e '.mesh_guidance.reference_version == "v1" and .mesh_guidance.validation_constraints.source_meshes_immutable == true' <<<"$continue_output" >/dev/null
jq -e '.mesh_guidance.secondary_asset_candidates | any(.asset_id == "clipboard" and .socket == "hand_l")' <<<"$continue_output" >/dev/null
test -f "$test_root/project/build_me_godot/characters/field_engineer/blender/v1/reference_inputs.json"
test -f "$test_root/project/build_me_godot/characters/field_engineer/blender/v1/mesh_guidance.json"
