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

mkdir -p "$test_root/comfyui/custom_nodes" "$test_root/comfyui/models" "$test_root/bin" "$test_root/bin-no-ctk" "$test_root/runtime"
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
cat > "$test_root/bin/podman" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == "image" && "${2:-}" == "exists" ]]; then
    exit 1
fi
printf 'podman placeholder\n'
SH
cat > "$test_root/bin/nvidia-smi" <<'SH'
#!/usr/bin/env bash
printf 'GPU 0: test\n'
SH
cat > "$test_root/bin/nvidia-ctk" <<'SH'
#!/usr/bin/env bash
printf 'nvidia-ctk placeholder\n'
SH
cp "$test_root/bin/ollama" "$test_root/bin-no-ctk/ollama"
cp "$test_root/bin/blender" "$test_root/bin-no-ctk/blender"
cp "$test_root/bin/podman" "$test_root/bin-no-ctk/podman"
cp "$test_root/bin/nvidia-smi" "$test_root/bin-no-ctk/nvidia-smi"
ln -s "$(command -v bash)" "$test_root/bin-no-ctk/bash"
ln -s "$(command -v dirname)" "$test_root/bin-no-ctk/dirname"
ln -s "$(command -v python3)" "$test_root/bin-no-ctk/python3"
chmod +x "$test_root/bin/ollama" "$test_root/bin/blender" "$test_root/bin/podman" "$test_root/bin/nvidia-smi" "$test_root/bin/nvidia-ctk" "$test_root/bin-no-ctk/ollama" "$test_root/bin-no-ctk/blender" "$test_root/bin-no-ctk/podman" "$test_root/bin-no-ctk/nvidia-smi"

run_setup() {
    XDG_RUNTIME_DIR="$test_root/runtime" PATH="$test_root/bin:$PATH" BUILD_ME_GODOT_STARTUP_TIMEOUT=0.1 \
        BUILD_ME_GODOT_NVIDIA_CDI_SPEC_PATHS="$test_root/missing-cdi/nvidia.yaml" \
        "$project_root/utils/check-local-requirements.sh" "$@" \
        --config "$test_root/missing.conf" \
        --comfyui-root "$test_root/comfyui" \
        --comfyui-url http://127.0.0.1:61991 \
        --model-download-dir "$test_root/stage" \
        --blender "$test_root/bin/blender" \
        --container-config "$test_root/container.local.env" \
        --ollama-model test:latest
}

run_setup_without_ctk() {
    XDG_RUNTIME_DIR="$test_root/runtime-no-ctk" PATH="$test_root/bin-no-ctk" BUILD_ME_GODOT_STARTUP_TIMEOUT=0.1 \
        BUILD_ME_GODOT_NVIDIA_CDI_SPEC_PATHS="$test_root/missing-cdi/nvidia.yaml" \
        bash "$project_root/utils/check-local-requirements.sh" "$@" \
        --config "$test_root/missing-no-ctk.conf" \
        --comfyui-root "$test_root/comfyui" \
        --comfyui-url http://127.0.0.1:61991 \
        --model-download-dir "$test_root/stage" \
        --blender "$test_root/bin/blender" \
        --container-config "$test_root/container-no-ctk.local.env" \
        --ollama-model test:latest
}

plan=$(run_setup plan --json || true)
provider_version=$(bash "$project_root/utils/run-container-triposr.sh" --version)
[[ "$provider_version" == "build-me-godot-container-triposr-provider 1" ]]
set +e
trellis_unconfigured_version=$(bash "$project_root/utils/run-trellis.sh" --version 2>&1)
trellis_unconfigured_code=$?
set -e
[[ "$trellis_unconfigured_code" -eq 1 ]]
grep -q 'build-me-godot-trellis-provider 1' <<<"$trellis_unconfigured_version"
grep -q 'not configured' <<<"$trellis_unconfigured_version"
jq -e '.checks[] | select(.id == "comfyui.helper") | .summary | contains("installed on disk")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "comfyui.nodes") | .summary | contains("not yet verified")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "comfyui.models") | .summary | test("installed: [0-9]+/[0-9]+")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "triposr.models" and .status == "missing" and .required == false) | .details.missing | length == 2' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "comfyui.flowty_triposr.node" and .status == "missing" and .required == false) | .details.license == "GPL-3.0" and .details.python_requirements_manual == true' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "trellis.root" and .status == "missing" and .required == false) | .details.automatic_install_allowed == false' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "trellis.model" and .status == "missing" and .required == false) | .details.automatic_downloads_allowed == false' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "trellis.provider" and .status == "missing" and .required == false) | .details.command == "bash utils/run-trellis.sh"' <<<"$plan" >/dev/null
jq -e '.actions[] | select(.id == "manual.install.trellis.provider" and .ready == true and .mutates == false) | .details.code_license == "MIT" and .details.weight_license == "MIT" and (.details.commands | any(contains("BUILD_ME_GODOT_TRELLIS_ROOT")))' <<<"$plan" >/dev/null
jq -e '.actions | all(.id != "download.triposr.models" and .id != "install.triposr.checkpoint.comfyui" and .id != "download.flowty.triposr.node" and .id != "install.flowty.triposr.node")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "container.runtime" and .status == "ok") | .details.detected.podman | length > 0' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "container.gpu.nvidia_cdi" and .status == "warning") | .details.expected_cdi_specs == ["'"$test_root"'/missing-cdi/nvidia.yaml"]' <<<"$plan" >/dev/null
jq -e '.actions[] | select(.id == "manual.configure.nvidia.cdi" and .ready == true and .mutates == false) | (.details.commands | any(contains("nvidia-ctk cdi generate"))) and .details.requires_privilege == true' <<<"$plan" >/dev/null
jq -e '.actions[] | select(.id == "manual.configure.nvidia.cdi") | .details.package_manager == "dnf" and (.details.toolkit_install_commands | any(contains("dnf install -y nvidia-container-toolkit")))' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "container.model_mounts" and .status == "ok") | .details.strategy | contains("do not bake model weights")' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "container.recipe" and .status == "ok") | .details.modes == ["doctor", "comfyui-server", "triposr-job", "blender-job"] and .details.weights_baked == false' <<<"$plan" >/dev/null
jq -e '.checks[] | select(.id == "container.image.local_toolchain" and .status == "missing")' <<<"$plan" >/dev/null
jq -e '.actions[] | select(.id == "container.build.local_toolchain" and .ready == true) | (.details.command | index("build")) != null and (.details.license_boundary | contains("model weights are not copied"))' <<<"$plan" >/dev/null
jq -e '.actions[] | select(.id == "write.container.config" and .ready == true) | .details.model_roots | length >= 1' <<<"$plan" >/dev/null
run_setup apply manual.configure.nvidia.cdi --yes >/dev/null
container_config=$(run_setup apply write.container.config --yes --json)
jq -e '.changed_paths | any(endswith("container.local.env"))' <<<"$container_config" >/dev/null
grep -q 'BUILD_ME_GODOT_CONTAINER_MODEL_ROOTS' "$test_root/container.local.env"

mkdir -p "$test_root/stage/comfyui_nodes" "$test_root/stage/triposr"
printf 'fake checkpoint' > "$test_root/stage/triposr/model.ckpt"
mkdir -p "$test_root/comfyui/custom_nodes/ComfyUI-Flowty-TripoSR" "$test_root/comfyui/models/checkpoints"
printf 'GPL node placeholder' > "$test_root/comfyui/custom_nodes/ComfyUI-Flowty-TripoSR/__init__.py"
printf 'native checkpoint' > "$test_root/comfyui/models/checkpoints/model.ckpt"

staged_plan=$(run_setup plan --json || true)
jq -e '.checks[] | select(.id == "comfyui.flowty_triposr.node" and .status == "ok")' <<<"$staged_plan" >/dev/null
jq -e '.checks[] | select(.id == "comfyui.flowty_triposr.checkpoint" and .status == "ok")' <<<"$staged_plan" >/dev/null
jq -e '.actions | all(.id != "install.flowty.triposr.node" and .id != "install.triposr.checkpoint.comfyui")' <<<"$staged_plan" >/dev/null
ready_setup_output=$(run_setup --non-interactive || true)
grep -q 'manual.configure.nvidia.cdi' <<<"$ready_setup_output"
grep -q 'apply manual.configure.nvidia.cdi --non-interactive' <<<"$ready_setup_output"
missing_ctk_output=$(run_setup_without_ctk --non-interactive || true)
grep -q 'nvidia-ctk missing' <<<"$missing_ctk_output"
grep -q 'sudo dnf install -y nvidia-container-toolkit' <<<"$missing_ctk_output"

mkdir -p "$test_root/TRELLIS/trellis/pipelines" "$test_root/TRELLIS-model"
printf '#!/usr/bin/env bash\n' > "$test_root/TRELLIS/setup.sh"
printf '{}\n' > "$test_root/TRELLIS-model/config.json"
configured_trellis_version=$(BUILD_ME_GODOT_TRELLIS_ROOT="$test_root/TRELLIS" BUILD_ME_GODOT_TRELLIS_MODEL_PATH="$test_root/TRELLIS-model" \
    bash "$project_root/utils/run-trellis.sh" --version)
[[ "$configured_trellis_version" == "build-me-godot-trellis-provider 1" ]]
configured_trellis_plan=$(BUILD_ME_GODOT_TRELLIS_ROOT="$test_root/TRELLIS" BUILD_ME_GODOT_TRELLIS_MODEL_PATH="$test_root/TRELLIS-model" \
    run_setup plan --json || true)
jq -e '.checks[] | select(.id == "trellis.provider" and .status == "ok")' <<<"$configured_trellis_plan" >/dev/null

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
