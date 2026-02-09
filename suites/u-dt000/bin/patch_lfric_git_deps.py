#!/usr/bin/env python3
"""Patch lfric_apps makefiles to use git-cloned deps instead of fcm."""
from __future__ import annotations

from pathlib import Path
import re
import sys


def write_extract_physics(path: Path) -> None:
    content = """##############################################################################
# (c) Crown copyright 2024 Met Office. All rights reserved.
# The file LICENCE, distributed with this code, contains details of the terms
# under which the code may be used.
##############################################################################
#
# Run this file to extract source code from the UM repository.
#
# The following environment variables are used for input:
#   UM_FCM_TARGET_PLATFORM : Target identifier used to get the
#                            correct UM build configs.
#   PROFILE : Build profile used to determine optimisation level.
#   PROJECT_DIR : Full path to the current project's root directory.
#   SCRATCH_DIR : Temporary space for extracted source.
#   WORKING_DIR : Directory to hold working copies of source.
#
###############################################################################

.PHONY: extract

extract:
\t# Retrieve and preprocess the UKCA and CASIM code (git-based)
\t$Qmkdir -p $(WORKING_DIR)/science/src
\t$Qpython $(ROSE_SUITE_DIR)/bin/extract_subset.py \\
\t\t--extract-cfg "$(APPS_ROOT_DIR)/build/extract/extract.cfg" \\
\t\t--namespace casim \\
\t\t--repo-root "$(LFRIC_DEPS_DIR)/casim" \\
\t\t--working-dir "$(WORKING_DIR)/science/src"
\t$Qpython $(ROSE_SUITE_DIR)/bin/extract_subset.py \\
\t\t--extract-cfg "$(APPS_ROOT_DIR)/build/extract/extract.cfg" \\
\t\t--namespace ukca \\
\t\t--repo-root "$(LFRIC_DEPS_DIR)/ukca" \\
\t\t--working-dir "$(WORKING_DIR)/science/src"
"""
    path.write_text(content)


def write_import_interface(path: Path, repo_name: str, allow_missing_prefixes: list[str] | None = None) -> None:
    interface = path.parent.parent.name
    allow_missing_prefixes = allow_missing_prefixes or []
    allow_args = ""
    if allow_missing_prefixes:
        lines = [f"\t\t--allow-missing-prefix \"{prefix}\"" for prefix in allow_missing_prefixes]
        allow_args = " \\\n" + " \\\n".join(lines)
    content = f"""##############################################################################
# (c) Crown copyright 2025 Met Office. All rights reserved.
# The file LICENCE, distributed with this code, contains details of the terms
# under which the code may be used.
##############################################################################
export PROJECT_SOURCE = $(APPS_ROOT_DIR)/interfaces/{interface}/source
export EXTRACT_CFG = $(APPS_ROOT_DIR)/interfaces/{interface}/build/extract.cfg
export REPO_ROOT = $(LFRIC_DEPS_DIR)/{repo_name}

.PHONY: import-{interface}
import-{interface}:
\t# Get a copy of the source code from the {repo_name} repository (git-based)
\t$Qmkdir -p $(WORKING_DIR)
\t$Qpython $(ROSE_SUITE_DIR)/bin/extract_subset.py \\
\t\t--extract-cfg "$(EXTRACT_CFG)" \\
\t\t--repo-root "$(REPO_ROOT)" \\
\t\t--working-dir "$(WORKING_DIR)"{allow_args}

\t# Extract the interface code
\t$Q$(MAKE) $(QUIET_ARG) -f $(LFRIC_BUILD)/extract.mk \\
\t\t\t  SOURCE_DIR=$(PROJECT_SOURCE)
"""
    path.write_text(content)


def patch_jules_nvegparm(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "science" / "params" / "nvegparm_mod.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping JULES nvegparm patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content.replace("HUGE(1.0)", "HUGE(1.0_real_jlslsm)")
    updated = updated.replace("0.0,", "0.0_real_jlslsm,")
    updated = updated.replace("1.0,", "1.0_real_jlslsm,")
    if updated != content:
        target.write_text(updated)


def patch_jules_veg3_field(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "control" / "shared" / "veg3_field_mod.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping JULES veg3_field patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content.replace(
        "REAL, ALLOCATABLE ::",
        "REAL(KIND=real_jlslsm), ALLOCATABLE ::",
    )
    updated = updated.replace(
        "REAL, POINTER ::",
        "REAL(KIND=real_jlslsm), POINTER ::",
    )
    if updated != content:
        target.write_text(updated)


def patch_jules_gridbox_mean(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "util" / "shared" / "gridbox_mean_mod.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping JULES gridbox_mean patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content
    updated = re.sub(
        r"^\s*USE um_types, ONLY: real_jlslsm\s*$\n?",
        "",
        updated,
        flags=re.M,
    )
    updated = re.sub(
        r"^MODULE gridbox_mean_mod\s*$",
        "MODULE gridbox_mean_mod\n\nUSE um_types, ONLY: real_jlslsm",
        updated,
        count=1,
        flags=re.M,
    )
    updated = re.sub(r"\bREAL\s*,", "REAL(KIND=real_jlslsm),", updated)
    updated = re.sub(r"\bREAL\s*::", "REAL(KIND=real_jlslsm) ::", updated)
    if updated != content:
        target.write_text(updated)


def patch_jules_deposition_surfddr(deps_dir: Path) -> None:
    target = (
        deps_dir
        / "jules"
        / "src"
        / "science"
        / "deposition"
        / "deposition_initialisation_surfddr_mod.F90"
    )
    if not target.exists():
        print(f"WARN: {target} not found; skipping JULES deposition patch", file=sys.stderr)
        return
    content = target.read_text()

    def repl(match: re.Match[str]) -> str:
        value = match.group(1)
        return f"{value}_real_jlslsm"

    updated = re.sub(
        r"(?<![\w.])([0-9]*\.[0-9]+(?:[Ee][+-]?[0-9]+)?)(?![0-9A-Za-z_])",
        repl,
        content,
    )
    if updated != content:
        target.write_text(updated)


def patch_jules_ukca_ddepo3_ocean(deps_dir: Path) -> None:
    target = (
        deps_dir
        / "jules"
        / "src"
        / "science"
        / "deposition"
        / "deposition_ukca_ddepo3_ocean_mod.F90"
    )
    if not target.exists():
        print(f"WARN: {target} not found; skipping UKCA ddepo3 ocean patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content
    if "USE um_types, ONLY: real_jlslsm" not in updated:
        updated = re.sub(
            r"^MODULE deposition_ukca_ddepo3_ocean_mod\s*$",
            "MODULE deposition_ukca_ddepo3_ocean_mod\n\nUSE um_types, ONLY: real_jlslsm",
            updated,
            count=1,
            flags=re.M,
        )
    updated = updated.replace(
        "REAL FUNCTION b_k0(x)",
        "REAL(KIND=real_jlslsm) FUNCTION b_k0(x)",
    )
    updated = updated.replace(
        "REAL FUNCTION b_k1(x)",
        "REAL(KIND=real_jlslsm) FUNCTION b_k1(x)",
    )
    updated = updated.replace(
        "REAL, INTENT(IN) :: x",
        "REAL(KIND=real_jlslsm), INTENT(IN) :: x",
    )
    updated = updated.replace(
        "REAL :: y",
        "REAL(KIND=real_jlslsm) :: y",
    )
    updated = updated.replace(
        "REAL, PARAMETER ::",
        "REAL(KIND=real_jlslsm), PARAMETER ::",
    )
    if updated != content:
        target.write_text(updated)


def patch_jules_ukca_h2dd_soil(deps_dir: Path) -> None:
    target = (
        deps_dir
        / "jules"
        / "src"
        / "science"
        / "deposition"
        / "deposition_ukca_h2dd_soil.F90"
    )
    if not target.exists():
        print(f"WARN: {target} not found; skipping UKCA h2dd soil patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = re.sub(r"\bREAL\s*,", "REAL(KIND=real_jlslsm),", content)
    updated = re.sub(r"\bREAL\s*::", "REAL(KIND=real_jlslsm) ::", updated)
    if updated != content:
        target.write_text(updated)


def patch_jules_can_drag(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "science" / "surface" / "can_drag_mod.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping can_drag patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content.replace(
        "calc_psi_m_h_rsl(0.0, 0.0,",
        "calc_psi_m_h_rsl(0.0_real_jlslsm, 0.0_real_jlslsm,",
    )
    updated = updated.replace("z_uv0 = 0.0", "z_uv0 = 0.0_real_jlslsm")
    updated = updated.replace("z_tq0 = 0.0", "z_tq0 = 0.0_real_jlslsm")
    if updated != content:
        target.write_text(updated)


def patch_jules_fcdch(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "science" / "surface" / "fcdch.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping fcdch patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content.replace("1.0,anthrop_heat", "1.0_real_jlslsm,anthrop_heat")
    if updated != content:
        target.write_text(updated)


def patch_jules_sf_stom(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "science" / "surface" / "sf_stom_jls_mod.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping sf_stom patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = content.replace(
        "act_j_tmp(:) = [act_jmax(ft), 0.0, 0.0]",
        "act_j_tmp(:) = [act_jmax(ft), 0.0_real_jlslsm, 0.0_real_jlslsm]",
    )
    updated = updated.replace(
        "act_v_tmp(:) = [act_vcmax(ft), 0.0, 0.0]",
        "act_v_tmp(:) = [act_vcmax(ft), 0.0_real_jlslsm, 0.0_real_jlslsm]",
    )
    if updated != content:
        target.write_text(updated)


def patch_jules_albpft(deps_dir: Path) -> None:
    target = deps_dir / "jules" / "src" / "science" / "radiation" / "albpft_jls_mod.F90"
    if not target.exists():
        print(f"WARN: {target} not found; skipping albpft patch", file=sys.stderr)
        return
    content = target.read_text()
    updated = re.sub(
        r"SIGN\(\s*1\.0e-4\s*,",
        "SIGN( 1.0e-4_real_jlslsm,",
        content,
    )
    if updated != content:
        target.write_text(updated)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: patch_lfric_git_deps.py <lfric_apps_root>", file=sys.stderr)
        return 2

    apps_root = Path(sys.argv[1]).resolve()
    extract_physics = apps_root / "build" / "extract" / "extract_physics.mk"
    socrates_import = apps_root / "interfaces" / "socrates_interface" / "build" / "import.mk"
    jules_import = apps_root / "interfaces" / "jules_interface" / "build" / "import.mk"

    missing = [p for p in [extract_physics, socrates_import, jules_import] if not p.exists()]
    if missing:
        print("Missing expected files:\n  " + "\n  ".join(str(p) for p in missing), file=sys.stderr)
        return 1

    write_extract_physics(extract_physics)
    write_import_interface(socrates_import, "socrates")
    write_import_interface(
        jules_import,
        "jules",
        allow_missing_prefixes=[
            "src/control/cable/",
            "src/params/cable/",
            "src/science_cable/",
            "src/util/cable/",
        ],
    )
    deps_dir = apps_root.parent / "deps"
    patch_jules_nvegparm(deps_dir)
    patch_jules_veg3_field(deps_dir)
    patch_jules_gridbox_mean(deps_dir)
    patch_jules_deposition_surfddr(deps_dir)
    patch_jules_ukca_ddepo3_ocean(deps_dir)
    patch_jules_ukca_h2dd_soil(deps_dir)
    patch_jules_can_drag(deps_dir)
    patch_jules_fcdch(deps_dir)
    patch_jules_sf_stom(deps_dir)
    patch_jules_albpft(deps_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
