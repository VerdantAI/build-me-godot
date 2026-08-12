#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "$0")/.." && pwd)
tmpdir=$(mktemp -d /tmp/build-me-godot-comfyui-client.XXXXXX)
port_file="$tmpdir/port"
server_pid=""

cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$tmpdir"
}
trap cleanup EXIT

python3 "$project_root/tests/mock_comfyui_server.py" "$port_file" &
server_pid=$!

for _ in {1..50}; do
    if [[ -s "$port_file" ]]; then
        break
    fi
    sleep 0.1
done

if [[ ! -s "$port_file" ]]; then
    echo "mock ComfyUI server did not write a port" >&2
    exit 1
fi

BUILD_ME_GODOT_MOCK_COMFYUI_PORT=$(cat "$port_file") \
    godot --headless --path "$project_root" --script res://tests/test_comfyui_client.gd
