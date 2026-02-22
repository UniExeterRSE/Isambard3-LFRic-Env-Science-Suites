#!/usr/bin/env bash
#SBATCH --job-name=install-lfric-apps-isambard-env
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=144
#SBATCH --mem=192G
#SBATCH --time=12:00:00
#SBATCH --output=install-lfric-apps-isambard-env.%j.out
#SBATCH --error=install-lfric-apps-isambard-env.%j.out

ROOT_DIR="${ROOT_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"

# Tie Spack parallelism to the Slurm allocation.
export SPACK_JOBS=32

# Optional: override these from sbatch --export if needed.
: "${WORKING_DIR:=$ROOT_DIR/working_dir}"
: "${ENV_NAME:=lfric-apps-isambard}"

./install.sh
