#!/usr/bin/env bash
#SBATCH --job-name=install-lfric-apps-isambard-env
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=144
#SBATCH --mem=192G
#SBATCH --time=12:00:00
#SBATCH --output=install-lfric-apps-isambard-env.%j.out
#SBATCH --error=install-lfric-apps-isambard-env.%j.out

if [ -n "${SLURM_SUBMIT_DIR:-}" ]; then
  if [ -f "$SLURM_SUBMIT_DIR/install.sh" ]; then
    ROOT_DIR="$SLURM_SUBMIT_DIR"
  elif [ -f "$SLURM_SUBMIT_DIR/env_lfric/install.sh" ]; then
    ROOT_DIR="$SLURM_SUBMIT_DIR/env_lfric"
  else
    ROOT_DIR="$SLURM_SUBMIT_DIR"
  fi
else
  ROOT_DIR="$PWD"
fi
cd "$ROOT_DIR" || exit 1

# Tie Spack parallelism to the Slurm allocation.
export SPACK_JOBS=32

# Optional: override these from sbatch --export if needed.
: "${WORKING_DIR:=$ROOT_DIR/working_dir}"
: "${ENV_NAME:=lfric-apps-isambard}"
: "${UPDATE_REPOS:=1}"

# Pin working_dir repos to known-good revisions for reproducibility.
: "${LFRIC_APPS_REF:=e906813e45406163723ad697584b500161a8874e}"
: "${LFRIC_CORE_REF_OVERRIDE:=da8a926408be418a8bf4da1f7caaa9791d0b37ca}"
: "${SIMIT_SPACK_REF:=ece4c48121791f2f1fef5d5999ccf75e74df520e}"
: "${SPACK_REF:=73eaea13f381e3495299284856fd02a64e1d154c}"
: "${UOE_SPACK_REF:=16b095587a8f04282ed8de8fe419a1fad1ff36e9}"

./install.sh
