#!/usr/bin/env python3
"""Load RDF files into GraphDB via HTTP (curl).

Docs:
https://graphdb.ontotext.com/documentation/10.8/loading-and-updating-data.html#loading-via-http-with-curl

"""

from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

RDF_CONTENT_TYPE = "application/rdf+xml"
SCRIPT_DIR = Path(__file__).resolve().parent


def load_env_file(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip("'\"")
        os.environ.setdefault(key, value)


def collect_files(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_file():
            if path.suffix.lower() == ".rdf":
                files.append(path)
            else:
                print(f"Warning: skipping non-.rdf file: {path}", file=sys.stderr)
        elif path.is_dir():
            files.extend(sorted(path.rglob("*.rdf")))
        else:
            print(f"Warning: path not found, skipping: {path}", file=sys.stderr)
    return files


def statements_url(base_url: str, repo: str) -> str:
    return f"{base_url.rstrip('/')}/repositories/{repo}/statements"


def run_curl(args: list[str], dry_run: bool) -> tuple[int, str]:
    if dry_run:
        print("  " + " ".join(shlex.quote(a) for a in args))
        return 204, ""
    result = subprocess.run(args, capture_output=True, text=True)
    body = (result.stdout or "") + (result.stderr or "")
    http_code = 0
    if result.stdout:
        lines = result.stdout.strip().splitlines()
        if lines and lines[-1].isdigit():
            http_code = int(lines[-1])
            body = "\n".join(lines[:-1]).strip()
    if http_code == 0:
        http_code = 500 if result.returncode != 0 else 200
    return http_code, body


def load_file(path: Path, url: str, dry_run: bool) -> int:
    curl = [
        "curl",
        "-sS",
        "-o",
        "-",
        "-w",
        "\n%{http_code}",
        "-X",
        "POST",
        "-H",
        f"Content-Type: {RDF_CONTENT_TYPE}",
        "--data-binary",
        f"@{path}",
        url,
    ]
    code, body = run_curl(curl, dry_run)
    if not str(code).startswith("2"):
        print(f"  FAILED HTTP {code}: {body}", file=sys.stderr)
    return code


def main() -> None:
    load_env_file(SCRIPT_DIR / "graphdb.env")

    parser = argparse.ArgumentParser(
        description="Load RDF into GraphDB via HTTP using curl (RDF4J /statements)."
    )
    parser.add_argument(
        "paths",
        nargs="+",
        type=Path,
        help="RDF file(s) or directory(ies) to load",
    )
    parser.add_argument(
        "-b",
        "--base-url",
        default=os.environ.get("GRAPHDB_BASE_URL", "http://localhost:7200"),
        help="GraphDB base URL (default: $GRAPHDB_BASE_URL or http://localhost:7200)",
    )
    parser.add_argument(
        "-r",
        "--repo",
        default=os.environ.get("GRAPHDB_REPO"),
        help="Repository id (default: $GRAPHDB_REPO)",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Print curl commands without executing",
    )
    args = parser.parse_args()

    if not args.repo:
        parser.error("repository id is required (-r / --repo or GRAPHDB_REPO)")
    if shutil.which("curl") is None:
        raise SystemExit("curl is required on PATH")

    files = collect_files(args.paths)
    if not files:
        raise SystemExit("No RDF files found.")

    url = statements_url(args.base_url, args.repo)

    print(f"GraphDB: {args.base_url.rstrip('/')}")
    print(f"Repo:    {args.repo}")
    print(f"Files:   {len(files)}")
    print()

    ok = 0
    fail = 0
    for i, path in enumerate(files, start=1):
        print(f"[{i}/{len(files)}] POST {path.name}")
        code = load_file(path, url, args.dry_run)
        if str(code).startswith("2"):
            ok += 1
        else:
            fail += 1

    print()
    print(f"Done. succeeded={ok} failed={fail} total={len(files)}")
    if fail:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
