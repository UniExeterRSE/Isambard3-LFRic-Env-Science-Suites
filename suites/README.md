# LFRic Science Suites (Isambard)

This directory contains Rose/Cylc suites used for LFRic science runs on
Isambard. Each subdirectory is a suite ID (for example `u-dn704`). Some suites
include their own `README.md` with case-specific notes.

## How To Use

1. Build and activate the environment via `env_lfric/README.md`.
2. Enter the suite directory you want to run.
3. Follow the suite README (if present) or the standard Rose/Cylc workflow
   defined by `flow.cylc` and `rose-suite.conf`.

## What To Commit

Keep suite definitions and configuration under version control. Runtime output
is expected to live outside this repo (for example in `working_dir/` or your
Cylc run directory) and should not be committed.
