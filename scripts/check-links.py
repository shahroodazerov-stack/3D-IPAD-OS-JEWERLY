#!/usr/bin/env python3
"""Fetch every URL cited in docs/research/*.md and record what the server returned.

Writes docs/evidence/link-status.json and docs/evidence/link-status.md.
A non-2xx status is recorded, not guessed at. Use --strict to exit non-zero when
any citation is not a 2xx (useful before a release, too noisy for routine runs
because several vendors block automated clients with 403).
"""
from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import json
import pathlib
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
RESEARCH = ROOT / "docs/research"
OUT_JSON = ROOT / "docs/evidence/link-status.json"
OUT_MD = ROOT / "docs/evidence/link-status.md"
UA = "FacetForge-citation-audit/1.0 (+clean-room research; contact: repo owner)"
TIMEOUT = 25
MAX_BYTES = 65536

URL_RE = re.compile(r"https?://[^\s)\]<>\"'`]+")

# Responses that are not a clean 200 but are still the correct, official page.
# The recorded code stays truthful; the note explains the client-side block.
KNOWN_NOTES = {
    "https://www.iso.org/standard/65408.html": "official ISO catalogue page; 403 is bot blocking, not a missing page",
    "https://gemvision.com/": "vendor homepage; 206 is a valid ranged response",
    "https://www.autodesk.com/products/fusion-360/pricing": "vendor pricing page; 403 is bot blocking, not a missing page",
    "https://www.cadjewelleryskills.com/jewellery-tech-blog-topics/jewellery-learning-resources/rhino-cad-rendering-comparison-test-part-1": "independent rendering comparison; 403 is bot blocking; the Cycles claim is corroborated by the 2.5 release note linking Render Studio to Rhino Cycles Settings",
}


def extract() -> dict[str, dict]:
    found: dict[str, dict] = {}
    for path in sorted(RESEARCH.glob("*.md")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(text.splitlines(), 1):
            for match in URL_RE.finditer(line):
                url = match.group(0).rstrip(".,;:")
                if url.endswith("`"):
                    url = url.rstrip("`")
                entry = found.setdefault(url, {"url": url, "sources": []})
                entry["sources"].append(f"{path.name}:{lineno}")
    return dict(sorted(found.items()))


def title_of(body: bytes) -> str:
    try:
        text = body.decode("utf-8", errors="replace")
    except Exception:
        return ""
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    if not m:
        return ""
    return re.sub(r"\s+", " ", m.group(1)).strip()[:160]


def classify(url: str, code: int | None, body: bytes, final: str, err: str) -> tuple[str, list[str]]:
    notes: list[str] = []
    parsed = urllib.parse.urlsplit(url)
    path = parsed.path
    if "..." in url or "%E2%80%A6" in url or "\u2026" in url:
        notes.append("url contains an ellipsis")
    if parsed.netloc and path in ("", "/"):
        notes.append("bare host (no specific page)")
    if path.endswith("/") and re.search(r"/(samples|download|downloads)/", path):
        notes.append("directory-like URL, no document filename")

    if err:
        return err, notes
    if code is None:
        return "network_error", notes
    if 200 <= code < 300:
        if len(body) < 400:
            notes.append(f"tiny body ({len(body)} bytes)")
        page_title = title_of(body).lower()
        if any(x in page_title for x in ("not found", "404", "error")):
            notes.append(f"title looks like an error page: {title_of(body)!r}")
        if notes:
            return "ok_suspect", notes
        return "ok", notes
    if 400 <= code < 500:
        return "http_4xx", notes
    if 500 <= code < 600:
        return "http_5xx", notes
    return "http_other", notes


def fetch(item: tuple[str, dict]) -> dict:
    url, meta = item
    result = {
        "url": url,
        "sources": meta["sources"],
        "http_code": None,
        "final_url": None,
        "content_type": None,
        "body_bytes": 0,
        "status": "network_error",
        "fetched_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "note": "",
    }
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml,application/pdf,*/*;q=0.8",
            "Range": f"bytes=0-{MAX_BYTES - 1}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            body = resp.read(MAX_BYTES)
            code = resp.status
            final = resp.geturl()
            ctype = resp.headers.get("Content-Type", "")
    except urllib.error.HTTPError as exc:
        code = exc.code
        final = exc.geturl()
        ctype = exc.headers.get("Content-Type", "") if exc.headers else ""
        try:
            body = exc.read(MAX_BYTES)
        except Exception:
            body = b""
    except urllib.error.URLError as exc:
        reason = exc.reason
        if isinstance(reason, ssl.SSLError):
            result["status"] = "tls_error"
        elif isinstance(reason, TimeoutError) or "timed out" in str(reason).lower():
            result["status"] = "timeout"
        elif "name or service not known" in str(reason).lower() or "getaddrinfo" in str(reason).lower():
            result["status"] = "dns_error"
        else:
            result["status"] = "network_error"
        result["note"] = str(reason)[:240]
        return result
    except TimeoutError:
        result["status"] = "timeout"
        result["note"] = f"no response within {TIMEOUT}s"
        return result
    except Exception as exc:
        result["status"] = "network_error"
        result["note"] = f"{type(exc).__name__}: {exc}"[:240]
        return result

    status, notes = classify(url, code, body, final, "")
    if url in KNOWN_NOTES:
        notes.append(KNOWN_NOTES[url])
    result.update(
        {
            "http_code": code,
            "final_url": final,
            "content_type": ctype,
            "body_bytes": len(body),
            "status": status,
            "note": "; ".join(notes),
        }
    )
    if final and final != url:
        result["note"] = (result["note"] + "; " if result["note"] else "") + f"redirected to {final}"
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true", help="exit 1 if any status is not ok")
    args = parser.parse_args()

    urls = extract()
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        results = list(pool.map(fetch, urls.items()))

    counts: dict[str, int] = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(
        json.dumps(
            {
                "generated_at": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                "source_glob": "docs/research/*.md",
                "total": len(results),
                "counts": counts,
                "entries": results,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    lines = [
        "# Citation fetch status",
        "",
        f"Generated by `scripts/check-links.py` on {dt.date.today().isoformat()}.",
        f"{len(results)} unique URLs extracted from `docs/research/*.md`.",
        "",
        "Status values: `ok` (2xx), `ok_suspect` (2xx but bare host / tiny body / error-looking",
        "title), `http_4xx`, `http_5xx`, `timeout`, `dns_error`, `tls_error`, `network_error`.",
        "A status is what the server returned, not a judgement about whether the claim is true.",
        "",
        "| Status | Count |",
        "| --- | --- |",
    ]
    for key in sorted(counts):
        lines.append(f"| `{key}` | {counts[key]} |")
    lines += [
        "",
        "## Citation repairs applied",
        "",
        "| Original problem | Resolution |",
        "| --- | --- |",
        "| `cdn.standards.iteh.ai/samples/65408/` returned 404 (truncated sample path) | Removed; ISO catalogue page retained |",
        "| `formlabs-media.formlabs.com/` returned 403 (bare host) | Replaced with the Formlabs casting white paper |",
        "| `castinghouse.com/.../anatomy-of-a-ring.html` returned 522 | Removed; claim is supported by the Besco and Stuller sources |",
        "| `4cs.gia.edu/.../how-to-buy-a-quality-diamond/` timed out | Replaced with GIA's fancy-shape cut-grade FAQ |",
        "| GitHub workflow-syntax URL returned 404 | Updated to the current `workflow-syntax` page |",
        "| Bluecast URL with a colon in the path was flagged as suspect | Verified 200; retained |",
        "",
        "## Failures and suspects",
        "",
        "| HTTP | Status | URL | Sources | Note |",
        "| --- | --- | --- | --- | --- |",
    ]
    bad = [r for r in results if r["status"] != "ok"]
    if not bad:
        lines.append("| — | — | — | — | none |")
    for r in bad:
        src = ", ".join(sorted(set(r["sources"])))
        note = (r["note"] or "").replace("|", "\\|")
        lines.append(f"| {r['http_code'] or '—'} | `{r['status']}` | {r['url']} | {src} | {note} |")
    lines += ["", "## All URLs", "", "| HTTP | Status | URL | Sources |", "| --- | --- | --- | --- |"]
    for r in results:
        src = ", ".join(sorted(set(r["sources"])))
        lines.append(f"| {r['http_code'] or '—'} | `{r['status']}` | {r['url']} | {src} |")
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"checked {len(results)} URLs -> {OUT_JSON.relative_to(ROOT)}, {OUT_MD.relative_to(ROOT)}")
    print("counts:", json.dumps(counts, sort_keys=True))
    for r in bad:
        print(f"  {r['http_code'] or '---'} {r['status']:<12} {r['url']}  ({r['note'][:120]})")

    if args.strict and bad:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
