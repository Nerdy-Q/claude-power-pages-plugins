# CI integration

The `pp-permissions-audit` script (`scripts/audit.py`) is **stdlib-only Python with `--exit-code` and `--severity` flags** — perfect for CI gates. This guide shows how to wire it into GitHub Actions, Azure DevOps, or any CI runner.

## GitHub Actions (recommended)

A ready-to-use workflow ships at [`examples/github-actions/power-pages-audit.yml`](examples/github-actions/power-pages-audit.yml). Drop it into your Power Pages project's repo:

```bash
mkdir -p .github/workflows
curl -o .github/workflows/power-pages-audit.yml \
     https://raw.githubusercontent.com/Nerdy-Q/claude-plugins/main/plugins/pp-permissions-audit/examples/github-actions/power-pages-audit.yml
```

What it does:

- Triggers on PRs that touch portal source files (web-pages, web-templates, site-settings, table-permissions, etc.)
- Auto-detects the site folder (the first `<name>---<name>/` containing `website.yml` + `web-pages/`)
- Fetches the audit script from a pinned tag (`v1.2.0` by default)
- Runs `audit.py --severity ERROR --exit-code` to gate the PR
- Uploads the **full report** (including WARN + INFO findings) as a build artifact, so reviewers can read all findings without re-running locally
- Optional: commenting the summary on the PR (commented out by default — uncomment to enable, plus the `permissions:` block)

### Pinning to a version

The template uses `AUDIT_REF: 'v1.2.0'` to pin to a released version. Bump this when you upgrade. Alternatives:

- `AUDIT_REF: 'main'` — always latest (convenient for early adopters; brittle for production)
- `AUDIT_REF: '<commit-sha>'` — exact commit pin (most reproducible)

### Multi-site repos

If your repo contains multiple Power Pages sites (e.g., one portal per division), the auto-detection finds the first match. To audit a specific site:

```yaml
- name: Run audit (PR gate)
  run: |
    python3 /tmp/pp-audit/audit.py path/to/specific/site---site/ \
            --severity ERROR --exit-code
```

Or run the audit step multiple times, once per site, with a matrix:

```yaml
strategy:
  matrix:
    site:
      - divisions/division-a/pages/site-a---site-a
      - divisions/division-b/pages/site-b---site-b
```

### Tightening or relaxing the gate

The default gate is `--severity ERROR --exit-code` — fail PR only on ERROR-class findings. Adjust:

| Stricter | More lenient |
|---|---|
| `--severity WARN --exit-code` | `--severity ERROR --exit-code` (default) |
| Fails PR on WARN-class too (`@odata.bind` casing, missing tokens, polymorphic shape) | Fails only on definite bugs (Web API enabled with no permission, anonymous-role writes) |

For a brand-new audit setup, run with `--severity ERROR` for a few weeks, fix what comes up, then ratchet to `--severity WARN`.

## Azure DevOps Pipelines

```yaml
trigger:
  branches:
    include: [main]
  paths:
    include:
      - '**/web-pages/**'
      - '**/web-templates/**'
      - '**/site-settings/**'
      - '**/sitesetting.yml'
      - '**/table-permissions/**'

pr:
  branches:
    include: ['*']
  paths:
    include:
      - '**/web-pages/**'
      - '**/web-templates/**'
      - '**/site-settings/**'
      - '**/sitesetting.yml'
      - '**/table-permissions/**'

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.11'

  - bash: |
      curl -fsSL https://raw.githubusercontent.com/Nerdy-Q/claude-plugins/v1.2.0/plugins/pp-permissions-audit/skills/pp-permissions-audit/scripts/audit.py \
           -o /tmp/audit.py
    displayName: 'Fetch audit script'

  - bash: |
      SITE_DIR=$(find . -maxdepth 6 -type d -name '*---*' | while read d; do
        [ -f "$d/website.yml" ] && [ -d "$d/web-pages" ] && echo "$d" && break
      done)
      python3 /tmp/audit.py "$SITE_DIR" --severity ERROR --exit-code
    displayName: 'Run audit'

  - bash: |
      python3 /tmp/audit.py "$SITE_DIR" -o $(Build.ArtifactStagingDirectory)/audit-report.md
    displayName: 'Generate full report'
    condition: always()

  - publish: $(Build.ArtifactStagingDirectory)/audit-report.md
    artifact: pp-permissions-audit-report
    condition: always()
```

## Generic CI / shell script

If your CI is generic shell (Jenkins, CircleCI, GitLab, Buildkite):

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Fetch the audit script
curl -fsSL https://raw.githubusercontent.com/Nerdy-Q/claude-plugins/v1.2.0/plugins/pp-permissions-audit/skills/pp-permissions-audit/scripts/audit.py \
     -o /tmp/audit.py

# 2. Detect site folder
SITE_DIR=$(find . -maxdepth 6 -type d -name '*---*' | while read d; do
  [ -f "$d/website.yml" ] && [ -d "$d/web-pages" ] && echo "$d" && break
done)
[ -n "$SITE_DIR" ] || { echo "ERROR: no Power Pages site folder found"; exit 1; }

# 3. Run audit (PR gate)
python3 /tmp/audit.py "$SITE_DIR" --severity ERROR --exit-code

# 4. Generate full report (always, even on failure)
python3 /tmp/audit.py "$SITE_DIR" -o audit-report.md
```

## Pre-commit hook

For a local-only gate on every commit (run before push):

```bash
# .git/hooks/pre-commit
#!/usr/bin/env bash
SCRIPT=$(find ~/.claude/plugins/cache/nq-claude-plugins/pp-permissions-audit -name audit.py | sort -V | tail -1)
SITE_DIR=$(find . -maxdepth 6 -type d -name '*---*' | head -1)
python3 "$SCRIPT" "$SITE_DIR" --severity ERROR --exit-code || {
  echo "Audit failed. Fix ERROR-class findings before committing."
  echo "Run 'pp audit <project>' to see the full report."
  exit 1
}
```

## Reading the JSON output

For richer CI integration (custom dashboards, JIRA-issue-creation, Slack notifications), use `--json`:

```bash
python3 audit.py site---site/ --severity ERROR --json > audit.json

# Count findings by severity:
jq '.findings | group_by(.severity) | map({severity: .[0].severity, count: length})' audit.json

# Get all ERROR-class with locations:
jq '.findings[] | select(.severity == "ERROR") | {code, title, location}' audit.json

# Slack-ready summary:
jq -r '"*\(.findings | map(select(.severity == "ERROR")) | length)* errors, *\(.findings | map(select(.severity == "WARN")) | length)* warnings on `\(.site)`"' audit.json
```

## Schema-aware checks in CI

WRN-006 / WRN-007 / WRN-008 (the schema-aware checks) only run when `dataverse-schema/` is present in the repo. If your CI checks out the portal source but the schema lives in a separate repo or solution-export pipeline, you have two options:

1. **Commit the unpacked schema to the portal repo** (recommended). Periodically run `pac solution export` + `pac solution unpack` and commit the output. The audit then has authoritative attribute info on every CI run.
2. **Fetch the schema in the workflow** before running the audit. Add a step that pulls and unpacks the latest solution before invoking `audit.py`.

Without the schema present, the audit is still useful — it just runs the heuristic checks (WRN-001 / WRN-005, INFO-005 / INFO-009, etc.) and skips the deterministic ones.

## What "successful CI" looks like

A clean CI run for a mature Power Pages project typically shows:

- **0 ERROR** (the gate)
- A small number of WARN: heuristic catches that may or may not be real bugs (review during code review)
- A larger number of INFO: configuration drift signals (review periodically, not every PR)

The first time you run the audit on an existing portal, expect a flood of findings. Don't try to fix all of them at once — set the gate at `--severity ERROR`, fix those over a sprint, then look at WARN-class findings.
