## Provider Boundary

The TRELLIS wrapper is a user-managed local command. It accepts the existing
Build Me Godot provider contract:

```text
--input <image> --output <mesh.glb> --metadata-output <metadata.json>
```

The wrapper requires:

- `BUILD_ME_GODOT_TRELLIS_ROOT` or `TRELLIS_ROOT` pointing at a local
  `microsoft/TRELLIS` checkout;
- `BUILD_ME_GODOT_TRELLIS_MODEL_PATH` pointing at a local
  `TRELLIS-image-large` model folder;
- optionally `BUILD_ME_GODOT_TRELLIS_PYTHON` pointing at the user's TRELLIS
  Python environment.

The wrapper sets `HF_HUB_OFFLINE=1` unless the user already configured it, so
passing a Hugging Face repo id is not enough. A missing local model folder
should fail before generation.

## Setup Utility

The repository setup utility reports:

- `trellis.root`;
- `trellis.model`;
- `trellis.provider`;
- manual action `manual.install.trellis.provider` with exact commands to
  review upstream sources, create a separate environment, and configure the
  wrapper.

The manual action is non-mutating. It is a remediation guide, not an installer.

## Runtime Strategy

The first implementation uses original TRELLIS, not TRELLIS.2. Original
TRELLIS has lower documented VRAM requirements than TRELLIS.2 and simpler
model output handling. TRELLIS.2 remains a later candidate after reviewing
`nvdiffrast`, `nvdiffrec`, `CuMesh`, `FlexGEMM`, and O-Voxel licensing and
container build behavior.
