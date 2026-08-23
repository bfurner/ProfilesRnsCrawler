#!/usr/bin/env python3
"""Load RDF files into GraphDB via HTTP (curl).

Docs:
https://graphdb.ontotext.com/documentation/10.8/loading-and-updating-data.html#loading-via-http-with-curl
https://graphdb.ontotext.com/documentation/11.3/enabling-security.html
https://graphdb.ontotext.com/documentation/11.4/access-control.html#basic-authentication

When GraphDB security is enabled, pass credentials via --username/--password

S3 mode lists objects under a prefix and streams one RDF object at a time
into GraphDB (no full-prefix download).
"""

from __future__ import annotations

import argparse
import getpass
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import BinaryIO

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


def s3_client(region: str):
    try:
        import boto3
    except ImportError as exc:
        raise SystemExit("boto3 is required for S3 mode (pip install boto3)") from exc
    return boto3.client("s3", region_name=region)


def list_rdf_objects(s3, bucket: str, prefix: str) -> list[str]:
    keys: list[str] = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for obj in page.get("Contents") or []:
            key = obj["Key"]
            if key.endswith("/") or not key.lower().endswith(".rdf"):
                continue
            keys.append(key)
    return keys


def statements_url(base_url: str, repo: str) -> str:
    return f"{base_url.rstrip('/')}/repositories/{repo}/statements"


def resolve_credentials(
    username: str | None, password: str | None
) -> tuple[str | None, str | None]:
    """Return (username, password) for Basic auth, or (None, None) if unused."""
    if not username:
        if password:
            raise SystemExit(
                "GRAPHDB_PASSWORD / --password set without a username "
                "(use --username or GRAPHDB_USERNAME)"
            )
        return None, None
    if password is None:
        password = getpass.getpass(f"Password for GraphDB user {username!r}: ")
    return username, password


def redact_curl_args(args: list[str]) -> list[str]:
    """Mask password in --user user:pass for dry-run output."""
    redacted: list[str] = []
    hide_next = False
    for arg in args:
        if hide_next:
            if ":" in arg:
                user, _, _ = arg.partition(":")
                redacted.append(f"{user}:***")
            else:
                redacted.append("***")  # mask the entire next argument, just in case
            hide_next = False
            continue
        if arg in ("-u", "--user"):
            redacted.append(arg)
            hide_next = True
            continue
        redacted.append(arg)
    return redacted


def graphdb_curl_args(
    url: str,
    data_arg: str,
    username: str | None = None,
    password: str | None = None,
) -> list[str]:
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
        data_arg,
    ]
    if username is not None and password is not None:
        # GraphDB Basic auth (enabled by default when security is on).
        curl.extend(["--user", f"{username}:{password}"])
    curl.append(url)
    return curl


def parse_curl_output(stdout: str, stderr: str, returncode: int) -> tuple[int, str]:
    body = (stdout or "") + (stderr or "")
    http_code = 0
    if stdout:
        lines = stdout.strip().splitlines()
        if lines and lines[-1].isdigit():
            http_code = int(lines[-1])
            body = "\n".join(lines[:-1]).strip()
    if http_code == 0:
        http_code = 500 if returncode != 0 else 200
    return http_code, body


def run_curl(args: list[str], dry_run: bool) -> tuple[int, str]:
    if dry_run:
        print("  " + " ".join(shlex.quote(a) for a in redact_curl_args(args)))
        return 204, ""
    result = subprocess.run(args, capture_output=True, text=True)
    return parse_curl_output(result.stdout, result.stderr, result.returncode)


def load_file(
    path: Path,
    url: str,
    dry_run: bool,
    username: str | None = None,
    password: str | None = None,
) -> int:
    curl = graphdb_curl_args(url, f"@{path}", username, password)
    code, body = run_curl(curl, dry_run)
    if not str(code).startswith("2"):
        print(f"  FAILED HTTP {code}: {body}", file=sys.stderr)
    return code


def load_stream(
    body: BinaryIO | None,
    url: str,
    dry_run: bool,
    username: str | None = None,
    password: str | None = None,
) -> int:
    curl = graphdb_curl_args(url, "@-", username, password)
    if dry_run:
        print("  " + " ".join(shlex.quote(a) for a in redact_curl_args(curl)))
        return 204
    if body is None:
        raise SystemExit("internal error: missing RDF stream")
    proc = subprocess.Popen(
        curl,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert proc.stdin is not None
    try:
        shutil.copyfileobj(body, proc.stdin)
    finally:
        proc.stdin.close()
    stdout_b, stderr_b = proc.communicate()
    code, response_body = parse_curl_output(
        stdout_b.decode("utf-8", errors="replace"),
        stderr_b.decode("utf-8", errors="replace"),
        proc.returncode,
    )
    if not str(code).startswith("2"):
        print(f"  FAILED HTTP {code}: {response_body}", file=sys.stderr)
    return code


def main() -> None:
    load_env_file(SCRIPT_DIR / "graphdb.env")

    parser = argparse.ArgumentParser(
        description="Load RDF into GraphDB via HTTP using curl."
    )
    parser.add_argument(
        "paths",
        nargs="*",
        type=Path,
        help="RDF file(s) or directory(ies) to load (local mode)",
    )
    parser.add_argument(
        "--s3-bucket",
        default=os.environ.get("RDF_S3_BUCKET"),
        help="S3 bucket to stream RDF from (default: $RDF_S3_BUCKET)",
    )
    parser.add_argument(
        "--s3-prefix",
        default=os.environ.get("RDF_S3_PREFIX", "rdf/"),
        help="S3 key prefix to list (default: $RDF_S3_PREFIX or rdf/)",
    )
    parser.add_argument(
        "--aws-region",
        default=os.environ.get("AWS_REGION", "us-east-2"),
        help="AWS region for S3 (default: $AWS_REGION or us-east-2)",
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
        "-u",
        "--username",
        default=os.environ.get("GRAPHDB_USERNAME"),
        help="GraphDB username when security is enabled (default: $GRAPHDB_USERNAME)",
    )
    parser.add_argument(
        "-p",
        "--password",
        default=os.environ.get("GRAPHDB_PASSWORD"),
        help="GraphDB password (default: $GRAPHDB_PASSWORD; prompted if username set)",
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
    if not args.s3_bucket and not args.paths:
        parser.error("provide local RDF paths or --s3-bucket / RDF_S3_BUCKET")

    username, password = resolve_credentials(args.username, args.password)
    url = statements_url(args.base_url, args.repo)

    print(f"GraphDB: {args.base_url.rstrip('/')}")
    print(f"Repo:    {args.repo}")
    print(f"Auth:    {username if username else '(none)'}")

    ok = 0
    fail = 0

    if args.s3_bucket:
        s3 = s3_client(args.aws_region)
        keys = list_rdf_objects(s3, args.s3_bucket, args.s3_prefix)
        if not keys:
            raise SystemExit(
                f"No RDF objects found in s3://{args.s3_bucket}/{args.s3_prefix}"
            )
        print(f"S3:      s3://{args.s3_bucket}/{args.s3_prefix} ({len(keys)} objects)")
        print()
        for i, key in enumerate(keys, start=1):
            print(f"[{i}/{len(keys)}] POST {key}")
            if args.dry_run:
                code = load_stream(None, url, True, username, password)
            else:
                response = s3.get_object(Bucket=args.s3_bucket, Key=key)
                code = load_stream(response["Body"], url, False, username, password)
            if str(code).startswith("2"):
                ok += 1
            else:
                fail += 1
        total = len(keys)
    else:
        files = collect_files(args.paths)
        if not files:
            raise SystemExit("No RDF files found.")
        print(f"Files:   {len(files)}")
        print()
        for i, path in enumerate(files, start=1):
            print(f"[{i}/{len(files)}] POST {path.name}")
            code = load_file(path, url, args.dry_run, username, password)
            if str(code).startswith("2"):
                ok += 1
            else:
                fail += 1
        total = len(files)

    print()
    print(f"Done. succeeded={ok} failed={fail} total={total}")
    if fail:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
