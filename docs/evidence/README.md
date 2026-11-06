# Evidence records

Some acceptance checks cannot be executed on a GitHub-hosted macOS runner: they need a
physical iPad (thermal state, sustained frame rate, Pencil palm rejection), a human
(VoiceOver, keyboard-only run, usability study), or an external service (TestFlight,
App Store Connect, legal sign-off).

Those phases are still gated. Their acceptance names a record under
`docs/evidence/phase-NNN.json`; `scripts/check-evidence.sh NNN` fails when the record is
missing, malformed, incomplete, or records anything other than `pass`. The CI gate runs the
validator, so a skipped evidence step turns the phase red instead of being silently waived.

This is deliberately narrow. A phase may only use an evidence record for the part of its
proof that genuinely cannot run on a runner. Everything that can be a unit, geometry,
snapshot, or XCUITest assertion must be one.

## Required fields

| Field | Type | Meaning |
| --- | --- | --- |
| `phase` | integer | Phase number, matching the filename |
| `check` | string | The exact acceptance check that was executed |
| `result` | `"pass"` \| `"fail"` | Only `pass` satisfies the gate |
| `device` | string | Hardware and OS, e.g. `iPad Air (M3), iPadOS 26.1` |
| `os` | string | Host or runner OS used for any accompanying automated check |
| `recorded_at` | string | `YYYY-MM-DD` |
| `artifacts` | string[] | Non-empty paths/URLs: recording, Instruments trace, upload run, signed PDF |
| `notes` | string | What was measured, by whom, and any deviation |

## Rules

1. Record the measurement, not an opinion. "60 fps sustained for 10 minutes" with an
   Instruments trace beats "looks smooth".
2. Never edit an old record to make a new run pass. Add a new dated record and supersede it
   in `notes`; the git history is the audit trail.
3. Artifacts live outside the repo when large (screen recordings); the field must point at a
   durable URL or a path under `.dev-cache/evidence/` that is not committed.
4. A record with `result: "fail"` blocks the phase exactly like a red test.

## Example

```json
{
  "phase": 143,
  "check": "Sustained 60 fps at 1 M triangles on iPad Pro for 10 minutes; resolution scaling engages before 20 ms",
  "result": "pass",
  "device": "iPad Pro 11-inch (M5), iPadOS 26.1",
  "os": "macOS 26.1 (host), Xcode 26.6",
  "recorded_at": "2027-02-14",
  "artifacts": ["https://example.invalid/traces/phase-143.trace"],
  "notes": "Median 16.4 ms, p99 19.2 ms over 10 min; quality tier dropped once at 8:12."
}
```
