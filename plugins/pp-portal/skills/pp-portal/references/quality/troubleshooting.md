# Troubleshooting — Error → Cause → Fix

Common Power Pages error messages and runtime symptoms, mapped to root causes and concrete fixes. Organized by where the error appears.

## Page renders blank

### Symptom: page returns 200 but the body is empty

**Cause #1 (most common): Base file is empty, localized file has content.**

Power Pages loads base `<Page>.webpage.copy.html` by default. Localized `content-pages/<lang>/<Page>.<lang>.webpage.copy.html` only renders when the base is empty AND the user requests a matching locale.

**Fix**: copy content from the localized file into the base file. Or: detect via the `pp-permissions-audit` skill (INFO-005).

```bash
# Quick check
SITE_DIR=...
for d in $SITE_DIR/web-pages/*/; do
  base=$(ls "$d"*.webpage.copy.html 2>/dev/null | head -1)
  loc=$(ls "$d"content-pages/*.webpage.copy.html 2>/dev/null | head -1)
  if [ -n "$base" ] && [ -n "$loc" ]; then
    bsize=$(wc -c < "$base")
    lsize=$(wc -c < "$loc")
    if [ "$bsize" -lt 50 ] && [ "$lsize" -gt 200 ]; then
      echo "BLANK: $d  base=$bsize  localized=$lsize"
    fi
  fi
done
```

**Cause #2: The page is set to require auth and the user is anonymous.**

A page set to "Specific Roles" with no role rule effectively shows nothing to anonymous visitors. Server returns a redirect to /SignIn that completes silently in some browsers.

**Fix**: check Page Permissions in Studio. Either set Authentication to "All Users" if it should be public, or verify the role rule.

### Symptom: page renders but JS doesn't work

**Cause: localized JS file populated, base JS file empty (same as the HTML version of this bug).**

**Fix**: copy `content-pages/<lang>/<Page>.<lang>.webpage.custom_javascript.js` content into the base `<Page>.webpage.custom_javascript.js`. Power Pages serves base by default.

### Symptom: page renders but CSS missing

Same root cause as JS. Check the base `<Page>.webpage.custom_css.css` file.

## 401 / 403 / 404 from `/_api/`

### `404 Not Found` from `/_api/<entity>`

**Cause**: Site Setting `Webapi/<entity>/Enabled` is missing or set to `false`.

**Fix**: Add to `sitesetting.yml`:

```yaml
- adx_name: Webapi/<entity>/Enabled
  adx_value: true
- adx_name: Webapi/<entity>/Fields
  adx_value: field1,field2,field3            # whitelist; avoid `*` for sensitive entities
```

Sync up; restart the portal cache via Admin Center if changes don't appear immediately.

### `401 Unauthorized` from `/_api/<entity>`

**Cause #1**: User is not authenticated. Anonymous users can't call this Web API endpoint.

**Fix**: Either authenticate the user (redirect to /SignIn first), or grant the Anonymous Users role a Table Permission allowing the operation (carefully — see [../data/permissions-and-roles.md](../data/permissions-and-roles.md)).

**Cause #2**: Anti-forgery token request failed (`window.shell.getTokenDeferred()` returned an error).

**Fix**: Verify the token helper is loaded — Power Pages includes it on every page automatically, but custom JS in iframes or detached contexts may not see it. The token must be refreshed for each call (don't cache).

### `403 Forbidden` from `/_api/<entity>`

**Cause #1**: `__RequestVerificationToken` header missing or stale.

**Fix**: Use the `safeAjax` pattern from [../data/webapi-patterns.md](../data/webapi-patterns.md) — never call `fetch('/_api/...')` directly without the token. Detect via `pp-permissions-audit` (WRN-004).

**Cause #2**: Table Permission denies the scope. The user has a Web Role, but no permission rule allows this operation on this entity at a scope reachable for them.

**Fix**: Audit Table Permissions for the calling Web Role + entity. Check the `adx_scope` value:

| Scope | Code | Records reachable |
|---|---|---|
| Global | `1` | All records of the entity |
| Account | `2` | Records related to user's parent Account |
| Contact | `3` | Records related to user's Contact |
| Self | `4` | The user's own Contact only |
| Parent | `5` | Records related to a parent permission |

**Cause #3**: The field referenced in `$select` / `$filter` isn't in `Webapi/<entity>/Fields` whitelist.

**Fix**: Either widen the whitelist (add the field) or remove the field from the call.

## OData errors (400 Bad Request from `/_api/`)

### `'<navigation>' is not a valid navigation property`

**Cause**: Wrong navigation property name in `@odata.bind`. Common with polymorphic (customer-type) lookups.

**Fix**:
1. Find the entity's schema XML: `dataverse-schema/<solution>/Entities/<entity>/Entity.xml`
2. Search for the lookup attribute. If `Type="customer"`, it's polymorphic.
3. Use `_contact` or `_account` suffix:

```javascript
// Wrong:
'contoso_Applicant@odata.bind': '/contacts(...)' 

// Right:
'contoso_Applicant_contact@odata.bind': '/contacts(...)' 
```

Detect via `pp-permissions-audit` (WRN-001).

Also check **case-sensitivity** — `contoso_Applicant_contact` is right; `contoso_applicant_contact` is wrong. Navigation property names are case-sensitive AND entity-specific.

### `Could not find a property named '<field>'`

**Cause**: Field name typo OR field doesn't exist on the entity.

**Fix**: Verify against schema. Common mistakes:
- Using display name instead of logical name (`Customer Name` vs `contoso_customername`)
- Wrong prefix (`acme_x` instead of `contoso_x`)
- Renamed field (entity rename history may have changed it)

### `Cannot bind value of type Edm.X to type Edm.Y`

**Cause**: Type mismatch — sending a string when a decimal is expected, etc.

**Fix**: Check the schema for the field's `Type`:

| Type | What to send |
|---|---|
| `Edm.String` | string |
| `Edm.Int32` | integer (no quotes) |
| `Edm.Decimal` | number (no quotes) |
| `Edm.Boolean` | `true` / `false` |
| `Edm.DateTimeOffset` | ISO 8601 string |
| `Edm.Guid` | GUID string (no quotes in `$filter`) |
| `Edm.Binary` | base64 string |

Watch for fields whose Edm type changed between environments (NQ vs GCC schema divergence).

## DotLiquid errors

### `JSON.parse: unexpected character` in client-side code

**Cause**: DotLiquid JSON serialization broke the JSON. Usually `replace: '"', '\\"'` produced 3 chars instead of 2.

**Fix**: Use Unicode escape and `<script type="application/json">`:

```liquid
<script id="data" type="application/json">
[{% for row in rows %}{
  "name": "{{ row.name | replace: '"', '"' }}"
}{% unless forloop.last %},{% endunless %}{% endfor %}]
</script>
<script>
  var data = JSON.parse(document.getElementById('data').textContent || '[]');
</script>
```

Detect via `pp-permissions-audit` (INFO-007).

### `Liquid error: Invalid filter '<name>'`

**Cause**: Using a filter that doesn't exist in DotLiquid (often a Shopify-only filter like `where_exp`, `pluralize`, `time_ago_in_words`).

**Fix**: See [../language/filters.md](../language/filters.md) "Filters that DON'T exist" section for alternatives.

### `Liquid error: undefined method 'fetchxml'`

**Cause**: Tried to use `{% fetchxml %}` outside a Power Pages context (e.g., in a snippet that isn't being rendered as Liquid).

**Fix**: Verify the Content Snippet has `liquid: true` set, OR use `{% editable snippets['Name'] type: 'html', liquid: true %}` when including it.

## Sync workflow errors

### `pac paportal upload` fails with "PowerPageComponentDeletePlugin: not found"

**Cause**: A record was deleted on the server but the local YAML still exists. Cosmetic — upload still succeeds for valid files.

**Fix**: Delete the orphaned local YAML files and commit. Or run `./*-doctor.sh` to audit.

### `pac paportal download` produces nested `site---site/site---site/` directory

**Cause**: Ran `pac paportal download` from inside the site folder.

**Fix**: Always `cd $(git rev-parse --show-toplevel)` before download. The `pp-sync` skill enforces this.

### Portal returns 503 / hangs after upload

**Cause**: Bulk upload (>50 files at once) jammed the cache.

**Fix**:
1. Power Platform Admin Center → site → Restart
2. Wait 30-60 seconds
3. Verify with browser
4. Future uploads: do incrementally (1-3 files at a time, verify between)

See [pp-sync sync workflow](../../../../pp-sync/skills/pp-sync/references/safety-checks.md) for full recovery procedure.

## Studio preview shows blank or errors

### `Studio preview fails for some pages`

**Cause**: Studio preview has stricter rendering than the live portal. Pages with complex Liquid (heavy `{% fetchxml %}`, multi-step forms, JS apps) often won't preview.

**Fix**: Test on the actual portal URL instead of relying on Studio preview. Studio preview is best-effort for simple pages.

## Liquid object errors

### `{{ user.something }}` returns nil for authenticated users

**Cause**: The Contact field isn't exposed to the portal context — Power Pages portals only expose a subset of Contact fields by default.

**Fix**: Add the field to the portal's exposed fields via Power Pages Studio (Site Settings → Authentication → user fields), OR use a FetchXML query against the Contact directly (if the user's Web Role has Read on Contact).

### `{% if user.roles contains 'X' %}` always false

**Cause #1**: The role isn't actually assigned to this Contact in Dataverse. Open the Contact record in Maker → Web Roles tab → verify the role is listed.

**Cause #2**: The role name has different casing than what Liquid is checking. `'State Employee'` vs `'state employee'` are different strings.

**Fix**: Confirm exact casing from the Web Role record, OR normalize:

```liquid
{% assign user_roles_lower = user.roles | downcase %}
{% if user_roles_lower contains 'state employee' %}…{% endif %}
```

(Note: this only works if `user.roles` is a string, not an array of role names. Test in your env.)

### `sitemarkers['Name']` returns nil

**Cause**: No Sitemarker record exists with this name.

**Fix**: Either create the Sitemarker (Maker Portal → Site Markers → New) or fix the typo. Detect via `pp-permissions-audit` (WRN-003). Always defensive-default:

```liquid
{% assign url = sitemarkers['Name'].url | default: '/fallback-path' %}
```

## Authentication and login flow errors

### `Browser shows /SignIn loop` after login

**Cause**: Identity provider configured but the return URL is malformed, or the user was sent to a page they can't access.

**Fix**: Check `Authentication/Registration/LoginButtonAuthenticationType` and the return URL handling. Common: a custom `/post-signin` page that redirects to a role-restricted page the user can't reach.

### `Anti-forgery token validation failed` in browser console

**Cause**: The token Page Pages issued is stale or for a different session.

**Fix**: Refresh the page once. If it persists, the user's session may have expired — sign them out and back in.

## When you can't figure it out

1. Run `pp-permissions-audit` to catch static-analysis findings
2. Open the browser DevTools Network tab and look at the failing request's status + response body
3. Check Power Platform Admin Center → site → Diagnostics → recent errors
4. Read the **first** non-trivial line of the error stack — DotLiquid stacks often have noise above the real cause
5. If totally stuck: temporarily set Site Setting `Webapi/error/innererror/enabled = true` to get richer error responses (disable in prod after debugging)
