# Isambard3 LFRic Environment + Science Suites

This repository is a handover bundle that keeps the Isambard LFRic Spack
environment and the science suites together so they stay in sync.

## Directories

- `env_lfric/`: Spack environment, install/activate/verify scripts, and
  supporting files needed to build and run LFRic apps on Isambard.
- `suites/`: Rose/Cylc science suites (each subdirectory is a suite ID).

## Quick Start

1. Build or activate the environment using `env_lfric/README.md`.
2. Pick a suite from `suites/` and follow its README (where present).
3. Ensure the environment is active before running any suite.

## Notes

- `env_lfric/` can be used standalone, but this repo keeps the environment and
  suites aligned for handover.
- Runtime artifacts (for example `working_dir/` and log files) are generated
  during installs/runs and are ignored by default.
