## Research Notes

Best automated local path:

1. Prepare clean reference inputs from the approved ComfyUI run: front or
   front-three-quarter for single-image reconstruction, with front/side/back
   retained for validation.
2. Run a local user-managed proxy reconstruction provider. TripoSR is the first
   target because its reviewed implementation and weights are MIT, has a low
   VRAM profile for draft proxy geometry, and produces mesh outputs quickly.
3. Treat the proxy as a measuring object only. Import it into Blender as
   immutable reference geometry and compare against the source mannequin and
   approved reference planes.
4. Generate duplicate-only conformance work meshes and separate field-engineer
   clothing/prop candidates. Do not rewrite source rigs, source meshes, stable
   bone names, sockets, or the `neutral_a_pose_30deg_v1` pose contract.
5. Use optional vision-language analysis, including Ollama when configured, for
   semantic JSON such as hardhat, high-visibility garment, boots, belt,
   clipboard/tablet, radio, and material/color targets. Do not use LLM output
   as geometry without review.

## Provider Command Contract

The configured reconstruction command is a user-owned executable. Build Me
Godot invokes it only from an explicit command such as:

```text
character_cli.gd -- generate-proxy --character-id field_engineer --version v1 --provider triposr
```

The command receives file paths, never `res://` paths:

```text
<command> \
  --input <absolute/front-or-canonical-image.png> \
  --output <absolute/proxy_meshes/triposr_front.glb> \
  --metadata-output <absolute/reports/triposr_front_metadata.json>
```

The command must exit `0`, write the declared output mesh, and optionally write
JSON metadata. Build Me Godot records:

- provider id and role;
- command path or configured command label;
- input image path in project-relative form;
- output mesh path in project-relative form;
- metadata/report path when present;
- exit code and stderr/stdout summary;
- license record already reviewed in `LICENSES.md`;
- generated timestamp.

The default provider command adapter should be testable with a mock script. It
must not assume that a real TripoSR checkout or model weights exist.

## Blender Automation

After proxy generation, `prepare_conformance_handoff.py` should:

- import proxy meshes into `AI_PROXY_MESH_REFERENCES`;
- align proxy bounds with the duplicate source-mesh bounds in the
  `neutral_a_pose_30deg_v1` frame;
- compute per-view silhouette and bounding-box deltas;
- tag source/proxy/reference objects as non-exportable reference objects;
- emit `conformance_guidance.json` with body-region scale hints, clothing shell
  candidates, prop candidates, material/color targets, warnings, and changed
  paths;
- leave actual deformation as duplicate-only work geometry or modifiers that an
  artist can review in Blender.

The first automated pass may create coarse placeholder meshes for hardhat,
vest, belt, boots, clipboard/tablet, and radio when the target exists in the
plan. These placeholders are production candidates only after explicit review.

## Setup App Contract

Whenever a provider is promoted from manual import to supported command
execution, the environment/install utilities must expose:

- stable read-only checks for command availability and `--version` probing;
- provider requirements from packaged JSON;
- install-plan/manual-action output naming the source project, license, expected
  external environment, output formats, and verification checks;
- no passive mutations;
- explicit apply actions only for mutation classes already approved by repo
  policy.

For TripoSR in this change, automatic clone/package/weight installation remains
out of scope. The setup app should manage configuration and verification, not
installation.

The repository-level setup utility may offer an explicit
`download.triposr.models` action for the reviewed `stabilityai/TripoSR`
`config.yaml` and `model.ckpt` artifacts. That action stages files under the
configured model-download directory and reports changed paths; it does not
install TripoSR, install Python packages, clone repositories, move files into a
provider checkout, or configure the runtime wrapper.

Ollama is not a TripoSR wrapper. Current Ollama support covers LLM and
multimodal/vision inference through Ollama-managed model formats; it does not
execute arbitrary image-to-3D reconstruction pipelines. Use Ollama only for
optional semantic/vision JSON review unless a separate user-authored wrapper
script chooses to call Ollama for analysis and TripoSR for geometry.

When ComfyUI is already the orchestration surface, prefer an existing local
ComfyUI TripoSR node before writing a custom wrapper. The first supported
Comfy-native candidate is `flowtyone/ComfyUI-Flowty-TripoSR`: it is local,
does not require API keys, exposes `TripoSRModelLoader`, `TripoSRSampler`, and
`TripoSRViewer`, and writes OBJ proxy meshes through ComfyUI output. Its code
license is GPL-3.0, so Build Me Godot must not bundle or copy its code into
the MIT addon. The setup app may offer explicit user-approved staging and
installation actions with a GPL-3.0 notice, while Python dependency
installation remains manual/operator work.

## Hard Blockers

Stop at the operator point when any of these are true:

- no configured provider command is available and no proxy mesh is manually
  supplied;
- the configured provider command fails or does not write the expected mesh;
- generated guidance indicates source rig/skeleton/socket mutation would be
  required;
- a desired provider requires unreviewed downloads, unclear weight licenses, or
  hosted-only/API access;
- Blender cannot load the generated proxy or write the handoff report.
