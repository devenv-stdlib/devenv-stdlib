#!/usr/bin/env python3
"""Write JUnit XML for nix-unit, nixosTest, and BATS so CI can annotate PRs."""

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
    return file_path.replace("/", ".").removesuffix(".nix").removesuffix(".bats")


def locate_nix_unit(name: str, unit_dir: Path, root: Path) -> tuple[str | None, int | None]:
    for path in sorted(unit_dir.glob("*.nix")):
        if path.name in SKIP_UNIT:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.lstrip()
            if stripped.startswith(f"{name} =") or stripped.startswith(f"{name}="):
                return repo_relative(path, root), lineno
    return None, None


def locate_run_nixos_test(root: Path, rel: str) -> int | None:
    path = root / rel
    if not path.is_file():
        return None
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "runNixOSTest" in line:
            return lineno
    return None


def resolve_bats_file(raw: str, root: Path) -> str | None:
    if not raw:
        return None
    raw = raw.strip()
    for candidate in (root / raw, root / "tests" / raw, Path(raw)):
        if candidate.is_file() and candidate.suffix == ".bats":
            return repo_relative(candidate, root)
    name = Path(raw).name
    if name.endswith(".bats") and (root / "tests").is_dir():
        matches = [path for path in (root / "tests").rglob(name) if path.is_file()]
        if len(matches) == 1:
            return repo_relative(matches[0], root)
    return None


def locate_bats_test(path: Path, name: str) -> int | None:
    if not path.is_file():
        return None
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "@test" not in line:
            continue
        if f'"{name}"' in line or f"'{name}'" in line:
            return lineno
    return None


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


def write_junit(path: Path, suite_name: str, cases: list[dict], time_s: float | None = None) -> None:
    tests = len(cases)
    failures = sum(1 for case in cases if case["status"] == "failed")
    errors = sum(1 for case in cases if case["status"] == "error")
    skipped = sum(1 for case in cases if case["status"] == "skipped")
    suites = ET.Element("testsuites", {"tests": str(tests), "failures": str(failures), "errors": str(errors)})
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
    if time_s is not None:
        suite.set("time", f"{time_s:.3f}")
        suites.set("time", f"{time_s:.3f}")

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
            node = ET.SubElement(testcase, tag, {"message": (case.get("message") or status)[:1000]})
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


def run_nix_unit(cmd: list[str]) -> tuple[int, str]:
    """Run nix-unit, keep a transcript for JUnit, and mirror every line to STDOUT.

    CI (and devenv tasks) often pipe our stdout, so Python would block-buffer
    without an explicit flush — looking like a hung job with no log output.
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
        sys.stdout.write(line)
        sys.stdout.flush()
        chunks.append(line)
    return proc.wait(), "".join(chunks)


def cmd_nix_unit(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    unit_dir = Path(args.unit_dir)
    if not unit_dir.is_absolute():
        unit_dir = root / unit_dir
    if args.from_text:
        text = Path(args.from_text).read_text(encoding="utf-8", errors="replace")
        rc = 0
    else:
        suite = args.suite if Path(args.suite).is_absolute() else str(root / args.suite)
        rc, text = run_nix_unit([args.nix_unit, "-I", "nixpkgs=flake:nixpkgs", suite])
    cases = parse_nix_unit(text, unit_dir, root)
    if not cases:
        cases = [
            {
                "name": "nix-unit",
                "classname": "tests.unit",
                "file": repo_relative(Path(args.suite), root) if not args.from_text else "tests/unit/default.nix",
                "line": 1,
                "status": "error" if rc else "passed",
                "message": "nix-unit produced no test results",
                "details": strip_ansi(text)[-4000:],
            }
        ]
    write_junit(Path(args.output), "nix-unit", cases)
    emit_github_annotations(cases)
    if args.from_text:
        return 1 if failed(cases) else 0
    return rc if rc != 0 else (1 if failed(cases) else 0)


def tail_text(path: Path | None, lines: int = 200) -> str:
    if path is None or not path.is_file():
        return ""
    content = path.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(content[-lines:])


def stamp_native_junit(native: Path, dest: Path, file_path: str, line: int | None) -> bool:
    try:
        tree = ET.parse(native)
    except ET.ParseError:
        return False
    root = tree.getroot()
    found = False
    for testcase in root.iter("testcase"):
        found = True
        testcase.set("file", file_path)
        if line is not None and "line" not in testcase.attrib:
            testcase.set("line", str(line))
    if not found:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(root, space="  ")
    tree.write(dest, encoding="utf-8", xml_declaration=True)
    return True


def cases_from_junit(path: Path) -> list[dict]:
    tree = ET.parse(path)
    cases = []
    for testcase in tree.getroot().iter("testcase"):
        status = "passed"
        message = ""
        details = ""
        for child in list(testcase):
            tag = child.tag.split("}")[-1]
            if tag == "failure":
                status = "failed"
                message = child.get("message") or "failed"
                details = child.text or ""
            elif tag == "error":
                status = "error"
                message = child.get("message") or "error"
                details = child.text or ""
            elif tag == "skipped":
                status = "skipped"
        line = testcase.get("line")
        cases.append(
            {
                "name": testcase.get("name") or "test",
                "classname": testcase.get("classname") or "",
                "file": testcase.get("file"),
                "line": int(line) if line else None,
                "status": status,
                "message": message,
                "details": details,
            }
        )
    return cases


def cmd_nixos_test(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    rel = args.file
    line = locate_run_nixos_test(root, rel)
    dest = Path(args.output)
    if args.native and Path(args.native).is_file() and stamp_native_junit(Path(args.native), dest, rel, line):
        emit_github_annotations(cases_from_junit(dest))
        return 0 if args.status == 0 else 1
    if args.skipped:
        status = "skipped"
        message = "nixosTest skipped"
        details = "Skipped inside act (no /dev/kvm in the act container)."
    elif args.status == 0:
        status = "passed"
        message = ""
        details = ""
    else:
        status = "failed"
        message = "nixosTest failed"
        details = tail_text(Path(args.log) if args.log else None)
    cases = [
        {
            "name": "devenv",
            "classname": "tests.integration",
            "file": rel,
            "line": line,
            "status": status,
            "message": message,
            "details": details,
        }
    ]
    write_junit(dest, "nixosTest", cases)
    emit_github_annotations(cases)
    return 0 if args.status == 0 else 1


def cmd_enrich_bats(args: argparse.Namespace) -> int:
    root = Path(args.root).resolve()
    src = Path(args.input)
    dest = Path(args.output)
    if not src.is_file() or src.stat().st_size == 0:
        cases = [
            {
                "name": "bats",
                "classname": "tests",
                "file": None,
                "line": None,
                "status": "error",
                "message": "BATS produced no JUnit report",
                "details": "",
            }
        ]
        write_junit(dest, "bats", cases)
        emit_github_annotations(cases)
        return 1
    try:
        tree = ET.parse(src)
    except ET.ParseError as exc:
        cases = [
            {
                "name": "bats",
                "classname": "tests",
                "file": None,
                "line": None,
                "status": "error",
                "message": f"invalid BATS JUnit XML: {exc}",
                "details": src.read_text(encoding="utf-8", errors="replace")[-2000:],
            }
        ]
        write_junit(dest, "bats", cases)
        emit_github_annotations(cases)
        return 1

    xml_root = tree.getroot()
    for testcase in xml_root.iter("testcase"):
        raw = testcase.get("file") or testcase.get("classname") or ""
        rel = resolve_bats_file(raw, root)
        if rel:
            testcase.set("file", rel)
            line = locate_bats_test(root / rel, testcase.get("name") or "")
            if line is not None:
                testcase.set("line", str(line))
    dest.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(xml_root, space="  ")
    tree.write(dest, encoding="utf-8", xml_declaration=True)
    emit_github_annotations(cases_from_junit(dest))
    return 1 if failed(cases_from_junit(dest)) else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    nix_unit = sub.add_parser("nix-unit", help="Run or parse nix-unit and write JUnit XML")
    nix_unit.add_argument("--suite", default="tests/unit/default.nix")
    nix_unit.add_argument("--unit-dir", default="tests/unit")
    nix_unit.add_argument("--output", required=True)
    nix_unit.add_argument("--root", default=".")
    nix_unit.add_argument("--from-text", help="Parse this nix-unit transcript instead of running nix-unit")
    nix_unit.add_argument("--nix-unit", default="nix-unit")
    nix_unit.set_defaults(func=cmd_nix_unit)

    nixos = sub.add_parser("nixos-test", help="Write JUnit XML for a nixosTest run")
    nixos.add_argument("--output", required=True)
    nixos.add_argument("--status", type=int, required=True)
    nixos.add_argument("--log")
    nixos.add_argument("--skipped", action="store_true", help="Record a skipped nixosTest case")
    nixos.add_argument("--native", help="Optional driver-produced junit.xml to stamp with file/line")
    nixos.add_argument("--root", default=".")
    nixos.add_argument("--file", default="tests/integration/default.nix")
    nixos.set_defaults(func=cmd_nixos_test)

    bats = sub.add_parser("enrich-bats", help="Add file/line attributes to a BATS JUnit report")
    bats.add_argument("--input", required=True)
    bats.add_argument("--output", required=True)
    bats.add_argument("--root", default=".")
    bats.set_defaults(func=cmd_enrich_bats)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
