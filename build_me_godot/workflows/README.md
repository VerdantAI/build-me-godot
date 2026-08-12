# Build Me Godot Project Workflows

This folder holds project-local ComfyUI workflows for artist tuning. These files
are not part of the packaged addon and should stay under `res://build_me_godot/`.

## qwen_blender_reference_set_ui.json

ComfyUI UI workflow for generating a Blender-friendly character reference set.
It starts with a positive character prompt and negative preservation prompt,
generates a canonical front reference, then uses Qwen Image Edit to produce
matching views:

- `canonical.png`
- `front.png`
- `right.png`
- `back.png`
- `left.png`
- `front_3q.png`
- `back_3q.png`
- `turnaround_sheet.png`

The workflow intentionally produces separate images as well as a sheet because
Blender modeling, material blocking, and validation are easier when each view can
be used as an independent reference plane.

Research notes:

- Qwen Image Edit 2511 is a practical local/open model choice for this task
  because its model card calls out improved character consistency, lower image
  drift, LoRA support, and Apache-2.0 licensing.
- LightX2V's Qwen Image Edit 2511 Lightning LoRA keeps the edit stage fast with
  a 4-step distilled LoRA and is also listed as Apache-2.0.
- Dedicated turnaround-sheet LoRAs can be useful for a single composited sheet,
  but this first workflow keeps the existing multi-view edit graph because we
  need separate per-view image files for Blender.

No model weights are bundled here. Install ComfyUI, required nodes, and model
weights manually from their upstream publishers.
