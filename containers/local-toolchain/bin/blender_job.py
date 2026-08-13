#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a headless Blender job")
    parser.add_argument("--script", required=True, type=Path)
    parser.add_argument("args", nargs=argparse.REMAINDER)
    parsed = parser.parse_args()
    if not parsed.script.is_file():
        raise SystemExit(f"Blender script not found: {parsed.script}")
    command = ["blender", "-b", "--python", str(parsed.script)]
    if parsed.args:
        command.extend(["--", *parsed.args])
    return subprocess.run(command, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
