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
