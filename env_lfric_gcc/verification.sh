#!/usr/bin/env bash

# Spack + rose/cylc verification helper for the Isambard environment.
# - Sources the local Spack install
# - Activates lfric-apps-isambard
# - Prints relevant specs and loads rose/cylc
# - Prints paths and versions for quick debugging

ENV_NAME="${ENV_NAME:-lfric-apps-isambard}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SPACK_DIR="$SCRIPT_DIR/working_dir/spack"
SPACK_DIR="${SPACK_DIR:-$DEFAULT_SPACK_DIR}"
SPACK_SETUP="$SPACK_DIR/share/spack/setup-env.sh"

info() {
  echo "INFO: $*"
}

warn() {
  echo "WARN: $*" >&2
}

info "Starting rose/cylc Spack environment check."
info "ENV_NAME=$ENV_NAME"
info "SPACK_DIR=$SPACK_DIR"
info "Hostname: $(hostname -f 2>/dev/null || hostname)"
info "Date: $(date)"

if [ -f "$SPACK_SETUP" ]; then
  . "$SPACK_SETUP"
  if command -v spack >/dev/null 2>&1; then
    info "Using Spack at $(command -v spack)"
    info "Spack version: $(spack --version 2>/dev/null || echo "unknown")"
    if spack env activate -p "$ENV_NAME" >/dev/null 2>&1; then
      info "Activated Spack environment: $ENV_NAME"
      spack env list || warn "Unable to list Spack environments"
      info "Spack spec for rose/cylc:"
      spack -e "$ENV_NAME" spec metomi-rose cylc-flow cylc-rose cylc-uiserver || \
        warn "Unable to print spec for metomi-rose/cylc-flow/cylc-rose/cylc-uiserver"
      info "Spack find for rose/cylc:"
      spack -e "$ENV_NAME" find metomi-rose cylc-flow cylc-rose cylc-uiserver || \
        warn "Required specs not found in $ENV_NAME"
      spack load metomi-rose cylc-flow cylc-rose cylc-uiserver >/dev/null 2>&1 || \
        warn "Unable to load rose/cylc from Spack environment $ENV_NAME"
      VIEW_DIR="$SPACK_DIR/var/spack/environments/$ENV_NAME/.spack-env/view"
      if [ -d "$VIEW_DIR/bin" ]; then
        export PATH="$VIEW_DIR/bin:$PATH"
        info "Prepended view bin to PATH: $VIEW_DIR/bin"
      else
        warn "Spack view bin not found at $VIEW_DIR/bin"
      fi
    else
      warn "Unable to activate Spack environment $ENV_NAME"
    fi
  else
    warn "Spack setup script found but spack command unavailable"
  fi
else
  warn "Spack setup not found at $SPACK_SETUP"
fi

command -v rose >/dev/null 2>&1 && info "rose path: $(command -v rose)" || warn "rose not found on PATH"
command -v cylc >/dev/null 2>&1 && info "cylc path: $(command -v cylc)" || warn "cylc not found on PATH"
command -v rose >/dev/null 2>&1 && rose --version || warn "rose --version failed"
command -v cylc >/dev/null 2>&1 && cylc --version || warn "cylc --version failed"

if [ "${EXTENDED_TOOL_VALIDATION:-1}" = "1" ]; then
  info "Extended rose/cylc validation on this machine."
  info "PATH=${PATH}"
  info "SPACK_ENV=${SPACK_ENV:-unset}"
  info "SPACK_ROOT=${SPACK_ROOT:-unset}"
  cat <<'EOF'
INFO: Suggested manual checks:
  rose --version
  cylc --version
  cylc validate --help
  rose app-run --help
  spack -e lfric-apps-isambard find metomi-rose cylc-flow cylc-rose cylc-uiserver
  spack -e lfric-apps-isambard spec metomi-rose cylc-flow cylc-rose cylc-uiserver
EOF
fi
