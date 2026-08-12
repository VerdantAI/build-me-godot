#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
default_config_path="$project_root/utils/check-local-requirements.local.conf"
config_path="${BUILD_ME_GODOT_SETUP_CONFIG:-$default_config_path}"

raw_args=("$@")
for ((i = 0; i < ${#raw_args[@]}; i++)); do
    if [[ "${raw_args[$i]}" == "--config" ]]; then
        config_path="${raw_args[$((i + 1))]:?--config requires a value}"
        break
    fi
done

if [[ -f "$config_path" ]]; then
    # shellcheck source=/dev/null
    source "$config_path"
fi

comfyui_url="${BUILD_ME_GODOT_COMFYUI_URL:-http://127.0.0.1:8188}"
comfyui_root="${BUILD_ME_GODOT_COMFYUI_ROOT:-}"
comfyui_root_source=""
download_dir="${BUILD_ME_GODOT_MODEL_DOWNLOAD_DIR:-$(pwd -P)}"
blender_path="${BUILD_ME_GODOT_BLENDER_PATH:-blender}"
ollama_host="${BUILD_ME_GODOT_OLLAMA_HOST:-${OLLAMA_HOST:-http://127.0.0.1:11434}}"
ollama_models_dir="${BUILD_ME_GODOT_OLLAMA_MODELS_DIR:-${OLLAMA_MODELS:-$HOME/.ollama/models}}"
workflow_requirements=(
    "$project_root/addons/build_me_godot/workflows/canonical_only_api.requirements.json"
    "$project_root/addons/build_me_godot/workflows/multiview_only_api.requirements.json"
    "$project_root/build_me_godot/workflows/qwen_blender_reference_set_ui.requirements.json"
)
ollama_models=()
if [[ -n "${BUILD_ME_GODOT_OLLAMA_MODELS:-}" ]]; then
    read -r -a ollama_models <<<"${BUILD_ME_GODOT_OLLAMA_MODELS}"
fi
interactive=1
download_missing_models=0
write_local_config=0
missing_model_rows=()

usage() {
    cat <<'EOF'
Usage: utils/check-local-requirements.sh [options]

Checks local Build Me Godot requirements and prints explicit user-run install
commands for anything missing. The script does not install packages, download
models, or modify external tool directories. If --comfyui-root is omitted, the
script tries to discover a running local ComfyUI process and prompts for the
root directory when running interactively.

Options:
  --config PATH              Read setup defaults from PATH.
  --comfyui-url URL          ComfyUI server URL. Default: http://127.0.0.1:8188
  --comfyui-root PATH        Existing local ComfyUI root for model-file checks.
  --blender PATH             Blender executable path or command. Default: blender
  --model-download-dir PATH  Directory for optional model downloads. Default: $PWD
  --download-missing-models  Download missing declared model files to $PWD.
  --write-local-config       Write discovered/current settings to local config.
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
        --config)
            config_path="${2:?--config requires a value}"
            shift 2
            ;;
        --comfyui-url)
            comfyui_url="${2:?--comfyui-url requires a value}"
            shift 2
            ;;
        --comfyui-root)
            comfyui_root="${2:?--comfyui-root requires a value}"
            comfyui_root_source="command line"
            shift 2
            ;;
        --blender)
            blender_path="${2:?--blender requires a value}"
            shift 2
            ;;
        --model-download-dir)
            download_dir="${2:?--model-download-dir requires a value}"
            shift 2
            ;;
        --ollama-model)
            ollama_models+=("${2:?--ollama-model requires a value}")
            shift 2
            ;;
        --download-missing-models)
            download_missing_models=1
            shift
            ;;
        --write-local-config)
            write_local_config=1
            shift
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
detected_godot_path=""
detected_blender_path=""
detected_ollama_path=""

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

shell_quote() {
    printf '%q' "$1"
}

join_lines() {
    awk 'BEGIN {first = 1} {if (!first) printf ", "; printf "%s", $0; first = 0}'
}

resolve_executable() {
    local executable="$1"
    if [[ "$executable" == */* ]]; then
        [[ -x "$executable" ]] && printf '%s\n' "$executable"
    else
        command -v "$executable" 2>/dev/null || true
    fi
}

is_comfyui_root() {
    local candidate="$1"
    [[ -n "$candidate" ]] || return 1
    [[ -d "$candidate/custom_nodes" ]] || return 1
    [[ -d "$candidate/models" || -f "$candidate/main.py" || -d "$candidate/user" ]]
}

comfyui_port_from_url() {
    sed -E 's#^[a-zA-Z]+://(\[[^]]+\]|[^/:]+):([0-9]+).*#\2#' <<<"$comfyui_url"
}

discover_comfyui_root_from_listener() {
    have_command ss || return 1

    local port pid cwd parent
    port=$(comfyui_port_from_url)
    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    pid=$(ss -ltnp 2>/dev/null \
        | awk -v port=":$port" '$4 ~ port "$" {print $0; exit}' \
        | sed -nE 's/.*pid=([0-9]+).*/\1/p')
    [[ -n "$pid" ]] || return 1

    cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)
    if is_comfyui_root "$cwd"; then
        comfyui_root="$cwd"
        comfyui_root_source="running process cwd for pid $pid"
        return 0
    fi

    parent=$(dirname "$cwd" 2>/dev/null || true)
    if is_comfyui_root "$parent"; then
        comfyui_root="$parent"
        comfyui_root_source="parent of running process cwd for pid $pid"
        return 0
    fi

    return 1
}

discover_comfyui_root_from_common_paths() {
    local candidate
    for candidate in \
        "$PWD/ComfyUI" \
        "$HOME/ComfyUI" \
        "$HOME/src/ComfyUI" \
        "$HOME/verdant/ComfyUI" \
        "$HOME/.local/share/ComfyUI"; do
        if is_comfyui_root "$candidate"; then
            comfyui_root="$candidate"
            comfyui_root_source="common path"
            return 0
        fi
    done
    return 1
}

resolve_comfyui_root() {
    if [[ -n "$comfyui_root" ]]; then
        if is_comfyui_root "$comfyui_root"; then
            comfyui_root_source="${comfyui_root_source:-configured path}"
            print_check "ok" "ComfyUI root: $comfyui_root ($comfyui_root_source)"
        else
            print_check "missing" "Configured ComfyUI root is not valid: $comfyui_root"
            record_missing "Configured ComfyUI root" \
                "Set BUILD_ME_GODOT_COMFYUI_ROOT or rerun with --comfyui-root /path/to/ComfyUI."
            comfyui_root=""
        fi
        return
    fi

    if discover_comfyui_root_from_listener || discover_comfyui_root_from_common_paths; then
        print_check "ok" "ComfyUI root: $comfyui_root ($comfyui_root_source)"
        return
    fi

    if [[ "$interactive" -eq 1 && -t 0 ]]; then
        local entered
        printf '[prompt] ComfyUI root was not found automatically.\n'
        read -r -p "Enter ComfyUI root path, or leave blank to skip file checks: " entered
        if [[ -n "$entered" ]]; then
            if is_comfyui_root "$entered"; then
                comfyui_root="$entered"
                comfyui_root_source="interactive prompt"
                print_check "ok" "ComfyUI root: $comfyui_root ($comfyui_root_source)"
            else
                print_check "missing" "ComfyUI root path is not valid: $entered"
                record_missing "ComfyUI root" \
                    "Rerun with --comfyui-root /path/to/ComfyUI after selecting an existing ComfyUI directory."
            fi
        else
            print_check "skip" "ComfyUI root file checks"
        fi
    else
        print_check "skip" "ComfyUI root: not configured and not discovered"
    fi
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

check_executable() {
    local executable="$1"
    local label="$2"
    local install_hint="$3"
    local detected

    detected=$(resolve_executable "$executable")
    if [[ -n "$detected" ]]; then
        print_check "ok" "$label: $detected"
        case "$label" in
            "Godot executable") detected_godot_path="$detected" ;;
            "Blender executable") detected_blender_path="$detected" ;;
            "Ollama executable") detected_ollama_path="$detected" ;;
        esac
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
        unique=$(printf '%s\n' "${missing[@]}" | sort -u | join_lines)
        print_check "missing" "ComfyUI required workflow nodes: $unique"
        record_missing "ComfyUI required workflow nodes" \
            "Open ComfyUI Manager and install the missing node packs, then restart ComfyUI. Missing classes: $unique"
    fi
}

model_subdirs_for_loader() {
    case "$1" in
        CLIPLoader) printf '%s\n' "models/text_encoders" "models/clip" ;;
        VAELoader) printf '%s\n' "models/vae" ;;
        UNETLoader) printf '%s\n' "models/unet" "models/diffusion_models" ;;
        LoraLoaderModelOnly) printf '%s\n' "models/loras" ;;
        *) printf '%s\n' "models" ;;
    esac
}

model_download_url() {
    local repository="$1"
    local value="$2"

    case "$repository|$value" in
        "Comfy-Org/Qwen-Image_ComfyUI|qwen_2.5_vl_7b_fp8_scaled.safetensors")
            printf '%s\n' "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"
            ;;
        "Comfy-Org/Qwen-Image_ComfyUI|qwen_image_vae.safetensors")
            printf '%s\n' "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"
            ;;
        "Comfy-Org/Qwen-Image_ComfyUI|qwen_image_2512_fp8_e4m3fn.safetensors")
            printf '%s\n' "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors"
            ;;
        "Comfy-Org/Qwen-Image-Edit_ComfyUI|qwen_image_edit_2511_fp8mixed.safetensors")
            printf '%s\n' "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors"
            ;;
        "lightx2v/Qwen-Image-Edit-2511-Lightning|Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors")
            printf '%s\n' "https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors"
            ;;
        "Wuli-art/Qwen-Image-2512-Turbo-LoRA-2-Steps|Wuli-Qwen-Image-2512-Turbo-LoRA-2steps-V1.0-bf16.safetensors")
            printf '%s\n' "https://huggingface.co/Wuli-art/Qwen-Image-2512-Turbo-LoRA-2-Steps/resolve/main/Wuli-Qwen-Image-2512-Turbo-LoRA-2steps-V1.0-bf16.safetensors"
            ;;
        *)
            printf '%s\n' "https://huggingface.co/$repository/resolve/main/$value"
            ;;
    esac
}

download_missing_model_files() {
    if [[ ${#missing_model_rows[@]} -eq 0 ]]; then
        return
    fi
    if ! have_command curl; then
        record_missing "Model downloader" "Install curl before using --download-missing-models."
        return
    fi

    local row loader value repository url target
    printf '\nDownloading missing model files into current directory:\n%s\n\n' "$download_dir"
    for row in "${missing_model_rows[@]}"; do
        IFS=$'\t' read -r loader value repository url <<<"$row"
        target="$download_dir/$value"
        if [[ -f "$target" ]]; then
            printf '[ok] %s already exists in current directory\n' "$value"
            continue
        fi
        printf '[download] %s\n' "$value"
        printf '           %s\n' "$url"
        curl --location --fail --continue-at - --output "$target" "$url"
    done
}

maybe_prompt_download_missing_models() {
    if [[ ${#missing_model_rows[@]} -eq 0 ]]; then
        return
    fi

    if [[ "$download_missing_models" -eq 1 ]]; then
        download_missing_model_files
        return
    fi

    if [[ "$interactive" -eq 1 && -t 0 ]]; then
        local answer
        printf '\nMissing model download option:\n'
        printf 'Download missing declared model files into current directory?\n'
        printf 'Target: %s\n' "$download_dir"
        read -r -p "Download now? [y/N] " answer
        case "$answer" in
            y|Y|yes|YES)
                download_missing_model_files
                ;;
            *)
                printf 'Skipped model downloads.\n'
                ;;
        esac
    fi
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
            missing_model_rows+=("$loader"$'\t'"$value"$'\t'"$repository"$'\t'"$(model_download_url "$repository" "$value")")
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
        local commands
        commands=$(for row in "${missing_model_rows[@]}"; do
            IFS=$'\t' read -r loader value repository url <<<"$row"
            printf "curl --location --fail --continue-at - --output './%s' '%s'\n" "$value" "$url"
        done)
        print_check "missing" "ComfyUI declared model files"
        record_missing "ComfyUI declared model files" \
            "Download the declared Apache-2.0 model artifacts manually into the current directory ($download_dir), then move them into the matching ComfyUI models subdirectories:"$'\n'"$summary"$'\n\n'"Download commands:"$'\n'"$commands"
    fi
}

check_ollama_models() {
    if [[ ${#ollama_models[@]} -eq 0 ]]; then
        print_check "skip" "Ollama models: pass --ollama-model NAME to require one"
        return
    fi

    check_executable "ollama" "Ollama executable" \
        "Install Ollama from https://ollama.com/download/linux, then run this script again."
    if [[ -z "$detected_ollama_path" ]]; then
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

write_config_file() {
    local target="$1"
    local target_dir
    target_dir=$(dirname "$target")
    mkdir -p "$target_dir"

    local ollama_model_text=""
    if [[ ${#ollama_models[@]} -gt 0 ]]; then
        ollama_model_text="${ollama_models[*]}"
    fi

    cat >"$target" <<EOF
# Build Me Godot local setup configuration.
# This file is machine-local and intentionally gitignored.

BUILD_ME_GODOT_COMFYUI_URL=$(shell_quote "$comfyui_url")
BUILD_ME_GODOT_COMFYUI_ROOT=$(shell_quote "$comfyui_root")
BUILD_ME_GODOT_MODEL_DOWNLOAD_DIR=$(shell_quote "$download_dir")
BUILD_ME_GODOT_BLENDER_PATH=$(shell_quote "${detected_blender_path:-$blender_path}")
BUILD_ME_GODOT_OLLAMA_HOST=$(shell_quote "$ollama_host")
BUILD_ME_GODOT_OLLAMA_MODELS_DIR=$(shell_quote "$ollama_models_dir")
BUILD_ME_GODOT_OLLAMA_MODELS=$(shell_quote "$ollama_model_text")

# ComfyUI model placement guide:
# text encoders: \$BUILD_ME_GODOT_COMFYUI_ROOT/models/text_encoders/
# diffusion models: \$BUILD_ME_GODOT_COMFYUI_ROOT/models/diffusion_models/
# VAEs: \$BUILD_ME_GODOT_COMFYUI_ROOT/models/vae/
# LoRAs: \$BUILD_ME_GODOT_COMFYUI_ROOT/models/loras/
EOF
    print_check "ok" "Wrote local setup config: $target"
}

maybe_write_local_config() {
    if [[ "$write_local_config" -eq 1 ]]; then
        write_config_file "$config_path"
        return
    fi

    if [[ -f "$config_path" ]]; then
        return
    fi

    if [[ "$interactive" -eq 1 && -t 0 ]]; then
        local answer
        printf '\nLocal config option:\n'
        printf 'Write discovered setup paths for reuse?\n'
        printf 'Target: %s\n' "$config_path"
        read -r -p "Write local config now? [y/N] " answer
        case "$answer" in
            y|Y|yes|YES)
                write_config_file "$config_path"
                ;;
            *)
                printf 'Skipped local config write.\n'
                ;;
        esac
    fi
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
    check_executable godot "Godot executable" "Install Godot 4.x and ensure 'godot' is on PATH."
    check_executable "$blender_path" "Blender executable" \
        "Install Blender 4.2+ and ensure the configured Blender command or path is executable."
    check_command curl "curl executable" "Install curl with your Linux package manager."
    check_command jq "jq executable" "Install jq with your Linux package manager."
    check_http "$comfyui_url/system_stats" "ComfyUI server at $comfyui_url" \
        "Start ComfyUI: comfyui --listen 127.0.0.1 --port 8188"
    resolve_comfyui_root
    check_comfyui_helper
    check_comfyui_nodes
    check_comfyui_model_files
    check_ollama_models
    maybe_prompt_download_missing_models
    maybe_write_local_config

    if [[ ${#warn_labels[@]} -gt 0 ]]; then
        printf '\nWarnings:\n'
        printf '  - %s\n' "${warn_labels[@]}"
    fi
    print_remediation

    [[ ${#missing_labels[@]} -eq 0 ]]
}

main "$@"
