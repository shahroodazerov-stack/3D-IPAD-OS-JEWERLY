#!/usr/bin/env bash
# Validates docs/evidence/phase-NNN.json records used by phases whose proof
# requires a physical device or an external process. The file is the gate:
# a missing, malformed or failed record fails the phase even on a simulator-only runner.
#
#   bash scripts/check-evidence.sh        validate every existing record
#   bash scripts/check-evidence.sh 143    validate one phase record (required)
set -euo pipefail
cd "$(dirname "$0")/.."

PY="${PYTHON:-}"
if [ -z "$PY" ]; then
  if command -v python3 >/dev/null 2>&1; then PY=python3; else PY=python; fi
fi

"$PY" - "$@" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path.cwd()
schema_path = root / "docs/evidence/schema.json"
readme = root / "docs/evidence/README.md"

errors = []
if not schema_path.exists():
    errors.append("docs/evidence/schema.json is missing")
if not readme.exists():
    errors.append("docs/evidence/README.md is missing")

required = ["phase", "check", "result", "device", "os", "recorded_at", "artifacts", "notes"]
files = []

if len(sys.argv) > 1:
    for arg in sys.argv[1:]:
        n = int(arg)
        files.append(root / f"docs/evidence/phase-{n:03d}.json")
else:
    files = sorted((root / "docs/evidence").glob("phase-*.json"))

for path in files:
    if not path.exists():
        errors.append(f"{path.relative_to(root)} is missing (phase record required)")
        continue
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        errors.append(f"{path.relative_to(root)} is not valid JSON: {exc}")
        continue
    for key in required:
        if key not in data:
            errors.append(f"{path.relative_to(root)}: missing key {key!r}")
    if data.get("result") != "pass":
        errors.append(f"{path.relative_to(root)}: result is {data.get('result')!r}, expected 'pass'")
    if not isinstance(data.get("artifacts"), list) or not data.get("artifacts"):
        errors.append(f"{path.relative_to(root)}: artifacts must be a non-empty list")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(data.get("recorded_at", ""))):
        errors.append(f"{path.relative_to(root)}: recorded_at must be YYYY-MM-DD")
    if not str(data.get("device", "")).strip():
        errors.append(f"{path.relative_to(root)}: device must name the hardware")
    if not str(data.get("check", "")).strip():
        errors.append(f"{path.relative_to(root)}: check must name the executed check")

if errors:
    print(f"evidence check: FAIL — {len(errors)} problem(s)")
    for e in errors:
        print("FAIL:", e)
    sys.exit(1)

print(f"evidence check: PASS — {len(files)} record(s) valid")
PY
