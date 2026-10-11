#!/usr/bin/env python3
"""Private nix-unit → JUnit XML reporter.

Not a public stdlib API. Consumers run the `nix-unit:test` devenv task; do not
invoke this script from project config. When nix-unit gains native JUnit
support, swap the task implementation and delete this file.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANSI_RE = re.compile(r"\x1b\[[0-9;]*[mK]")
# nix-unit prints ✅ / ❌ / ☢️ (the last is U+2622 plus an optional VS16).
STATUS_RE = re.compile(r"^([✅❌☢]\ufe0f?)\s+(.+)$")
SUMMARY_RE = re.compile(r"^[🎉😢]")
SKIP_UNIT = {"default.nix", "harness.nix"}


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text).replace("\ufe0f", "")


def repo_relative(path: Path, root: Path) -> str:
    resolved = path if path.is_absolute() else (root / path)
    try:
        return str(resolved.resolve().relative_to(root.resolve())).replace("\\", "/")
    except ValueError:
        return str(path).replace("\\", "/")


def classname_for(file_path: str | None, fallback: str) -> str:
    if not file_path:
        return fallback
    return file_path.replace("/", ".").removesuffix(".nix")


def locate_nix_unit(
    name: str, unit_dir: Path, root: Path
) -> tuple[str | None, int | None]:
    # Main suite nests topics under stdlib/ and aspects/; owner suites are flat.
    paths = sorted(
        path
        for path in unit_dir.rglob("*.nix")
        if path.is_file() and path.name not in SKIP_UNIT
    )
    for path in paths:
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.lstrip()
            if stripped.startswith((f"{name} =", f"{name}=")):
                return repo_relative(path, root), lineno
    return None, None


def parse_nix_unit(text: str, unit_dir: Path, root: Path) -> list[dict]:
    cases: list[dict] = []
    current: dict | None = None
    details: list[str] = []

    def flush() -> None:
        nonlocal current, details
        if current is None:
            return
        current["details"] = "\n".join(details).strip()
        if current["status"] != "passed" and not current.get("message"):
            current["message"] = details[0] if details else f"{current['name']} failed"
        cases.append(current)
        current = None
        details = []

    for raw in strip_ansi(text).splitlines():
        line = raw.rstrip()
        if SUMMARY_RE.match(line) or line.startswith("error: Tests failed"):
            flush()
            continue
        match = STATUS_RE.match(line)
        if match:
            flush()
            mark, name = match.group(1), match.group(2).strip()
            file_path, lineno = locate_nix_unit(name, unit_dir, root)
            status = {"✅": "passed", "❌": "failed", "☢": "error"}[mark]
            current = {
                "name": name,
                "file": file_path,
                "line": lineno,
                "classname": classname_for(file_path, "tests.unit"),
                "status": status,
                "message": "" if status == "passed" else f"{name} failed",
            }
            continue
        if current is not None:
            details.append(line)
    flush()
    return cases


def write_junit(path: Path, suite_name: str, cases: list[dict]) -> None:
    tests = len(cases)
    failures = sum(1 for case in cases if case["status"] == "failed")
    errors = sum(1 for case in cases if case["status"] == "error")
    skipped = sum(1 for case in cases if case["status"] == "skipped")
    suites = ET.Element(
        "testsuites",
        {"tests": str(tests), "failures": str(failures), "errors": str(errors)},
    )
    suite = ET.SubElement(
        suites,
        "testsuite",
        {
            "name": suite_name,
            "tests": str(tests),
            "failures": str(failures),
            "errors": str(errors),
            "skipped": str(skipped),
        },
    )

    for case in cases:
        attrs = {
            "name": case["name"],
            "classname": case.get("classname") or suite_name,
        }
        if case.get("file"):
            attrs["file"] = case["file"]
        if case.get("line") is not None:
            attrs["line"] = str(case["line"])
        testcase = ET.SubElement(suite, "testcase", attrs)
        status = case["status"]
        if status in {"failed", "error"}:
            tag = "failure" if status == "failed" else "error"
            node = ET.SubElement(
                testcase, tag, {"message": (case.get("message") or status)[:1000]}
            )
            node.text = case.get("details") or case.get("message") or ""
        elif status == "skipped":
            ET.SubElement(testcase, "skipped")

    path.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(suites, space="  ")
    ET.ElementTree(suites).write(path, encoding="utf-8", xml_declaration=True)


def emit_github_annotations(cases: list[dict]) -> None:
    if os.environ.get("GITHUB_ACTIONS", "") != "true":
        return
    for case in cases:
        if case["status"] not in {"failed", "error"}:
            continue
        loc = []
        if case.get("file"):
            loc.append(f"file={case['file']}")
        if case.get("line") is not None:
            loc.append(f"line={case['line']}")
        loc.append(f"title={case['name']}")
        body = case.get("details") or case.get("message") or case["name"]
        body = body.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        prefix = f"::{case['status'] if case['status'] == 'error' else 'error'}"
        print(f"{prefix} {','.join(loc)}::{body[:4000]}")


def failed(cases: list[dict]) -> bool:
    return any(case["status"] in {"failed", "error"} for case in cases)


def run_nix_unit(cmd: list[str], *, quiet: bool = False) -> tuple[int, str]:
    """Run nix-unit, keep a transcript for JUnit, and mirror lines to STDOUT.

    CI (and devenv tasks) often pipe our stdout, so Python would block-buffer
    without an explicit flush — looking like a hung job with no log output.
    With quiet=True, skip ✅ pass lines; still mirror failures, errors, and
    summary lines.
    """
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    assert proc.stdout is not None
    chunks: list[str] = []
    for line in proc.stdout:
        chunks.append(line)
        if quiet:
            match = STATUS_RE.match(strip_ansi(line).rstrip())
            if match and match.group(1).startswith("✅"):
                continue
        sys.stdout.write(line)
        sys.stdout.flush()
    return proc.wait(), "".join(chunks)


def cmd_nix_unit(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    unit_dir = Path(args.unit_dir)
    if not unit_dir.is_absolute():
        unit_dir = root / unit_dir
    includes = list(args.include or [])
    if args.from_text:
        text = Path(args.from_text).read_text(encoding="utf-8", errors="replace")
        rc = 0
    else:
        suite = args.suite if Path(args.suite).is_absolute() else str(root / args.suite)
        cmd = [args.nix_unit, "-I", "nixpkgs=flake:nixpkgs"]
        for entry in includes:
            cmd.extend(["-I", entry])
        cmd.append(suite)
        rc, text = run_nix_unit(cmd, quiet=args.quiet)
    cases = parse_nix_unit(text, unit_dir, root)
    if not cases:
        cases = [
            {
                "name": "nix-unit",
                "classname": "tests.unit",
                "file": repo_relative(Path(args.suite), root)
                if not args.from_text
                else "tests/unit/default.nix",
                "line": 1,
                "status": "error" if rc else "passed",
                "message": "nix-unit produced no test results",
                "details": strip_ansi(text)[-4000:],
            }
        ]
    write_junit(Path(args.output), "nix-unit", cases)
    emit_github_annotations(cases)
    if args.quiet and cases:
        passed = sum(1 for case in cases if case["status"] == "passed")
        bad = sum(1 for case in cases if case["status"] in {"failed", "error"})
        print(f"==> nix-unit: {passed} passed, {bad} failed/error", flush=True)
    if args.from_text:
        return 1 if failed(cases) else 0
    return rc if rc != 0 else (1 if failed(cases) else 0)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", default="tests/unit/default.nix")
    parser.add_argument("--unit-dir", default="tests/unit")
    parser.add_argument("--output", required=True)
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--from-text", help="Parse this nix-unit transcript instead of running nix-unit"
    )
    parser.add_argument("--nix-unit", default="nix-unit")
    parser.add_argument(
        "-I",
        "--include",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help="Extra nix-unit -I include (repeatable). Typical: projectname=$root",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Hide ✅ pass lines when running nix-unit; still show failures and a summary",
    )
    parser.set_defaults(func=cmd_nix_unit)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
