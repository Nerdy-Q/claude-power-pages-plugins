# pp-liquid

A Claude Code skill for working in **classic Microsoft Power Pages** portals — Web Templates, FetchXML in Liquid, Web API in custom JS, hybrid render-then-mutate pages, DotLiquid quirks, and `pac paportal` sync.

## What this is

This is a **knowledge skill**, not a runner skill. It provides the model with reference patterns, gotchas, and decision routing for hybrid Power Pages portals — the kind where Liquid renders the initial state and custom JavaScript handles interactivity via the `/_api/<entity>` Web API.

## Scope

- ✅ Power Pages classic portals (Studio + `pac paportal`-managed sites)
- ✅ Hybrid Liquid + Web API custom pages
- ✅ FetchXML query patterns (`{% fetchxml %}`)
- ✅ Power Pages entity tags (`{% entitylist %}`, `{% entityform %}`, `{% webform %}`)
- ✅ Web Roles, Table Permissions, Site Settings model
- ✅ DotLiquid-specific gotchas (JSON escape, date filters, comment syntax)
- ✅ `pac paportal` sync workflow patterns

- ❌ Power Pages **code sites** (React/Vue/Astro SPAs) — use Microsoft's `power-pages` plugin
- ❌ Shopify or Jekyll Liquid — different objects, tags, and filter behavior
- ❌ Power Apps Canvas / Model-Driven apps
- ❌ Dataverse schema authoring outside the portal — use the `dataverse` plugin

## Reference files

The skill loads `SKILL.md` first (router + critical gotchas). Detail lives in topic-specific reference files the model pulls on demand:

| File | Topic |
|---|---|
| `references/fetchxml-patterns.md` | `{% fetchxml %}` count+paginate+filter, link-entity, aggregation |
| `references/webapi-patterns.md` | `safeAjax`, GET/POST/PATCH/DELETE, `@odata.bind`, file upload |
| `references/entity-tags.md` | `{% entitylist %}`, `{% entityform %}`, `{% webform %}`, includes, blocks |
| `references/objects-reference.md` | `user`, `page`, `website`, `request`, `weblinks`, `snippets`, `sitemarkers`, `settings` |
| `references/hybrid-page-idiom.md` | Liquid render scaffold + JS mutate; base vs localized files |
| `references/dotliquid-gotchas.md` | DotLiquid behavioral differences from Shopify Liquid |
| `references/sync-workflow.md` | `pac paportal` patterns, wrapper scripts, cache hangs |
| `references/permissions-and-roles.md` | Web Roles, Table Permissions scopes, Web API access requirements |

## Install

```bash
claude plugin marketplace add https://github.com/Nerdy-Q/claude-plugins
claude plugin install pp-liquid@nq-claude-plugins
```

Or from a local checkout:

```bash
git clone https://github.com/Nerdy-Q/claude-plugins
claude plugin marketplace add ./claude-plugins
claude plugin install pp-liquid@nq-claude-plugins
```

## Verify it loaded

After install, ask Claude something like:

> What's the right pattern for a paginated, search-filterable customer list on a Power Pages portal?

The model should load `SKILL.md` and `references/fetchxml-patterns.md` automatically.

## License

MIT
