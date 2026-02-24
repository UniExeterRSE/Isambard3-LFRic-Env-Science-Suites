# LFRic Spack Environment (Isambard)

This directory provides a portable Spack environment for LFRic Apps
build/run dependencies. It defines the `lfric-apps-isambard` bundle package,
plus scripts that install, activate, and validate the environment.

Start here for day-to-day usage (login or compute nodes):
```
source env_lfric_gcc/activate.sh
```
`activate.sh` loads the local Spack install, activates the environment, and
puts the environment view on `PATH`. This is the preferred entrypoint for
interactive use. From inside this directory, you can also run `source activate.sh`.

See also:
- `../README.md`
- `../env_lfric_nvhpc/README.md`
- `../suites/README.md`

## The Spack Environment

- `lfric-isambard-spack_repo/repo.yaml` — declares the local Spack repo.
- `lfric-isambard-spack_repo/packages/lfric-apps-isambard/package.py` — bundle
  package and dependency list/versions/variants.
- `spack-envs/lfric-apps-isambard/spack.yaml` — example environment manifest
  (template).

The bundle pulls packages from the Met Office `simit-spack` repo (for example
`xios`, `shumlib`, `foxml`, `rose-picker`, `metomi-rose`, `cylc-flow`, and
`cylc-rose`). MPI is pinned to `mpich` and Python to `3.11` to match the LFRic
environment.

## Install (Login Node)

The end-to-end installer clones source repos, builds the Spack environment
under `working_dir/`, then builds and runs `lfric_atm`.

```
./install.sh > install.log 2>&1
```

To use HTTPS instead of SSH, set `USE_GITHUB_SSH=0` (and `GITHUB_TOKEN` or
`GH_TOKEN` for private repos).

Please note that you will need to use this installer for the time being to be
able to use the environment as there are modifications that need to be made to
`simit-spack` to bring it into line with the current iterations of Spack.

## Install (Compute Node via Slurm)

Use the Slurm wrapper to run the build on a compute node:

```
sbatch compute_node_install.slurm
```

The wrapper sets `SPACK_JOBS` and runs `./install.sh`. Override `WORKING_DIR`
and `ENV_NAME` via `sbatch --export` if needed.

## Rose/Cylc Environment Check

For a quick environment-only check (no build), use:

```
./verification.sh > verification.log 2>&1
```

The script sources the local Spack install, activates `lfric-apps-isambard`,
prints spec/find output for rose/cylc, loads the packages, and prints paths and
versions. Set `EXTENDED_TOOL_VALIDATION=0` to skip the extended diagnostics.

## Cylc GUI

Launch the GUI without opening a browser:

```
cylc gui --no-browser
```

## Relationship To `rose/`

The `rose/` directory is a separate handover area for running rose-stem
experiments (Epic/DIaL3/Monsoon). It uses the Spack environment built here, but
adds local compatibility shims so Cylc 8.6.2 can run the `lfric_apps` rose-stem
suite without touching the Spack env. See `rose/README.md` for details.

## Driver Configuration (Optional)

Common overrides:

- Default compiler is GNU12 (`gcc@12.3.0`) to match the cluster-tested setup.
- `WORKING_DIR=/path/to/working_dir`
- `USE_GITHUB_SSH=0|1` (default: `1`)
- `LFRIC_APPS_REF=e906813e45406163723ad697584b500161a8874e`
- `LFRIC_APPS_DEPTH=1`
- `LFRIC_CORE_DEPTH=...`
- `SPACK_REF=73eaea13f381e3495299284856fd02a64e1d154c`
- `SPACK_DIR=/path/to/spack`
- `ENV_NAME=lfric-apps-isambard`
- `ENV_DIR=/path/to/env_dir`
- `REGEN_ENV=0|1`
- `SPACK_JOBS=16`
- `MAKE_JOBS=8`
- `COMPILER_SPEC=gcc@12.3.0`
- `SIMIT_SPACK_DIR=/path/to/simit-spack`
- `SIMIT_SPACK_REF=ece4c48121791f2f1fef5d5999ccf75e74df520e`
- `CLONE_SIMIT_SPACK=0|1` (default: `1`)
- `CLONE_UOE_REPO=0|1` (default: `1`)
- `UOE_SPACK_REF=16b095587a8f04282ed8de8fe419a1fad1ff36e9`
- `USE_UOE_REPO=0|1` (default: `0`)
- `RUN_ROSE_CYLC=0|1` (default: `1`)
- `ROSE_STEM_DIR=/path/to/rose-stem` (default: `$WORKING_DIR/lfric_apps/rose-stem`)
- `ROSE_SITE=uoe` (default: `uoe`)
- `ROSE_GROUP=all` (default: `all`)
- `ROSE_CYLC_CMD="rose stem --group=..."` (optional override for the rose/cylc step)
- `EXIT_ON_ERROR=0|1` (default: `0`)

## Layout

- `activate.sh` — loads Spack, activates `lfric-apps-isambard`, loads rose/cylc.
- `install.sh` — end-to-end driver (clone -> Spack env -> build -> run -> rose/cylc checks).
- `compute_node_install.slurm` — Slurm wrapper for the compute-node build.
- `verification.sh` — Spack/rose/cylc environment validation script.
- `clean.sh` — removes the local `working_dir` artifacts (safety clean-up).
- `spack-envs/` — Spack environment templates.
- `working_dir/` — runtime artifacts (clones, Spack install, environments, builds).
- `lfric-isambard-spack_repo/` — local Spack repo containing `lfric-apps-isambard`.

## Notes

- By default, `activate.sh` sets the Cylc run base to the directory one level
  above `env_lfric_gcc/` (it writes a managed block into `~/.cylc/flow/global.cylc`).
  Override with `CYLC_RUN_BASE=/path/to/base` before sourcing `activate.sh`.
- The driver writes the active environment manifest under `working_dir/spack-envs/`
  by default (or wherever `ENV_DIR` points); the active environment itself is
  stored under `working_dir/spack/var/spack/environments/<env>`.
- `yaxt` is installed serially before the main install to avoid a known parallel
  install race.
- `netcdf-c` is constrained with `~dap` in the bundle package to avoid optional
  XML/DAP builds.
