# Power Pages Permissions and Roles

Power Pages enforces access on **two layers**, both of which must allow an action for it to succeed:

1. **Page-level access** — controls who can reach a URL
2. **Record-level access** — controls which Dataverse records that user can read/write/create/delete

A page that loads correctly for one user but errors for another is almost always a **record-level** miss (Table Permissions), not a page-level one. Conversely, a page that 404s for everyone is almost always a page-level miss (sitemap or webrole).

## Web Roles

Web Roles are the unit of authorization. Every authenticated user has zero or more Web Roles. Anonymous users effectively have a single implicit role: "Anonymous Users".

Web Roles are stored as YAML in `web-roles/`:

```yaml
# web-roles/state-employee/state-employee.webrole.yml
adx_websiteid: <site-guid>
adx_name: State Employee
adx_authenticatedusersrole: false                   # NOT the implicit role
adx_anonymoususersrole: false                       # NOT the anonymous role
```

Two implicit roles every site has:

| Role | When applied |
|---|---|
| Authenticated Users | Every signed-in user |
| Anonymous Users | Every visitor without a session |

**The most common mistake**: assuming a role isn't honored. It is — but you must explicitly assign it to the calling Contact via the `adx_contact_webrole` link table. New Contacts default to having **only** the implicit Authenticated Users role until you assign more.

## Page-level access

Two ways to control which roles can reach a page:

### A) Web Page → Web Role association

In Studio: Page properties → Access permissions → Web Roles. In YAML: a row in `adx_webpageaccesscontrolrule_webrole` linking the access rule to allowed roles.

### B) Authentication setting on the page

In Studio: Page properties → Permissions → Authentication. In YAML: `adx_publishingstateid` and `adx_requireregistration`.

Three common configurations:

| Page audience | Setting |
|---|---|
| Anonymous + authenticated | Authentication = "All Users", no role rule |
| Authenticated only | Authentication = "Authenticated Users", no role rule |
| Specific roles only | Authentication = "Specific Roles", with role rule |

## Record-level access (Table Permissions)

Table Permissions YAML lives in `table-permissions/`:

```yaml
# table-permissions/contractors-read-own/contractors-read-own.tablepermissions.yml
adx_websiteid:        <site-guid>
adx_name:             Contractors - Read Own
adx_entityname:       contoso_contactor
adx_scope:            3                              # Contact (see scopes table)
adx_read:             true
adx_create:           false
adx_write:            true                           # update permission
adx_delete:           false
adx_append:           true
adx_appendto:         false
adx_webroles:
  - <web-role-guid-of-Contractor>
```

### Scopes

The `adx_scope` field is the single most important one. It defines **which records this rule applies to** for the calling user:

| Scope | Code | Records | Use when |
|---|---|---|---|
| Global | `1` | All records of the entity | Admin / state-employee patterns |
| Account | `2` | Records related to the user's parent Account | Multi-user company access |
| Contact | `3` | Records related to the user's Contact (typically owned by) | Per-user access |
| Self | `4` | The user's own Contact record only | Profile pages |
| Parent | `5` | Records related to a parent permission | Cascading hierarchies |

The "related to" definition uses the `adx_entityreference` field on the Table Permission to specify the lookup column on the entity that ties records back to the user/account.

### Cascading via Parent scope

For a deep hierarchy — e.g., Account → Project → WorkOrder where a user has Account-scope access to Projects but should also see the WorkOrders under those Projects — create:

1. **Permission A**: Account-scope on `contoso_project`, lookup = `contoso_account`
2. **Permission B**: Parent-scope on `contoso_workorder`, parent = Permission A, lookup = `contoso_project` (the lookup from WorkOrder back to Project)

Permission B inherits Permission A's qualifying record set.

### Multiple permissions on the same entity for the same role

A user can have **multiple** Table Permissions on the same entity through the same role. The portal **OR**s them — if any rule allows the operation on the record, it's allowed. So you can build complex access patterns by stacking simple rules:

- Permission 1: Read records where `contoso_assigned_consultant = user.contactid`
- Permission 2: Read records where `_contoso_account_value = user.parentcustomerid.id`

A consultant whose company is also assigned sees both sets.

## Checking permissions in Liquid

Inline auth checks for UI:

```liquid
{# Has a specific role? #}
{% if user | has_role: 'State Employee' %}
  …admin button…
{% endif %}

{# Authenticated at all? #}
{% if user %}
  …signed-in UI…
{% else %}
  …anonymous UI…
{% endif %}

{# Multiple roles via array #}
{% if user.roles contains 'State Employee' or user.roles contains 'Contractor' %}
  …
{% endif %}

{# User has a parent Account? #}
{% if user.parentcustomerid.id %}
  …company-mode UI…
{% endif %}
```

**These are UI checks, not security**. They control what the user *sees* — but the actual data access is enforced by Table Permissions on the server. Always rely on Table Permissions for security; use Liquid checks only to hide UI elements from users who couldn't act on them anyway.

## Web API access

For the Power Pages Web API (`/_api/<entity>`) to work for a given table, **all four** of these must be true:

| Requirement | Where configured |
|---|---|
| Site Setting `Webapi/<entity>/enabled = true` | `site-settings/` YAML |
| Site Setting `Webapi/<entity>/fields = *` (or specific fields) | `site-settings/` YAML |
| Table Permission allowing the operation, with a Scope reachable by the user | `table-permissions/` YAML |
| Web Role assigned to the calling Contact | Studio (Contacts → Roles) or `adx_contact_webrole` |

Common failure modes:

- 404: site setting missing
- 401 (HTML): user not authenticated and table requires auth
- 403 (HTML): anti-forgery token missing or invalid; or no table permission grants this scope
- 400 with "no field 'contoso_x'": field not in the `Webapi/<entity>/fields` whitelist

The `audit-permissions` agent in Microsoft's `power-pages` plugin can scan a portal's permissions configuration and flag misalignments. Not a substitute for understanding the model, but useful for quick triage.

## Anonymous users and CSRF

Anonymous users **can** call `/_api/...` endpoints **if** the Web API site settings allow it AND the calling Web Role (Anonymous Users by default) has a Table Permission allowing the operation.

Anonymous Web API calls still require the `__RequestVerificationToken`. The token is per-session — for anonymous, the session is established on first portal page load.

Anonymous create patterns (e.g., a public contact form):

```yaml
# table-permissions/anonymous-create-contact/anonymous-create-contact.tablepermissions.yml
adx_entityname: contact
adx_scope:      1                                    # Global
adx_read:       false
adx_create:     true                                 # only Create
adx_write:      false
adx_delete:     false
adx_webroles:
  - <Anonymous Users role guid>
```

Pair with Site Settings `Webapi/contact/enabled=true` and `Webapi/contact/fields=firstname,lastname,emailaddress1,…`. **Restrict the field list** for anonymous — never `*` on a security-sensitive table.

## Field-level security

Power Pages does not have its own field-level security. It honors **Dataverse field-level security profiles**, which are tied to **System Users** (back-office), not Web Roles or Contacts. So:

- A field locked behind FLS in Dataverse is invisible to ALL portal users (because the portal app user has no FLS profile).
- To expose an FLS field through the portal, you must either disable FLS on the field or grant the portal app user the FLS profile.

To restrict portal-only field access, use the `Webapi/<entity>/fields` site setting (whitelist) instead of FLS.

## Page-level security via `adx_webrole`

For finer page-level rules than the page Authentication setting allows:

```yaml
# Page access permission rule
adx_name: Contractor pages
adx_webroles:
  - <Contractor role guid>
adx_publishingstateid: …
```

Linked to specific Web Pages via `adx_webpage_accesscontrolrule`. This lets you say "these 12 pages are visible only to Contractors" without setting Authentication on each page individually.

## Debugging "no records appear" symptoms

Walk this list:

1. **Liquid `{{ user.roles }}` shows the expected roles?** If not, the user isn't assigned the role. Fix in Studio (Contacts → Roles).
2. **Run the same FetchXML in the Maker Portal as a System Admin** — does it return rows? If yes, the data exists and the issue is permissions.
3. **Run via Web API as the user** — does it return 401/403/404? Identifies which permission layer is blocking.
4. **Inspect the Table Permissions for the calling role**:
   - Is there a permission on this entity with Read=true?
   - Is the scope reachable for this user (Global / Account / Contact)?
   - For non-Global scopes, is `adx_entityreference` set to the correct lookup column?
5. **Check site settings for Web API**: `Webapi/<entity>/enabled`, `Webapi/<entity>/fields`.
6. **Look for stacked permissions** — additional rules may be needed to cover the user's intended record set.

## Two-tenant deployment workflow (auth profiles)

When the same portal exists in your dev env (your tenant) and a client env (their tenant), keep:

- **One PAC profile per env** — different tenant IDs, different sign-in accounts
- **One git branch per env** — `main` for dev, `client-dev` for the client env
- Apply changes from `main` to `client-dev` via `git cherry-pick`, then sync up to client
- Anonymous-Users role and System Admin role exist independently per env — exporting Table Permissions from dev and importing to client requires re-mapping role GUIDs (the role is the same logical role; the GUID is different per env)

The unmanaged solution export/import will preserve the YAML structure but break role-GUID references. After import, re-link Table Permissions to the client env's roles in Studio.
