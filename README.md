# Isambard3 LFRic Environment + Science Suites

This repository is a handover bundle that keeps the Isambard LFRic Spack
environment and the science suites together so they stay in sync.

## Directories

- `env_lfric_gcc/`: GNU (gfortran) toolchain environment.
- `env_lfric_nvhpc/`: NVIDIA (nvfortran) toolchain environment.
- `suites/`: Rose/Cylc science suites (each subdirectory is a suite ID).

See also:
- `env_lfric_gcc/README.md`
- `env_lfric_nvhpc/README.md`
- `suites/README.md`

## Quick Start

1. Choose your toolchain and follow its README:
   `env_lfric_gcc/README.md` or `env_lfric_nvhpc/README.md`.
2. Pick a suite from `suites/` and follow its README (where present).
3. Ensure the environment is active before running any suite.

## Notes

- Each `env_lfric_*` directory can be used standalone, but this repo keeps the
  environments and suites aligned for handover.
- Runtime artifacts (for example `working_dir/` and log files) are generated
  during installs/runs and are ignored by default.
