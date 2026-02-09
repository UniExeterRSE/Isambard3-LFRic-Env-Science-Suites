#!/usr/bin/env python3
"""Copy a subset of source files based on a Rose extract.cfg list."""
from __future__ import annotations

from pathlib import Path
import argparse
import re
import shutil
import sys


PATH_INCL_RE = re.compile(r"^extract\.path-incl(?:\[(?P<ns>[^\]]+)\])?")


def parse_extract_cfg(cfg: Path) -> dict[str | None, list[str]]:
    paths: dict[str | None, list[str]] = {}
    in_list = False
    current_ns: str | None = None
    buf: list[str] = []

    def flush() -> None:
        nonlocal buf
        if in_list and buf:
            paths.setdefault(current_ns, []).extend(buf)
        buf = []

    for raw in cfg.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        match = PATH_INCL_RE.match(stripped)
        if match:
            if in_list:
                flush()
            in_list = True
            current_ns = match.group("ns")
            if "=" in stripped:
                after = stripped.split("=", 1)[1].strip()
                if after.endswith("\\"):
                    after = after[:-1].strip()
                if after and after != "\\":
                    buf.append(after)
            continue
        if in_list:
            if stripped.startswith("extract.") and not stripped.startswith("extract.path-incl"):
                flush()
                in_list = False
                current_ns = None
                continue
            if stripped.endswith("\\"):
                stripped = stripped[:-1].strip()
            if stripped:
                buf.append(stripped)
    if in_list:
        flush()
    return paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--extract-cfg", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--working-dir", required=True)
    parser.add_argument(
        "--namespace",
        default=None,
        help="Optional extract.path-incl namespace, e.g. casim or ukca.",
    )
    parser.add_argument(
        "--allow-missing-prefix",
        action="append",
        default=[],
        help="Allow missing paths that start with this prefix (can repeat).",
    )
    args = parser.parse_args()

    cfg = Path(args.extract_cfg)
    repo = Path(args.repo_root)
    work = Path(args.working_dir)

    if not cfg.is_file():
        print(f"ERROR: extract cfg not found: {cfg}", file=sys.stderr)
        return 2
    if not repo.is_dir():
        print(f"ERROR: repo root not found: {repo}", file=sys.stderr)
        return 2

    paths_by_ns = parse_extract_cfg(cfg)
    if not paths_by_ns:
        print(f"ERROR: no extract.path-incl entries found in {cfg}", file=sys.stderr)
        return 2
    if args.namespace is not None:
        if args.namespace not in paths_by_ns:
            keys = ", ".join(sorted(k or "<default>" for k in paths_by_ns))
            print(
                f"ERROR: namespace {args.namespace} not found in {cfg} (have: {keys})",
                file=sys.stderr,
            )
            return 2
        paths = paths_by_ns[args.namespace]
    else:
        if len(paths_by_ns) == 1:
            paths = next(iter(paths_by_ns.values()))
        else:
            keys = ", ".join(sorted(k or "<default>" for k in paths_by_ns))
            print(
                f"ERROR: multiple extract.path-incl sections in {cfg}; "
                f"specify --namespace (have: {keys})",
                file=sys.stderr,
            )
            return 2
    if not paths:
        print(f"ERROR: no extract.path-incl entries selected from {cfg}", file=sys.stderr)
        return 2

    missing: list[str] = []
    ignored: list[str] = []
    for rel in paths:
        src = repo / rel
        dest = work / rel
        if not src.exists():
            if any(rel.startswith(prefix) for prefix in args.allow_missing_prefix):
                ignored.append(rel)
            else:
                missing.append(rel)
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        if src.is_dir():
            shutil.copytree(src, dest, dirs_exist_ok=True)
        else:
            shutil.copy2(src, dest)

    if ignored:
        print("WARN: ignored missing paths in repo:", file=sys.stderr)
        for rel in ignored:
            print(f"  {rel}", file=sys.stderr)
    if missing:
        print("ERROR: missing paths in repo:", file=sys.stderr)
        for rel in missing:
            print(f"  {rel}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
