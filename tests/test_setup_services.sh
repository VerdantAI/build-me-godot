#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/build-me-godot-setup-services.XXXXXX)

cleanup() {
    for name in comfyui ollama blender; do
        record="$test_root/runtime/build-me-godot-$(id -u)/$name.json"
        if [[ -f "$record" ]]; then
            kill -TERM "$(jq -r .pid "$record")" 2>/dev/null || true
        fi
    done
    rm -rf "$test_root"
}
trap cleanup EXIT

mkdir -p "$test_root/comfyui/custom_nodes" "$test_root/comfyui/models" "$test_root/bin" "$test_root/runtime"
cp "$project_root/addons/build_me_godot/integrations/comfyui/character_turnaround_output.py" \
    "$test_root/comfyui/custom_nodes/character_turnaround_output.py"
cat > "$test_root/comfyui/main.py" <<'PY'
import time
time.sleep(60)
PY
cat > "$test_root/bin/ollama" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == "list" ]]; then
    printf 'NAME ID SIZE MODIFIED\n'
    exit 0
fi
sleep 60
SH
cat > "$test_root/bin/blender" <<'SH'
#!/usr/bin/env bash
sleep 60
SH
chmod +x "$test_root/bin/ollama" "$test_root/bin/blender"

run_setup() {
    XDG_RUNTIME_DIR="$test_root/runtime" PATH="$test_root/bin:$PATH" BUILD_ME_GODOT_STARTUP_TIMEOUT=0.1 \
        "$project_root/utils/check-local-requirements.sh" "$@" \
        --config "$test_root/missing.conf" \
        --comfyui-root "$test_root/comfyui" \
        --comfyui-url http://127.0.0.1:61991 \
        --blender "$test_root/bin/blender" \
        --ollama-model test:latest
}

plan=$(run_setup plan --json || true)
jq -e '.checks[] | select(.id == "comfyui.helper") | .summary | contains("installed on disk")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "comfyui.nodes") | .summary | contains("not yet verified")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "comfyui.models") | .summary | test("installed: [0-9]+/[0-9]+")' <<<"$plan" >/dev/null
for name in comfyui ollama blender; do
    jq -e --arg id "start.$name" '.actions[] | select(.id == $id and .ready == true)' <<<"$plan" >/dev/null
    run_setup apply "start.$name" --yes --json >/dev/null
    running_plan=$(run_setup plan --json || true)
    jq -e --arg id "stop.$name" '.actions[] | select(.id == $id and .ready == true)' <<<"$running_plan" >/dev/null
    run_setup apply "stop.$name" --yes --json >/dev/null
    stopped_plan=$(run_setup plan --json || true)
    jq -e --arg id "start.$name" '.actions[] | select(.id == $id and .ready == true)' <<<"$stopped_plan" >/dev/null
done

no_model_plan=$(XDG_RUNTIME_DIR="$test_root/runtime-empty" PATH="$test_root/bin:$PATH" \
    "$project_root/utils/check-local-requirements.sh" plan --json \
    --config "$test_root/missing.conf" \
    --comfyui-root "$test_root/comfyui" \
    --comfyui-url http://127.0.0.1:61991 \
    --blender "$test_root/bin/blender" || true)
jq -e '.checks | any(.id == "ollama.models" and .status == "ok" and .summary == "Ollama models: none required")' <<<"$no_model_plan" >/dev/null
