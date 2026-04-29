---
name: pp-liquid
description: Microsoft Power Pages classic Liquid templating — Web Templates, Page Templates, Content Snippets, FetchXML in Liquid, Web API in custom JS, hybrid page pattern, and pac paportal sync. Use when working in *.liquid, *.webpage.copy.html, *.webtemplate.source.html, or *.webpage.custom_javascript.js files; when building or debugging classic Power Pages portals; or when the user mentions Power Pages, Power Apps Portals, Dynamics Portals, fetchxml, entitylist, entityform, webform, web roles, table permissions, or sitemarkers. NOT for code sites (React/Vue/Astro SPAs) or Shopify/Jekyll Liquid.
---

# Power Pages Liquid

Classic-portal Liquid templating reference for Microsoft Power Pages (formerly Power Apps Portals, formerly Dynamics 365 Portals). Covers the **server-rendered Liquid + client-side Web API** hybrid pattern that real production portals use.

> **NOT for**: Power Pages **code sites** (React/Vue/Astro SPAs that call the Web API directly — those use Microsoft's `power-pages` plugin). NOT for Shopify, Jekyll, or generic Liquid — Power Pages uses **DotLiquid**, a .NET reimplementation with different filter behavior in important places (see [dotliquid-gotchas.md](references/dotliquid-gotchas.md)).

## When this skill applies

Apply this skill when any of these are true:

- File extension is `.liquid`, `.webpage.copy.html`, `.webtemplate.source.html`, `.contentsnippet.value.html`, `.webpage.custom_javascript.js`
- Directory contains `web-pages/`, `web-templates/`, `web-files/`, `content-snippets/`, `page-templates/`, `table-permissions/`, `web-roles/`, or `website.yml`
- User mentions Power Pages, Power Apps Portals, Dynamics 365 Portals, FetchXML, entitylist, entityform, webform, web roles, sitemarkers, or `pac paportal`
- Code uses `window.shell.getTokenDeferred()`, `__RequestVerificationToken`, or `/_api/<entity>`

## Power Pages classic site anatomy

A `pac paportal download` produces this canonical structure:

```
<site-name>---<site-name>/
├── website.yml                              # site root metadata
├── .portalconfig/                           # tenant/env-specific (often gitignored)
├── web-pages/                               # one folder per page
│   └── <page-slug>/
│       ├── <Page>.webpage.yml               # page metadata
│       ├── <Page>.webpage.copy.html         # ⚠ BASE Liquid template (THIS is loaded)
│       ├── <Page>.webpage.custom_javascript.js
│       ├── <Page>.webpage.custom_css.css
│       └── content-pages/
│           └── <Page>.en-US.webpage.copy.html  # localized — NOT loaded by default
├── web-templates/                           # reusable Liquid components
│   └── <name>/<Name>.webtemplate.source.html
├── page-templates/                          # page layouts (reference web-templates)
├── content-snippets/                        # editable content blocks
│   └── <name>/<Name>.contentsnippet.value.html
├── web-files/                               # CSS / JS / images served at /<filename>
├── basic-forms/                             # entityform metadata
├── advanced-forms/                          # webform (multi-step) metadata
├── entity-lists/                            # entitylist metadata
├── table-permissions/                       # YAML — CRUD rules per table per role
├── web-roles/                               # YAML — role definitions
├── site-settings/                           # YAML — k/v site config (CSP lives here)
└── sitemarkers/                             # YAML — named URL anchors for Liquid
```

## Four critical gotchas — read these first

### 1. Base file ↔ localized file pair must stay in sync

Power Pages stores **two physical copies** of every page asset: a base file (`<Page>.webpage.copy.html`) and one or more localized files (`content-pages/<lang>/<Page>.<lang>.webpage.copy.html`). The base is what most users get. The localized file renders only when the user requests a matching locale AND… implementation details vary.

**Two distinct failure modes:**

| Mode | Symptom | What happened |
|---|---|---|
| **A. Empty base** | Page renders blank | The base file is empty (Studio sometimes saves edits only to localized). Audit catches this as **INFO-005**. |
| **B. Diverged pair** | Some users see different content than others | Both files were edited at different times; they've drifted. Audit catches this as **INFO-009**. |

**The maintenance rule that prevents both**: when you edit ONE file in the pair, edit the OTHER too — or use `pp sync-pages <project>` to copy one to the other in bulk. The tooling does not auto-sync.

Files affected (each has a base + localized form): `*.webpage.copy.html`, `*.webpage.custom_javascript.js`, `*.webpage.custom_css.css`, `*.webpage.summary.html`.

**A common workflow that creates Mode A bugs**: dev edits a page in Studio (which saves to localized only) → commits → on another machine the page renders blank because the puller's Studio didn't auto-populate the localized version of *their* base. Always sync after Studio edits. See [hybrid-page-idiom.md](references/hybrid-page-idiom.md).

### 2. DotLiquid JSON serialization breaks JavaScript

`replace: '"', '\\"'` in DotLiquid produces **3 chars** (`\`, `\`, `"`) — backslash escaping doesn't work the way it does in Shopify. Inline JSON inside `<script>` tags will silently break.

**Fix:** Always emit data via `<script type="application/json">` with **Unicode escapes**, then `JSON.parse` in your real script. See [dotliquid-gotchas.md](references/dotliquid-gotchas.md).

```html
<script id="rowsJSON" type="application/json">
[{% for row in rows %}{"name":"{{ row.name | replace: '"', '"' }}"}{% unless forloop.last %},{% endunless %}{% endfor %}]
</script>
<script>
  var rows = [];
  try { rows = JSON.parse(document.getElementById('rowsJSON').textContent || '[]'); }
  catch (e) { console.warn('rows parse failed', e); }
</script>
```

### 3. Polymorphic lookup `@odata.bind` requires a suffix

Customer-type fields (target Contact OR Account) need the disambiguating suffix on the navigation property, e.g. `contoso_Applicant_contact@odata.bind` or `contoso_Applicant_account@odata.bind`. Bare `contoso_Applicant@odata.bind` returns 400. Navigation property names are also **case-sensitive** and **entity-specific** — `contoso_Account@odata.bind` works on one entity but not on another with the same field name. See [webapi-patterns.md](references/webapi-patterns.md).

### 4. Dataverse uses 4 different "names" for the same thing — and Power Pages uses different ones in different contexts

Every entity has a **Logical Name** (lowercase, e.g. `acme_customer`), a **Schema Name** (often PascalCase, e.g. `acme_Customer`), a **Display Name** (`Acme Customer`), and an **Entity Set Name** (lowercase plural, e.g. `acme_customers`). Lookup columns add a fifth: their **Navigation Property Name**, which uses the schema-name casing.

| Where you write the name | What name it expects |
|---|---|
| Web API URL: `/_api/<entityset>` | Entity Set Name (lowercase plural) |
| Web API `$select=` / `$filter=` attribute references | Logical Name (lowercase) — for lookups, the `_<attr>_value` form |
| Web API POST/PATCH payload field keys | Logical Name (lowercase) — for lookups, use `<NavigationProperty>@odata.bind` instead |
| Web API `@odata.bind` and `$expand=` | **Navigation Property Name (PascalCase)** ⚠ |
| FetchXML in Liquid (entity, attribute, link-entity, condition) | Logical Name (lowercase) — everywhere |

**The trap**: if you copy `acme_contact` from Studio's Columns view, you get the Logical Name (lowercase). If you then use it as `acme_contact@odata.bind`, you get **`'acme_contact' is not a valid navigation property`** at runtime — because the navigation property is `acme_Contact` (PascalCase, matching the schema name). The error message doesn't say "casing"; it just says "not a valid".

**Always read the Navigation Property name from `Entity.xml`** in your unpacked solution, the Maker Portal's **Relationships** view, or `/_api/$metadata`. Don't infer from the Logical Name. See [dataverse-naming.md](references/dataverse-naming.md) for the full cheat sheet, error-decoding table, and lookup recipes.

## Decision routing — which pattern fits this task?

| Task | Use | Why |
|---|---|---|
| Render a list/table on initial page load | **`{% fetchxml %}` in Liquid** ([fetchxml-patterns.md](references/fetchxml-patterns.md)) | Server-rendered, indexed by search engines, no flash of empty content |
| Filter/paginate via querystring | **`{% fetchxml %}` + `request.params`** | Works without JS, bookmarkable URLs |
| Submit a form (create/update) | **Web API POST/PATCH in custom JS** ([webapi-patterns.md](references/webapi-patterns.md)) | Form data isn't available to Liquid until next request |
| Dependent dropdown (city → branches) | **Web API GET in custom JS** with `$filter`, `$orderby` | Liquid can't react to client-side selection |
| File upload | **Web API POST to `/_api/annotations`** | Annotations entity stores attachment metadata; SharePoint integration is automatic if configured |
| Standard CRUD form with built-in validation | **`{% entityform %}`** ([entity-tags.md](references/entity-tags.md)) | Power Pages renders the form from Dataverse form metadata — minimal code |
| Multi-step wizard with branching | **`{% webform %}`** | Same as entityform but multi-step |
| Read-only list with search/sort/page | **`{% entitylist %}`** | Bound to a Dataverse view; built-in pagination and search |
| Custom UI that doesn't fit entity tags | **Hybrid: Liquid render scaffold + JS for interactivity** ([hybrid-page-idiom.md](references/hybrid-page-idiom.md)) | Most production pages |

## Liquid-side reference

- **Dataverse naming + casing rules** (the 4-name model: Logical / Schema / Display / Entity Set Name; navigation property casing; where each form is used; common-error decoding) — see [dataverse-naming.md](references/dataverse-naming.md)
- **Objects** (`user`, `page`, `website`, `request`, `weblinks`, `snippets`, `sitemarkers`, `settings`, `now`, `params`) — see [objects-reference.md](references/objects-reference.md)
- **Power Pages tags** (`{% fetchxml %}`, `{% entitylist %}`, `{% entityform %}`, `{% webform %}`, `{% editable %}`, `{% chart %}`, `{% include %}`, `{% block %}`/`{% extends %}`) — see [entity-tags.md](references/entity-tags.md)
- **DotLiquid filter table** (every supported filter with examples + Power Pages-specific extensions) — see [filters-reference.md](references/filters-reference.md)
- **DotLiquid behavioral quirks** (where it differs from Shopify Liquid) — see [dotliquid-gotchas.md](references/dotliquid-gotchas.md)
- **Troubleshooting common errors** (blank pages, 401/403/404 from `/_api/`, OData errors, sync failures) — see [troubleshooting.md](references/troubleshooting.md)

## JS-side reference

- **`safeAjax` helper** with `__RequestVerificationToken` (the canonical Power Pages anti-forgery pattern) — see [webapi-patterns.md](references/webapi-patterns.md)
- **GET with `$select` / `$filter` / `$orderby` / `$expand`**
- **POST / PATCH / DELETE** with polymorphic lookups
- **File upload via `/_api/annotations`** (5-call sequence)
- **Dependent dropdowns** keyed off another field

## Permissions, roles, and security

Power Pages enforces **two layers**:

1. **Page-level access** — via `Page.webrole` references and the Authentication settings on the page record
2. **Record-level access** — via Table Permissions YAML, scoped by Web Role

A page that loads correctly for one user but errors for another is almost always a Table Permissions miss, not a Liquid bug. See [permissions-and-roles.md](references/permissions-and-roles.md).

User-context Liquid checks:

```liquid
{% if user %}                                {# authenticated #}
{% if user.roles contains 'Authenticated Users' %}
{% if user.contact.parentcustomerid.id %}    {# user belongs to an Account #}
```

## Sync workflow

Power Pages source code lives in **Dataverse**, not your repo. The workflow is:

```
pac paportal download → edit locally → pac paportal upload → test in browser
```

Naive `pac paportal download` regenerates files non-deterministically (timestamps, GUIDs reorder, `.portalconfig/` churn). Production projects wrap it in scripts that auto-stash known noise and only commit meaningful diffs. See [sync-workflow.md](references/sync-workflow.md) for:

- The `download` → `stash noise` → `commit` → `upload` cycle
- Wrapper script pattern (the `*-down.sh` / `*-up.sh` / `*-doctor.sh` / `*-commit.sh` family)
- Portal cache hangs after bulk uploads (and how to recover)
- PAC stale manifest errors after server-side deletes
- GCC vs commercial cloud differences

## NOT supported by this skill

- **Power Pages code sites** (React/Vue/Astro SPAs) — use Microsoft's `power-pages` plugin
- **Shopify/Jekyll Liquid** — different objects, different tags, different filter behavior
- **Power Apps Canvas / Model-Driven apps** — different platform; use `canvas-apps` / `model-apps` plugins
- **Dataverse schema authoring** outside the portal — use the `dataverse` plugin (`dv-metadata`, `dv-data`, `dv-query`, `dv-solution`)
- **Power Automate Cloud Flows triggered from a portal** — Liquid embedding only; the flow itself is out of scope
