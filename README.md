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

If you are new to Spack on Isambard 3, the
[Isambard 3 Spack setup guide](https://docs.isambard.ac.uk/user-documentation/guides/spack/setup/)
is a useful reference before running the environment install.

1. Choose your toolchain and follow its README:
   `env_lfric_gcc/README.md` or `env_lfric_nvhpc/README.md`.
2. Pick a suite from `suites/` and follow its README (where present).
3. Ensure the environment is active before running any suite.
4. Run `./tests/xios_verification.sh` from the repo root if you want to check
   the migrated XIOS source before a full Spack install.

## Notes

- Each `env_lfric_*` directory can be used standalone, but this repo keeps the
  environments and suites aligned for handover.
- XIOS is now pinned to the IPSL GitLab mirror of the former revision `2252`
  rather than the retired SVN endpoint.
- Runtime artifacts (for example `working_dir/` and log files) are generated
  during installs/runs and are ignored by default.

## Cylc VIP And SSH

`cylc vip` relies on standard SSH authentication to reach the scheduler host.
Make sure you have an SSH agent running with your private key loaded.

1. Start an agent (if you do not already have one):
   ```bash
   eval "$(ssh-agent -s)"
   ```
2. Add your key:
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```
3. Confirm it is loaded:
   ```bash
   ssh-add -l
   ```

## GitHub Access And MetOffice SSO

During the suite `extract` step, `get_git_sources.py` clones the MetOffice
repositories listed in `suites/<suite>/dependencies.yaml`. The MetOffice
GitHub organization enforces SAML SSO, so GitHub will return `403` errors until
your credentials are explicitly authorized for the org. This applies to both
HTTPS tokens and SSH keys.

The environment installs use SSH by default (`USE_GITHUB_SSH=1` in
`env_lfric_*/install.sh`), and expect an SSH key at
`~/.ssh/id_ed25519` unless you override it via `GITHUB_SSH_KEY`.
The installer can use a live SSH agent, or it can call SSH directly with
`GITHUB_SSH_KEY`. For non-interactive Slurm jobs using an encrypted key, export
`GITHUB_SSH_PASSPHRASE` or use HTTPS with a GitHub token.

```bash
# SSH (default for install.sh and preferred for workflows):
export GITHUB_SSH_KEY="$HOME/.ssh/id_ed25519"  # or your actual key path
# One-time: add the public key to GitHub and authorize it for MetOffice SSO.
ssh -T git@github.com
git ls-remote git@github.com:MetOffice/jules.git >/dev/null
```

If you see:
`SSH key not found at /home/.../.ssh/id_ed25519`
then either generate a key (e.g. `ssh-keygen -t ed25519`) or point
`GITHUB_SSH_KEY` at your existing key before running the install or suite.

### Creating And Authorizing An SSH Key (GitHub + MetOffice SSO)

1. Create a new SSH key (press enter for the default path, which the suites expect):
   ```bash
   ssh-keygen -t ed25519 -C "your.email@domain"
   ```
2. Start an agent and load the key:
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ssh-add -l
   ```
3. Copy the public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
4. Add the key in GitHub:
   - Go to your GitHub settings page for SSH keys:
     ```text
     https://github.com/settings/keys
     ```
   - Click “New SSH key”, paste the public key, and save.
5. Authorize the key for MetOffice SSO:
   - Go to Settings -> SSH and GPG Keys (https://github.com/settings/keys)
   - For the key that you have created click the drop down for "Configure SSO"
   - Login and Authorize the key for use with the MetOffice
6. Verify access:
   ```bash
   ssh -T git@github.com
   git ls-remote git@github.com:MetOffice/jules.git
   ```
