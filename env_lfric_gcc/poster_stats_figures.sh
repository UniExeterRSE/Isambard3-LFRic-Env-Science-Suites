#!/usr/bin/env bash
set -euo pipefail

SPACK=/lfs1i3/projects/u35v/lberrisford/Isambard3-LFRic-Env-Science-Suites/env_lfric_gcc/working_dir/spack/bin/spack
ENV=/lfs1i3/projects/u35v/lberrisford/Isambard3-LFRic-Env-Science-Suites/env_lfric_gcc/working_dir/spack/var/spack/environments/lfric-apps-isambard
ROOT_SPEC=${ROOT_SPEC:-lfric-apps-isambard}

# Color helpers (disable with NO_COLOR=1)
if [ -z "${NO_COLOR:-}" ]; then
  # Spack-like palette (as seen in spack output)
  ESC=$'\033'
  C_TITLE="${ESC}[1m"      # bold
  C_LABEL="${ESC}[1m"      # bold
  C_VALUE="${ESC}[0m"      # default
  C_STATUS="${ESC}[32m"    # green
  C_NAME="${ESC}[36m"      # cyan
  C_VERSION="${ESC}[34m"   # blue
  C_COMPILER="${ESC}[32m"  # green
  C_ARCH="${ESC}[35m"      # magenta
  C_RESET="${ESC}[0m"
else
  C_TITLE='' C_LABEL='' C_VALUE='' C_STATUS='' C_NAME='' C_VERSION='' C_COMPILER='' C_ARCH='' C_RESET=''
fi

printf "%sPoster Stats (LFRic GCC env)%s\n" "$C_TITLE" "$C_RESET"
printf "Environment: %s\n" "$ENV"
printf "Root spec:   %s\n\n" "$ROOT_SPEC"

TOTAL_PKGS=$($SPACK -e "$ENV" find --format '{name}' | wc -l)
PY_PKGS=$($SPACK -e "$ENV" find --format '{name}' | grep -E '^py-' | wc -l)

printf "%sPackage counts%s\n" "$C_TITLE" "$C_RESET"
printf "  %sTotal packages:%s  %s%s%s\n" "$C_LABEL" "$C_RESET" "$C_VALUE" "$TOTAL_PKGS" "$C_RESET"
printf "  %sPython packages:%s %s%s%s\n\n" "$C_LABEL" "$C_RESET" "$C_VALUE" "$PY_PKGS" "$C_RESET"

# Spack-like trimmed tree (poster-friendly but shows versions/compilers).
printf "%sHigh-level dependency tree (poster, spack-style)%s\n" "$C_TITLE" "$C_RESET"

has_pkg() {
  $SPACK -e "$ENV" find --format '{name}' 2>/dev/null | grep -qE "^$1$"
}

spec_line() {
  local pkg="$1"
  $SPACK -e "$ENV" find --format '{name}@{version} %{compiler} arch={arch}' "$pkg" 2>/dev/null | head -n 1
}

colorize_spec() {
  local line="$1"
  if [ -n "${NO_COLOR:-}" ]; then
    printf "%s" "$line"
    return
  fi

  # Expected format: name@version %compiler arch=arch
  local name rest version compiler arch
  name="${line%%@*}"
  rest="${line#*@}"
  version="${rest%% *}"
  rest="${rest#* }"
  compiler="${rest%% *}"
  arch="${rest#* }"

  printf "%s%s%s@%s%s%s %s%s%s %s%s%s" \
    "$C_NAME" "$name" "$C_RESET" \
    "$C_VERSION" "$version" "$C_RESET" \
    "$C_COMPILER" "$compiler" "$C_RESET" \
    "$C_ARCH" "$arch" "$C_RESET"
}

ROOT_LINE=$(spec_line "$ROOT_SPEC")
if [ -z "$ROOT_LINE" ]; then
  echo "  (no spec output; check ROOT_SPEC or environment)"
  exit 0
fi

printf "%s[+]%s  [    ]  %s\n" "$C_STATUS" "$C_RESET" "$(colorize_spec "$ROOT_LINE")"

# Toolchain: prefer one MPI implementation if present.
MPI_PKG=""
if has_pkg mpich; then
  MPI_PKG="mpich"
elif has_pkg openmpi; then
  MPI_PKG="openmpi"
elif has_pkg cray-mpich; then
  MPI_PKG="cray-mpich"
fi

TOOLCHAIN_LINES=()
if [ -n "$MPI_PKG" ]; then
  TOOLCHAIN_LINES+=("$(spec_line "$MPI_PKG")")
fi

# Key IO and coupling libs.
IO_LINES=()
has_pkg hdf5 && IO_LINES+=("$(spec_line hdf5)")
has_pkg netcdf-c && IO_LINES+=("$(spec_line netcdf-c)")
has_pkg netcdf-fortran && IO_LINES+=("$(spec_line netcdf-fortran)")
has_pkg xios && IO_LINES+=("$(spec_line xios)")

# Workflow tooling.
WF_LINES=()
has_pkg metomi-rose && WF_LINES+=("$(spec_line metomi-rose)")
has_pkg cylc-flow && WF_LINES+=("$(spec_line cylc-flow)")
has_pkg cylc-rose && WF_LINES+=("$(spec_line cylc-rose)")
has_pkg cylc-uiserver && WF_LINES+=("$(spec_line cylc-uiserver)")

emit_dep() {
  local line="$1"
  [ -z "$line" ] && return 0
  printf "%s[+]%s  [bl  ]      ^%s\n" "$C_STATUS" "$C_RESET" "$(colorize_spec "$line")"
}

for line in "${TOOLCHAIN_LINES[@]}"; do emit_dep "$line"; done
for line in "${IO_LINES[@]}"; do emit_dep "$line"; done
for line in "${WF_LINES[@]}"; do emit_dep "$line"; done

echo
printf "\n%sLegend%s\n" "$C_TITLE" "$C_RESET"
printf "%s[+]%s  installed in the environment\n" "$C_STATUS" "$C_RESET"
printf "%s[bl ]%s  built from source (no binary)\n" "$C_LABEL" "$C_RESET"
printf "%s^%s     dependency of the root spec\n" "$C_LABEL" "$C_RESET"
printf "%s@%s     version\n" "$C_VERSION" "$C_RESET"
printf "%s%%%s     compiler used to build\n" "$C_COMPILER" "$C_RESET"
printf "%sarch=%s target architecture\n" "$C_ARCH" "$C_RESET"
