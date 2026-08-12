# Dependency license review

This table records reviewed components and whether Build Me Godot redistributes them. A permissive code license does not establish the license of separately published model weights or assets.

| Component | Repository or asset | Code license | Weight/data license | Commercial use | Included? | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Build Me Godot | `VerdantAI/build-me-godot` | MIT | N/A | Yes | Yes | Godot editor addon and local integration source. |
| Godot Engine | `godotengine/godot` | MIT | N/A | Yes | No | Required host editor/runtime. |
| ComfyUI | `Comfy-Org/ComfyUI` | GPL-3.0 | N/A | Yes | No | Independent local server; no code is copied into the addon. |
| Character turnaround helper | Project-local integration | MIT | N/A | Yes | Yes | Local ComfyUI nodes; no downloads or external requests. |
| Qwen-Image-2512 | `Qwen/Qwen-Image-2512` and `Comfy-Org/Qwen-Image_ComfyUI` | Apache-2.0 | Apache-2.0 | Yes | No | Tested canonical model; users install weights explicitly. |
| Wuli Qwen-Image-2512 Turbo LoRA | `Wuli-art/Qwen-Image-2512-Turbo-LoRA-2-Steps` | Apache-2.0 | Apache-2.0 | Yes | No | Optional local acceleration LoRA for Qwen-Image-2512 canonical reference generation; users install weights explicitly. |
| Qwen-Image-Edit-2511 | `Qwen/Qwen-Image-Edit-2511` and `Comfy-Org/Qwen-Image-Edit_ComfyUI` | Apache-2.0 | Apache-2.0 | Yes | No | Tested multiview edit model; users install weights explicitly. |
| LightX2V Qwen-Image-Edit-2511 Lightning LoRA | `lightx2v/Qwen-Image-Edit-2511-Lightning` | Apache-2.0 | Apache-2.0 | Yes | No | Optional local 4-step edit acceleration LoRA for UI-tuned multiview reference workflows; users install weights explicitly. |
| Blender | `blender/blender` | GPL-2.0-or-later | User output unaffected | Yes | No | Independent authoring and automated processing tool. |
| Burb Sweeper humanoid scripts | Inhuman Entertainment Burb Sweeper | MIT | N/A | Yes | Generalized source | Original project-specific paths and asset assumptions removed. |
| Gator Model Studio 1.0.1 | Godot Asset Store, Blackwater Gator Studios | MIT | N/A | Yes | No | Optional in-Godot last-mile refinement solution. |
| Quaternius Universal Animation Library Standard | Quaternius | N/A | CC0-1.0 | Yes | No | Tested animation source; obtain independently and record its path. |
| TripoSR | `VAST-AI-Research/TripoSR` at `107cefdc244c39106fa830359024f6a2f1c78871`; `stabilityai/TripoSR` revision `5b521936b01fbe1890f6f9baed0254ab6351c04a` | MIT | MIT | Yes | Adapter only | Optional user-managed local provider. No checkout, environment, or weights are bundled or installed automatically. |
| Zero123++ | `sudo-ai/zero123plus` distributions | Apache lineage | Non-commercial or unclear exact weights | No/unclear | No | Rejected. |
| FLUX dev models | Black Forest Labs | Mixed code | Non-commercial model license | No | No | Rejected. |
| Hunyuan3D 2.x | Tencent Hunyuan | Open repository | Tencent custom community license | Not accepted by permissive-only policy | No | Rejected as a default dependency. |

This review is not legal advice. Recheck upstream records when changing an exact version, repository, or artifact.
