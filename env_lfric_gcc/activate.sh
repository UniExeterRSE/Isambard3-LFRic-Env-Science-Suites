#!/usr/bin/env bash

ENV_NAME="${ENV_NAME:-lfric-apps-isambard}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SPACK_DIR="${SPACK_DIR:-$SCRIPT_DIR/working_dir/spack}"

. "$SPACK_DIR/share/spack/setup-env.sh"
spack env activate -p "$ENV_NAME"

# Match the install.sh runtime environment as closely as possible.
REQUIRED_SPECS=(
  metomi-rose
  cylc-flow
  cylc-rose
  cylc-uiserver
  rose-picker
  py-psyclone
  py-fparser
  py-ansimarkup
  py-aiofiles
  py-colorama
  py-graphene
  py-graphql-core
  py-graphql-relay
  py-protobuf
  py-psutil
  py-ldap3
  py-requests
  py-sqlalchemy
)

spack load "${REQUIRED_SPECS[@]}" >/dev/null 2>&1 || spack load metomi-rose cylc-flow cylc-rose cylc-uiserver
export PATH="$SPACK_DIR/var/spack/environments/$ENV_NAME/.spack-env/view/bin:$PATH"

# Shumlib runtime paths (needed for lfric_atm runtime linking).
if shumlib_prefix=$(spack -e "$ENV_NAME" location -i shumlib 2>/dev/null); then
  export SHUMLIB_ROOT="${SHUMLIB_ROOT:-$shumlib_prefix}"
  if [ -d "$SHUMLIB_ROOT/lib" ]; then
    export LDFLAGS="${LDFLAGS:+$LDFLAGS }-L$SHUMLIB_ROOT/lib -Wl,-rpath=$SHUMLIB_ROOT/lib"
    export LIBRARY_PATH="$SHUMLIB_ROOT/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
    export LD_LIBRARY_PATH="$SHUMLIB_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
fi

# Align compiler wrappers with the Spack environment (as install.sh does).
mpich_prefix="$(spack -e "$ENV_NAME" location -i mpich 2>/dev/null || true)"
if [ -n "$mpich_prefix" ] && [ -x "$mpich_prefix/bin/mpif90" ]; then
  mpi_fc="$mpich_prefix/bin/mpif90"
  export PATH="$mpich_prefix/bin:$PATH"
else
  mpi_fc="$(command -v mpif90 || true)"
fi
if [ "${KEEP_FC:-0}" != "1" ] && [ -n "$mpi_fc" ]; then
  export FC="$mpi_fc"
  export LDMPI="$mpi_fc"
  export MPIFC="$mpi_fc"
  export MPIF90="$mpi_fc"
  export F90="$mpi_fc"
  export F77="$mpi_fc"
fi

# Python/PSyclone paths (used by local_build.py and tooling).
if python_prefix=$(spack -e "$ENV_NAME" location -i python 2>/dev/null); then
  export PATH="$python_prefix/bin:$PATH"
  if [ -x "$python_prefix/bin/python3" ] && ! command -v python >/dev/null 2>&1; then
    TMP_PYTHON_DIR="$(mktemp -d)"
    ln -s "$python_prefix/bin/python3" "$TMP_PYTHON_DIR/python"
    export PATH="$TMP_PYTHON_DIR:$PATH"
  fi
fi
if psyclone_prefix=$(spack -e "$ENV_NAME" location -i py-psyclone 2>/dev/null); then
  export PATH="$psyclone_prefix/bin:$PATH"
fi

if [ -n "${ROSE_PICKER:-}" ] && [ -x "$ROSE_PICKER" ]; then
  export PATH="$(dirname "$ROSE_PICKER"):$PATH"
elif rose_picker_prefix=$(spack -e "$ENV_NAME" location -i rose-picker 2>/dev/null); then
  spack load rose-picker >/dev/null 2>&1
  export PATH="$rose_picker_prefix/bin:$PATH"
fi

# Default build/run variables used by install.sh.
WORKING_DIR="${WORKING_DIR:-$SCRIPT_DIR/working_dir}"
export APPS_ROOT_DIR="${APPS_ROOT_DIR:-$WORKING_DIR/lfric_apps}"
export CORE_ROOT_DIR="${CORE_ROOT_DIR:-$WORKING_DIR/lfric_core}"
export LFRIC_TARGET_PLATFORM="${LFRIC_TARGET_PLATFORM:-meto-spice}"
export FPP="${FPP:-cpp -traditional-cpp}"

# Configure the default Cylc run location under the project directory.
# $PROJECTDIR is set by the system to the user's project space; fall back to
# $SCRATCH or $HOME for users outside a project allocation.
CYLC_RUN_BASE_ROOT="${CYLC_RUN_BASE_ROOT:-${PROJECTDIR:-${SCRATCH:-$HOME}}}"
CYLC_RUN_BASE_DEFAULT="${CYLC_RUN_BASE_DEFAULT:-$CYLC_RUN_BASE_ROOT/${USER}/cylc-run}"
export CYLC_RUN_BASE="${CYLC_RUN_BASE:-$CYLC_RUN_BASE_DEFAULT}"
CYLC_USER_CONF="${CYLC_USER_CONF:-$HOME/.cylc/flow/global.cylc}"
CYLC_USER_CONF_DIR="$(dirname "$CYLC_USER_CONF")"
CYLC_RUN_BLOCK_START="# BEGIN LFRIC_CYLC_RUN_DIR"
CYLC_RUN_BLOCK_END="# END LFRIC_CYLC_RUN_DIR"
CYLC_PLATFORM_BLOCK_START="# BEGIN LFRIC_ISAMBARD3_PLATFORM"
CYLC_PLATFORM_BLOCK_END="# END LFRIC_ISAMBARD3_PLATFORM"

mkdir -p "$CYLC_USER_CONF_DIR" "$CYLC_RUN_BASE"
if [ ! -f "$CYLC_USER_CONF" ]; then
  : > "$CYLC_USER_CONF"
fi

if grep -q "$CYLC_RUN_BLOCK_START" "$CYLC_USER_CONF" 2>/dev/null; then
  awk -v start="$CYLC_RUN_BLOCK_START" -v end="$CYLC_RUN_BLOCK_END" -v run="$CYLC_RUN_BASE" '
    $0 == start {
      inblock=1
      print
      print "[install]"
      print "    [[symlink dirs]]"
      print "        [[[localhost]]]"
      print "            run = " run
      next
    }
    $0 == end { inblock=0; print; next }
    !inblock { print }
  ' "$CYLC_USER_CONF" > "$CYLC_USER_CONF.tmp" && mv "$CYLC_USER_CONF.tmp" "$CYLC_USER_CONF"
else
  cat >> "$CYLC_USER_CONF" <<EOF

$CYLC_RUN_BLOCK_START
[install]
    [[symlink dirs]]
        [[[localhost]]]
            run = $CYLC_RUN_BASE
$CYLC_RUN_BLOCK_END
EOF
fi

# Install a default isambard3 platform definition in platforms.d (user scope).
CYLC_PLATFORMS_DIR="$CYLC_USER_CONF_DIR/platforms.d"
CYLC_ISAMBARD3_PLATFORM_FILE="$CYLC_PLATFORMS_DIR/isambard3.cylc"
mkdir -p "$CYLC_PLATFORMS_DIR"
if [ ! -f "$CYLC_ISAMBARD3_PLATFORM_FILE" ]; then
  cat > "$CYLC_ISAMBARD3_PLATFORM_FILE" <<EOF
$CYLC_PLATFORM_BLOCK_START
[platforms]
    [[isambard3]]
        hosts = localhost
        job runner = slurm
        install target = localhost
$CYLC_PLATFORM_BLOCK_END
EOF
elif grep -q "$CYLC_PLATFORM_BLOCK_START" "$CYLC_ISAMBARD3_PLATFORM_FILE" 2>/dev/null; then
  awk -v start="$CYLC_PLATFORM_BLOCK_START" -v end="$CYLC_PLATFORM_BLOCK_END" '
    $0 == start {
      inblock=1
      print
      print "[platforms]"
      print "    [[isambard3]]"
      print "        hosts = localhost"
      print "        job runner = slurm"
      print "        install target = localhost"
      next
    }
    $0 == end { inblock=0; print; next }
    !inblock { print }
  ' "$CYLC_ISAMBARD3_PLATFORM_FILE" > "$CYLC_ISAMBARD3_PLATFORM_FILE.tmp" \
    && mv "$CYLC_ISAMBARD3_PLATFORM_FILE.tmp" "$CYLC_ISAMBARD3_PLATFORM_FILE"
fi

hash -r
