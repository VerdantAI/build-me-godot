## 1. OpenSpec

- [x] 1.1 Document runtime choice, GPU/CDI practices, model mount strategy,
  license boundary, image modes, and hard blockers.
- [x] 1.2 Add spec deltas for local generation containers and setup utility
  reporting.

## 2. Setup Utility

- [x] 2.1 Add read-only checks for Podman/Docker/Apptainer availability.
- [x] 2.2 Add read-only checks for NVIDIA CDI readiness when NVIDIA tools are
  present.
- [x] 2.3 Discover existing user-owned model/cache roots and report them as
  future container mounts.
- [x] 2.4 Add explicit `write.container.config` action for a gitignored local
  env file.
- [x] 2.5 Add manual NVIDIA CDI remediation output when an NVIDIA GPU is
  present but no CDI spec is detected.

## 3. Documentation and Validation

- [x] 3.1 Document the host-mounted model strategy in setup docs and README.
- [x] 3.2 Run setup tests, parser checks, OpenSpec validation, headless editor
  load, GDScript tests, and `git diff --check`.
- [x] 3.3 Remove setup-app download/install actions for Flowty TripoSR and
  TripoSR checkpoint/model placement now that reconstruction runtime belongs
  to user-managed native installs or the container toolchain.

## 4. Future Explicit Actions

- [x] 4.1 Add a reviewed Containerfile and entrypoint scripts for
  `doctor`, `comfyui-server`, `triposr-job`, and `blender-job`.
- [x] 4.2 Add explicit build/run/stop/smoke-test setup actions that do not
  execute without user approval.
- [x] 4.3 Add a proxy-generation adapter that can call the containerized
  `triposr-job` through the existing provider command contract.
