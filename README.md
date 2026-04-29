# nq-claude-plugins

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Power Pages](https://img.shields.io/badge/Power%20Pages-classic-purple.svg)](https://learn.microsoft.com/en-us/power-pages/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin%20marketplace-orange.svg)](https://docs.claude.com/en/docs/claude-code/plugins)

Open-source Claude Code plugins from [NerdyQ](https://github.com/Nerdy-Q) for **Microsoft Power Pages classic portals**: hybrid Liquid + Web API patterns, safe `pac paportal` sync workflows, and static-analysis security audit.

If you build classic Power Pages sites — particularly the hybrid pattern where Liquid renders the initial state and custom JS calls `/_api/<entity>` for interactivity — this marketplace turns Claude Code into a Power Pages-aware pair programmer that knows the gotchas, runs the right `pac` commands with the right safety guards, and audits your portal's permissions for misalignment.

## Plugins

| Plugin | Purpose |
|---|---|
| [`pp-liquid`](plugins/pp-liquid/) | Microsoft Power Pages classic Liquid templating reference — Web Templates, FetchXML in Liquid, Web API in custom JS, hybrid pages, DotLiquid gotchas, troubleshooting |
| [`pp-sync`](plugins/pp-sync/) | Action skill + `pp` CLI for running portal sync workflows safely — `pac paportal` + project registry + alias resolution + bulk-upload safety guards + 6 ready-to-drop wrapper templates |
| [`pp-permissions-audit`](plugins/pp-permissions-audit/) | Static-analysis audit of a portal's Web Roles, Table Permissions, Site Settings, and Web API config — 13 checks including base-vs-localized blank-page detection, polymorphic lookup pre-emption, and missing-token detection |

## Install

```bash
claude plugin marketplace add https://github.com/Nerdy-Q/claude-plugins
claude plugin install pp-liquid@nq-claude-plugins
claude plugin install pp-sync@nq-claude-plugins
claude plugin install pp-permissions-audit@nq-claude-plugins
```

After installing `pp-sync`, run its installer once to put the `pp` CLI on your PATH:

```bash
~/.claude/plugins/cache/nq-claude-plugins/pp-sync/<version>/install.sh
pp setup    # interactive bootstrap — auto-detects PAC profiles + site folders
```

## Marketplace structure

```
nq-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json              # marketplace manifest
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json           # plugin manifest
│       ├── README.md
│       └── skills/<skill-name>/
│           ├── SKILL.md              # skill entry point (frontmatter + body)
│           └── references/...        # topic-specific reference files
```

## Add a new plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json`
2. Add a `skills/<name>/SKILL.md` (or commands, agents, or MCP server)
3. Add an entry to `.claude-plugin/marketplace.json` under `plugins`
4. From any Claude Code session: `claude plugin install <name>@nq-claude-plugins`

If the marketplace was already added, re-add it to refresh: `claude plugin marketplace add <path>`.

## Conventions

- **Plugin slugs**: short, kebab-case, prefixed with the platform if ambiguous (`pp-liquid` for Power Pages Liquid; `dv-*` is reserved for Microsoft's `dataverse` plugin)
- **Skill descriptions**: must include both positive triggers ("use when…") and explicit negatives ("NOT for…") so the description-gated skill loader doesn't drift onto unrelated tasks
- **Reference files**: keep `SKILL.md` lean (overview + critical gotchas + decision routing); push detail to `references/<topic>.md` so the model lazy-loads only what it needs
- **No client-specific identifiers in shipped content** — anonymize examples using fictional company names (Acme, Contoso) or placeholder syntax (`<your-prefix>_<field>`)

## License

MIT
