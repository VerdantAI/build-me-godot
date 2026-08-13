## ADDED Requirements

### Requirement: Local generation containers reuse host-owned model stores

The containerized generation toolchain SHALL mount user-owned model, custom
node, output, and cache directories from the host instead of baking model
weights or generated project assets into distributed images.

#### Scenario: Setup writes container configuration

- **GIVEN** a supported local container runtime is available
- **AND** at least one configured model or cache directory exists on the host
- **WHEN** the user explicitly applies `write.container.config`
- **THEN** the setup utility writes a gitignored local configuration file
- **AND** the file lists host model/cache roots for mounting
- **AND** no image is built, pulled, or run.

#### Scenario: Existing ComfyUI models are reused

- **GIVEN** a configured ComfyUI root has a `models` directory
- **WHEN** a container config is written
- **THEN** that model directory is included in the suggested mounts
- **AND** the image recipe is not required to download duplicate copies of the
  same model weights.

#### Scenario: Reconstruction runtime is not installed by setup

- **GIVEN** Flowty TripoSR or TripoSR checkpoint files are missing from the
  native ComfyUI environment
- **WHEN** the user runs setup checks or plans
- **THEN** their missing state is reported as optional readiness evidence
- **AND** no setup action is offered to download, stage, install, or copy those
  reconstruction runtime files
- **AND** the plan directs users toward existing native installs, mounted
  user-owned model folders, or the reviewed container toolchain path.

### Requirement: Container runtime readiness is advisory

Container readiness checks SHALL be optional and SHALL NOT make native
Godot/ComfyUI/Blender workflows fail when no container runtime is installed.

#### Scenario: No runtime is installed

- **GIVEN** Podman, Docker, and Apptainer are absent
- **WHEN** the user runs setup checks
- **THEN** container runtime readiness is reported as skipped
- **AND** required native workflow checks keep their normal readiness status.

#### Scenario: NVIDIA GPU is present without CDI

- **GIVEN** `nvidia-smi` is available
- **AND** no NVIDIA CDI spec is detected
- **WHEN** the user runs setup checks
- **THEN** the utility reports an advisory warning for container GPU readiness
- **AND** the utility exposes a manual remediation action with NVIDIA CDI
  generation, listing, and Podman GPU smoke-test commands
- **AND** does not install NVIDIA Container Toolkit or edit system CDI files.

### Requirement: Toolchain image exposes separate execution modes

The eventual container image SHALL expose separate modes for a ComfyUI server,
one-shot TripoSR proxy reconstruction, one-shot headless Blender processing,
and read-only doctor checks.

#### Scenario: Agent runs proxy reconstruction through a container

- **GIVEN** a reviewed container image exists
- **AND** the image has access to mounted host model roots and project files
- **WHEN** the existing provider command contract invokes the containerized
  `triposr-job`
- **THEN** the job accepts absolute input, output, and metadata paths
- **AND** writes the proxy mesh and metadata under project-owned conformance
  outputs
- **AND** does not mutate source rigged meshes.
