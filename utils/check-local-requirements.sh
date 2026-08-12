#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

comfyui_url="${BUILD_ME_GODOT_COMFYUI_URL:-http://127.0.0.1:8188}"
comfyui_root="${BUILD_ME_GODOT_COMFYUI_ROOT:-}"
workflow_requirements=(
    "$project_root/addons/build_me_godot/workflows/canonical_only_api.requirements.json"
    "$project_root/addons/build_me_godot/workflows/multiview_only_api.requirements.json"
    "$project_root/build_me_godot/workflows/qwen_blender_reference_set_ui.requirements.json"
)
ollama_models=()
interactive=1

usage() {
    cat <<'EOF'
Usage: utils/check-local-requirements.sh [options]

Checks local Build Me Godot requirements and prints explicit user-run install
commands for anything missing. The script does not install packages, download
models, or modify external tool directories.

Options:
  --comfyui-url URL          ComfyUI server URL. Default: http://127.0.0.1:8188
  --comfyui-root PATH        Existing local ComfyUI root for model-file checks.
  --ollama-model NAME        Required local Ollama model. Can be repeated.
  --non-interactive          Print remediation without prompting.
  -h, --help                 Show this help.

Examples:
  utils/check-local-requirements.sh --comfyui-root "$HOME/src/ComfyUI"
  utils/check-local-requirements.sh --ollama-model llama3.1:8b
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --comfyui-url)
            comfyui_url="${2:?--comfyui-url requires a value}"
            shift 2
            ;;
        --comfyui-root)
            comfyui_root="${2:?--comfyui-root requires a value}"
            shift 2
            ;;
        --ollama-model)
            ollama_models+=("${2:?--ollama-model requires a value}")
            shift 2
            ;;
        --non-interactive)
            interactive=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

missing_labels=()
missing_commands=()
warn_labels=()

have_command() {
    command -v "$1" >/dev/null 2>&1
}

record_missing() {
    missing_labels+=("$1")
    missing_commands+=("$2")
}

record_warning() {
    warn_labels+=("$1")
}

print_check() {
    printf '[%s] %s\n' "$1" "$2"
}

check_command() {
    local command_name="$1"
    local label="$2"
    local install_hint="$3"

    if have_command "$command_name"; then
        print_check "ok" "$label: $(command -v "$command_name")"
    else
        print_check "missing" "$label"
        record_missing "$label" "$install_hint"
    fi
}

check_http() {
    local url="$1"
    local label="$2"
    local install_hint="$3"

    if ! have_command curl; then
        print_check "skip" "$label: curl is missing"
        return
    fi

    if curl --silent --fail --max-time 2 "$url" >/dev/null; then
        print_check "ok" "$label"
    else
        print_check "missing" "$label"
        record_missing "$label" "$install_hint"
    fi
}

check_godot_project() {
    if [[ -f "$project_root/project.godot" ]]; then
        print_check "ok" "Godot project file"
    else
        print_check "missing" "Godot project file"
        record_missing "Godot project file" "Run this script from the build-me-godot repository."
    fi

    if [[ -d "$project_root/addons/build_me_godot" ]]; then
        print_check "ok" "Build Me Godot addon source"
    else
        print_check "missing" "Build Me Godot addon source"
        record_missing "Build Me Godot addon source" "Restore addons/build_me_godot from the repository."
    fi
}

check_comfyui_helper() {
    if [[ -z "$comfyui_root" ]]; then
        print_check "skip" "ComfyUI helper file: pass --comfyui-root for file check"
        return
    fi

    local helper="$comfyui_root/custom_nodes/character_turnaround_output.py"
    if [[ -f "$helper" ]]; then
        print_check "ok" "ComfyUI turnaround helper"
    else
        print_check "missing" "ComfyUI turnaround helper"
        record_missing "ComfyUI turnaround helper" \
            "cp '$project_root/addons/build_me_godot/integrations/comfyui/character_turnaround_output.py' '$helper' && restart ComfyUI"
    fi
}

check_comfyui_nodes() {
    if ! have_command curl || ! have_command jq; then
        print_check "skip" "ComfyUI node metadata: requires curl and jq"
        return
    fi

    local object_info
    if ! object_info=$(curl --silent --fail --max-time 5 "$comfyui_url/object_info"); then
        print_check "skip" "ComfyUI node metadata: server is not reachable"
        return
    fi

    local requirements_path class_type
    local missing=()
    for requirements_path in "${workflow_requirements[@]}"; do
        [[ -f "$requirements_path" ]] || continue
        while IFS= read -r class_type; do
            if ! jq -e --arg class_type "$class_type" 'has($class_type)' <<<"$object_info" >/dev/null; then
                missing+=("$class_type")
            fi
        done < <(jq -r '.required_node_classes[]?' "$requirements_path")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_check "ok" "ComfyUI required workflow nodes"
    else
        local unique
        unique=$(printf '%s\n' "${missing[@]}" | sort -u | paste -sd ', ' -)
        print_check "missing" "ComfyUI required workflow nodes: $unique"
        record_missing "ComfyUI required workflow nodes" \
            "Open ComfyUI Manager and install the missing node packs, then restart ComfyUI. Missing classes: $unique"
    fi
}

model_subdirs_for_loader() {
    case "$1" in
        CLIPLoader) printf '%s\n' "models/clip" ;;
        VAELoader) printf '%s\n' "models/vae" ;;
        UNETLoader) printf '%s\n' "models/unet" "models/diffusion_models" ;;
        LoraLoaderModelOnly) printf '%s\n' "models/loras" ;;
        *) printf '%s\n' "models" ;;
    esac
}

check_comfyui_model_files() {
    if [[ -z "$comfyui_root" ]]; then
        print_check "skip" "ComfyUI model files: pass --comfyui-root for file checks"
        return
    fi
    if ! have_command jq; then
        print_check "skip" "ComfyUI model files: jq is missing"
        return
    fi

    local requirements_path artifact loader value repository found subdir
    local missing=()
    while IFS=$'\t' read -r loader value repository; do
        [[ -n "$loader" && -n "$value" ]] || continue
        found=0
        while IFS= read -r subdir; do
            if [[ -f "$comfyui_root/$subdir/$value" ]]; then
                found=1
                break
            fi
        done < <(model_subdirs_for_loader "$loader")
        if [[ "$found" -eq 0 ]]; then
            missing+=("$value from $repository")
        fi
    done < <(
        for requirements_path in "${workflow_requirements[@]}"; do
            [[ -f "$requirements_path" ]] || continue
            jq -r '.model_artifacts[]? | [.loader, .value, .repository] | @tsv' "$requirements_path"
        done | sort -u
    )

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_check "ok" "ComfyUI declared model files"
    else
        local summary
        summary=$(printf '%s\n' "${missing[@]}" | sed 's/^/  - /')
        print_check "missing" "ComfyUI declared model files"
        record_missing "ComfyUI declared model files" \
            "Download the declared Apache-2.0 model artifacts manually into '$comfyui_root/models/*':"$'\n'"$summary"
    fi
}

check_ollama_models() {
    if [[ ${#ollama_models[@]} -eq 0 ]]; then
        print_check "skip" "Ollama models: pass --ollama-model NAME to require one"
        return
    fi

    if ! have_command ollama; then
        print_check "missing" "Ollama executable"
        record_missing "Ollama executable" "Install Ollama from https://ollama.com/download/linux, then run this script again."
        return
    fi

    local list_output model
    if ! list_output=$(ollama list 2>/dev/null); then
        print_check "missing" "Ollama local model list"
        record_missing "Ollama local model list" "Start Ollama, then run: ollama list"
        return
    fi

    for model in "${ollama_models[@]}"; do
        if awk 'NR > 1 {print $1}' <<<"$list_output" | grep -Fx "$model" >/dev/null; then
            print_check "ok" "Ollama model $model"
        else
            print_check "missing" "Ollama model $model"
            record_missing "Ollama model $model" "ollama pull '$model'"
        fi
    done
}

print_remediation() {
    if [[ ${#missing_labels[@]} -eq 0 ]]; then
        printf '\nAll required local checks passed for the selected options.\n'
        return
    fi

    printf '\nMissing requirements detected:\n'
    local i
    for i in "${!missing_labels[@]}"; do
        printf '\n%d. %s\n' "$((i + 1))" "${missing_labels[$i]}"
        printf '   Suggested explicit user action:\n'
        printf '   %s\n' "${missing_commands[$i]}"
    done

    if [[ "$interactive" -eq 1 && -t 0 ]]; then
        printf '\nNo actions have been run. Type the command(s) you approve in another shell.\n'
        read -r -p "Press Enter after reviewing the suggested actions." _
    fi
}

main() {
    printf 'Build Me Godot local requirement check\n'
    printf 'Project: %s\n\n' "$project_root"

    check_godot_project
    check_command godot "Godot executable" "Install Godot 4.x and ensure 'godot' is on PATH."
    check_command blender "Blender executable" "Install Blender 4.2+ and ensure 'blender' is on PATH."
    check_command curl "curl executable" "Install curl with your Linux package manager."
    check_command jq "jq executable" "Install jq with your Linux package manager."
    check_http "$comfyui_url/system_stats" "ComfyUI server at $comfyui_url" \
        "Start ComfyUI: comfyui --listen 127.0.0.1 --port 8188"
    check_comfyui_helper
    check_comfyui_nodes
    check_comfyui_model_files
    check_ollama_models

    if [[ ${#warn_labels[@]} -gt 0 ]]; then
        printf '\nWarnings:\n'
        printf '  - %s\n' "${warn_labels[@]}"
    fi
    print_remediation

    [[ ${#missing_labels[@]} -eq 0 ]]
}

main "$@"
