# Power Pages Web API Configuration

Deep reference for the Site Settings that control `/_api/<entity>` access. The audit checks these for misconfiguration; this file documents the full surface.

## Required site settings per table

To expose `<entity>` via `/_api/<entity>`, both of these must be present and active:

| Site Setting Name | Required | Example value | Effect |
|---|---|---|---|
| `Webapi/<entity>/Enabled` | Yes | `true` | Switches Web API on for this entity |
| `Webapi/<entity>/Fields` | Yes | `field1,field2,field3` or `*` | Whitelist of readable/writable fields |

Notes:
- The path is **case-insensitive** but conventionally PascalCase: `Webapi/<entity>/Enabled` (capital E)
- `<entity>` is the **logical name**, not display name. `contact`, not `Contact`. `contoso_consultant`, not `EnfConsultant`.
- Value comparison is case-insensitive: `true`, `True`, `TRUE` all enable the API.

## Top-level Web API settings

These control Web API behavior at the portal level, not per-entity:

| Site Setting | Effect |
|---|---|
| `Webapi/error/innererror/enabled` | If `true`, error responses include inner exception details. Useful for dev; **disable in prod** to avoid leaking stack traces. |
| `Webapi/<entity>/disablefilter` | If `true`, `$filter` queries on this entity are disabled. Limits Web API to ID-based reads. |

## Field whitelist patterns

### Wildcard

```
Webapi/<entity>/Fields = *
```

All fields readable. **Risky** for entities that may gain fields later. Avoid for tables with PII or financial data.

### Explicit comma-separated list

```
Webapi/<entity>/Fields = firstname,lastname,emailaddress1,telephone1
```

Only listed fields are exposed. Adding a new field is opt-in. **Recommended pattern** for any entity touched in production.

### Custom navigation properties

To expose a lookup or relationship field:

```
Webapi/<entity>/Fields = firstname,lastname,_parentcustomerid_value
```

Lookup values come back as `_<lookup>_value` (the GUID). To get the formatted display name, request the formatted-values header in the call (`Prefer: odata.include-annotations="*"`).

## Cross-cutting requirements

Beyond site settings, the entity also needs:

1. **A Table Permission** on this entity allowing the operation, with a Scope reachable by the calling user, attached to the calling user's Web Role.
2. **The user's Web Role assigned** in Dataverse via Contact → Web Roles.
3. **Anti-forgery token** sent on every Web API request (`__RequestVerificationToken` header from `window.shell.getTokenDeferred()`).

A 401/403/404 from `/_api/<entity>` typically means one of these is missing. The audit catches the site-setting + table-permission misalignment statically; the user/role assignment must be verified live.

## Common Webapi entity names

These are the logical names of common Power Pages-relevant entities. For your custom tables, use the `contoso_<name>`, `acme_<name>`, etc. logical name with the right prefix.

| Display | Logical | Notes |
|---|---|---|
| Contact | `contact` | Portal users; almost always needs Web API enabled with restricted fields |
| Account | `account` | Companies; same pattern as contact |
| Annotation | `annotation` | File attachments; Read+Create needed for upload flows |
| Note | (alias for annotation) | Don't confuse with the deprecated note entity |
| Activity File Attachment | `activityfileattachment` | Used for richer attachments; rare |
| Activity MIME Attachment | `activitymimeattachment` | Email attachments; rare for portals |
| System User | `systemuser` | Internal user accounts — almost never needed in portals |

## State and statuscode for site settings

Site Settings are records like any other Dataverse record. Each has:

| Field | Meaning |
|---|---|
| `statecode` | `0` = Active, `1` = Inactive |
| `statuscode` | `1` = Active, `2` = Inactive (varies by entity) |

The audit treats `statecode == 0` (or missing) as active. To disable a setting without deleting it, set `statecode: 1`.

## Troubleshooting Web API errors

| Symptom | Likely cause |
|---|---|
| 404 on `/_api/<entity>` | `Webapi/<entity>/Enabled` is missing or `false` |
| 401 on `/_api/<entity>` | User not authenticated; or the token request failed |
| 403 on `/_api/<entity>` | Anti-forgery token missing/invalid; or Table Permission denies the scope |
| 400 with field error | The field isn't in `Webapi/<entity>/Fields` whitelist |
| 400 "no such navigation property" | Wrong navigation property name in `@odata.bind` (often case-sensitivity or polymorphic suffix) |
| 500 from a custom plugin | Server-side plugin rejected the request — check error.message in the response body |

## CSP and Web API

Power Pages' Content Security Policy (Site Setting `HTTP/Content-Security-Policy`) must allow XHR to `/_api/`. The default policy includes `'self'` for `connect-src`, which covers same-origin Web API calls.

If you tighten CSP, **don't accidentally remove `'self'`** from `connect-src` — that breaks all Web API.

## Web API metadata endpoint

`/_api/$metadata` returns the OData EDMX schema for all enabled entities. Useful for:

- Discovering navigation property names (the `<NavigationProperty>` elements)
- Confirming an entity is actually reachable via Web API
- Generating client-side type definitions

The metadata endpoint requires the user to be authenticated and have at least one Web API call available. Anonymous users get 401.

## Future: Web API Preview endpoint

Power Pages also has a preview endpoint at `/api/data/v9.2/` (the standard Dataverse Web API). It's **opt-in per environment** and not used by the standard portal `safeAjax` pattern. Don't conflate the two:

| Endpoint | Auth | Use |
|---|---|---|
| `/_api/<entity>` | Portal session + anti-forgery token | Standard Power Pages Web API |
| `/api/data/v9.2/` (preview) | OAuth token (Bearer) | Opt-in advanced; rarely used |

Most portals use `/_api/` exclusively. This audit only checks `/_api/` configuration.
