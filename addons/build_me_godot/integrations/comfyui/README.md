# ComfyUI integration

Build Me Godot communicates with an independently installed, local ComfyUI server. It does not install ComfyUI, custom nodes, Python packages, or model weights.

The bundled turnaround workflows require `character_turnaround_output.py`. Copy that file into the existing ComfyUI installation's `custom_nodes/character_turnaround_output.py`, then restart ComfyUI. The helper is MIT licensed and only loads, normalizes, composes, and saves local turnaround images.

The editable workflow is `workflows/character_turnaround_open.json`. Execution is deliberately staged into `canonical_only_api.json` and `multiview_only_api.json` so the canonical and edit diffusion models do not need to remain loaded together on lower-memory workstations.

Required model weights are not included. Review the model card and weight license for every installed model; a permissive source-code license does not establish the weight license.
