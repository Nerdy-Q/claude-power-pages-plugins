# pp-permissions-audit

A Claude Code skill that **audits a Power Pages classic portal's permissions configuration** — Web Roles, Table Permissions, Site Settings, Web API enablement, and custom JS — to find misalignments and security risks.

## What this is

A **knowledge + analytical skill**. The skill ships a stdlib-only Python script that reads YAML and JS files, cross-references findings, and emits a markdown (or JSON) report of issues with severity levels (ERROR / WARN / INFO). The model interprets findings and proposes fixes — but never auto-applies them.

## What it catches

| Code | Severity | Finding |
|---|---|---|
| ERR-001 | ERROR | Web API enabled but no Table Permission grants Read |
| ERR-002 | ERROR | Orphaned Table Permission (no Web Roles assigned) |
| ERR-003 | ERROR | Anonymous Users role granted Write/Create/Delete on a sensitive table |
| WRN-001 | WARN | Custom JS uses `<lookup>@odata.bind` without `_contact` / `_account` suffix on a polymorphic field — runtime 400 risk |
| WRN-002 | WARN | Web Role exists but no Table Permission references it |
| INFO-001 | INFO | Table Permission allows Read but Web API isn't enabled (would 404) |
| INFO-002 | INFO | `Webapi/<entity>/Fields = *` exposes all fields (consider narrowing) |
| INFO-003 | INFO | Page requires auth but no role rule (any authenticated user can see) |
| INFO-004 | INFO | Role-permission junction not exported — role-aware checks skipped |

## Run it directly

```bash
python3 <skill-cache>/scripts/audit.py <site-folder>
python3 <skill-cache>/scripts/audit.py <site-folder> -o report.md
python3 <skill-cache>/scripts/audit.py <site-folder> --json
```

The skill knows where the cached `audit.py` lives and will invoke it automatically when you ask it to audit a portal.

## Reference files

- `references/checks.md` — full list of audit checks with codes and trigger conditions
- `references/interpreting.md` — how to interpret each finding type, false-positive cases, when to act
- `references/remediation.md` — how to fix each finding type
- `references/api-config.md` — Power Pages Web API site setting reference (deep)
- `CI.md` — GitHub Actions / Azure Pipelines / pre-commit hook integration
- `examples/github-actions/power-pages-audit.yml` — drop-in workflow template

## What it catches in production

Smoke-tested against multiple real Power Pages portals (commercial + USGov, single-environment + dual-environment dev/client, single-portal + multi-division). Representative findings from those runs:

- **ERR-001** (Web API enabled with no Table Permission) — common when site settings get added eagerly during dev but the matching permission never gets configured. Typical run: 5–20 findings per portal.
- **INFO-002** (`Webapi/<entity>/Fields = *` wildcards) — common when permissions are set up via Studio defaults. Often 100+ findings on portals with many entities.
- **WRN-001** (polymorphic lookup without `_contact` / `_account` suffix) — pre-empts a 400 Bad Request at runtime. Caught a real bug on a customer-type lookup that would have shipped to a production form.
- **WRN-004** (custom JS calling `/_api/` without anti-forgery token) — pre-empts a 403. Caught files where the safeAjax pattern was missing.
- **INFO-005** (base-vs-localized file divergence) — the canonical "page renders blank" bug. Caught half a dozen on a single portal.

The pre-emptive bug detection (WRN-001, WRN-004, INFO-005) is the kind of catch this skill is most valuable for — these would otherwise show up as runtime errors after deploy.

## What this skill does NOT do

- **Auto-apply fixes** — every fix is proposed to the user, not applied automatically. Permissions changes affect security; the user must approve each one.
- **Live-query Dataverse** — this is static analysis of local site source. It can't verify whether a Web Role is actually assigned to specific Contacts (that lives in Dataverse). For live verification, use the `dataverse` plugin (`dv-query`).
- **Audit Dataverse-side security** — System User roles, security roles on entities, business unit boundaries are out of scope. This skill audits the **portal layer** only.
- **Audit code sites** (React/Vue/Astro SPAs) — different security model, different config files. NOT supported.

## Dependencies

- Python 3.7+
- Stdlib only (PyYAML used opportunistically if installed; falls back to a hand-rolled parser otherwise)

## License

MIT
