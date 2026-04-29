# Power Pages Web API in Custom JS

The Power Pages Web API is exposed at `/_api/<entityset>` on every portal. Custom JavaScript can call it for client-side reads, writes, and file uploads. Auth is handled by the portal session — every request must include the `__RequestVerificationToken` header (anti-CSRF).

## Prerequisites

For a table to be reachable via Web API, **two Site Settings must exist** (per table per portal):

| Site Setting | Value |
|---|---|
| `Webapi/<schema>/enabled` | `true` |
| `Webapi/<schema>/fields` | `*` (all fields) or comma-separated logical names |

Replace `<schema>` with the table's schema name (e.g., `contact`, `contoso_AbandonedTankApplication`). Schema names are **case-sensitive**.

Plus: **Table Permissions** for the calling Web Role must allow the operation (Read/Write/Create/Delete) and Scope (Global / Account / Contact / Self / Parent).

A 401 from `/_api/...` almost always means: missing site setting, missing table permission, missing field in the `fields` list, or anonymous user trying to call an authenticated table. The plugin's `audit-permissions` agent (in Microsoft's `power-pages` plugin) can diagnose this.

## The safeAjax helper (canonical pattern)

Every Power Pages portal needs a wrapper around the browser fetch API that handles the anti-forgery token. Drop this in a custom-javascript file:

```javascript
function getToken() {
  if (!window.shell || typeof window.shell.getTokenDeferred !== 'function') {
    return Promise.reject(new Error('Power Pages shell token helper is unavailable on this page.'));
  }
  return new Promise(function (resolve, reject) {
    window.shell.getTokenDeferred().done(resolve).fail(function () {
      reject(new Error('Could not acquire a Power Pages Web API token.'));
    });
  });
}

function safeAjax(options) {
  return getToken().then(function (token) {
    var headers = Object.assign(
      {
        '__RequestVerificationToken': token,
        'Accept':                     'application/json',
        'Content-Type':               'application/json',
        'OData-MaxVersion':           '4.0',
        'OData-Version':              '4.0'
      },
      options.headers || {}
    );

    return fetch(options.url, {
      method:      options.method || 'GET',
      headers:     headers,
      body:        options.body,
      credentials: 'same-origin'
    }).then(function (response) {
      if (!response.ok) {
        return response.text().then(function (text) {
          throw new Error(text || ('Request failed with status ' + response.status + '.'));
        });
      }
      // GET returns JSON; POST/PATCH/DELETE may return empty
      var ct = response.headers.get('content-type') || '';
      return ct.indexOf('application/json') >= 0 ? response.json() : response;
    });
  });
}
```

Why this helper exists:

- `window.shell.getTokenDeferred()` is the official way to obtain the anti-forgery token. It returns a jQuery `Deferred`, hence the `.done().fail()` shape — wrapping it in a native Promise smooths the rest of the code.
- `credentials: 'same-origin'` is required so the portal session cookie travels with the request.
- OData v4 headers are required; v3 is rejected.
- Reading `.text()` on error rather than `.json()` because Web API errors are sometimes returned as HTML (auth wall) or plain text (CSRF rejection).

## GET — read with $select / $filter / $orderby / $expand

```javascript
safeAjax({
  url: '/_api/contoso_officebranches'
     + '?$select=contoso_officebranchid,contoso_officebranch,contoso_address,contoso_city,contoso_state,contoso_zip'
     + '&$filter=_contoso_account_value eq ' + companyId
     + '&$orderby=contoso_officebranch'
})
.then(function (data) {
  // GET responses always wrap rows in `value` array
  data.value.forEach(function (office) {
    renderRow(office);
  });
});
```

Notes:

- **Lookup filters use the `_<attr>_value` form**, not the bare attribute name. `_contoso_account_value eq <guid>` works; `contoso_account eq <guid>` doesn't.
- `<guid>` in `$filter` is **bare** — no quotes, no curly braces. `_contoso_account_value eq d8a3...e4` is correct.
- `$select` is strongly recommended — without it you get every field on the entity, slowing the response.
- For paged responses, the response includes `@odata.nextLink` when there are more rows.

To request formatted (display) values for choice fields and lookups, add this header:

```javascript
safeAjax({
  url: '/_api/contacts?$select=fullname,gendercode',
  headers: { 'Prefer': 'odata.include-annotations="*"' }
})
.then(function (data) {
  data.value.forEach(function (row) {
    console.log(row.fullname, row['gendercode@OData.Community.Display.V1.FormattedValue']);
  });
});
```

## POST — create a record

```javascript
var payload = {
  firstname:       'Jane',
  lastname:        'Doe',
  emailaddress1:   'jane@example.com',
  telephone1:      '555-0100'
};

safeAjax({
  url:    '/_api/contacts',
  method: 'POST',
  body:   JSON.stringify(payload)
})
.then(function (response) {
  // Power Pages POST responses include the new GUID either:
  //  (a) in the OData-EntityId response header, or
  //  (b) as the response body when Prefer: return=representation is set
  var entityId = getEntityId(response);
  window.location.href = '/customer-details?id=' + encodeURIComponent(entityId) + '&type=contact';
});

function getEntityId(response) {
  var headerVal = response.headers && response.headers.get && response.headers.get('OData-EntityId');
  if (!headerVal) return null;
  var match = /\(([^)]+)\)/.exec(headerVal);
  return match ? match[1] : null;
}
```

Add `Prefer: return=representation` if you need the full created record back:

```javascript
safeAjax({
  url:     '/_api/contacts',
  method:  'POST',
  body:    JSON.stringify(payload),
  headers: { 'Prefer': 'return=representation' }
})
.then(function (created) { /* `created` is the full record */ });
```

## POST with lookup binding — @odata.bind

To set a lookup, use the `<navigation_property>@odata.bind` syntax with the **entityset URI**:

```javascript
var payload = {
  contoso_officebranch:                'Main Office',
  'contoso_Account@odata.bind':        '/accounts(' + accountId + ')'
};
```

### Polymorphic (customer-type) lookups need a suffix

Customer-type fields (target Contact OR Account) require the disambiguating navigation property:

```javascript
// Setting the applicant when they're a Contact:
payload['contoso_Applicant_contact@odata.bind'] = '/contacts(' + contactId + ')';

// Setting the applicant when they're an Account:
payload['contoso_Applicant_account@odata.bind'] = '/accounts(' + accountId + ')';

// WRONG — bare `contoso_Applicant@odata.bind` returns 400 Bad Request
```

### Navigation property names are case-sensitive AND entity-specific

The same field name can map to different navigation properties on different entities:

| Entity | Lookup field | Navigation property | `@odata.bind` |
|---|---|---|---|
| Invoice | Account | `contoso_Account` | `contoso_Account@odata.bind` |
| OfficeBranch | Account | `contoso_Account` | `contoso_Account@odata.bind` |
| Contractor | Account | `contoso_CompanyAccount` | `contoso_CompanyAccount@odata.bind` |
| InsurancePolicy | Account | `contoso_CompanyAccount` | `contoso_CompanyAccount@odata.bind` |

**Always verify against the entity's schema XML** before assuming. A 400 with `'<name>' is not a valid navigation property` means you guessed wrong — check the actual schema export.

## PATCH — update a record

```javascript
safeAjax({
  url:    '/_api/contacts(' + contactId + ')',
  method: 'PATCH',
  body:   JSON.stringify({ telephone1: '555-0200' })
});
```

PATCH returns 204 No Content on success. To get the updated record back, add `Prefer: return=representation`.

## DELETE

```javascript
safeAjax({
  url:    '/_api/contacts(' + contactId + ')',
  method: 'DELETE'
});
```

Returns 204 No Content. The user's Web Role must have Delete permission scoped appropriately.

## File upload via /_api/annotations

Annotations (notes) are how Power Pages handles file attachments. The pattern is a 3-step sequence: read file as base64, POST the annotation, optionally link to a parent record.

```javascript
function fileToBase64(file) {
  return new Promise(function (resolve, reject) {
    var reader = new FileReader();
    reader.onload  = function () { resolve(reader.result.split(',')[1]); };  // strip data:... prefix
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

function uploadAttachment(file, parentRecordEntitySet, parentRecordId) {
  return fileToBase64(file).then(function (base64) {
    var payload = {
      filename:                       file.name,
      mimetype:                       file.type || 'application/octet-stream',
      documentbody:                   base64,
      subject:                        file.name,
      'objectid_<entity>@odata.bind': '/' + parentRecordEntitySet + '(' + parentRecordId + ')'
    };
    return safeAjax({
      url:    '/_api/annotations',
      method: 'POST',
      body:   JSON.stringify(payload)
    });
  });
}
```

Notes:

- **`documentbody` is base64-encoded file content** with the `data:...;base64,` prefix stripped
- **`objectid_<entity>@odata.bind`** is the polymorphic lookup that links the note to its parent — the suffix is the entity logical name (`objectid_contact`, `objectid_account`, `objectid_<custom>`)
- The Annotation table needs `Webapi/annotation/enabled = true` and Table Permissions allowing Create
- If SharePoint integration is enabled on the env, attachments over a configurable size threshold get redirected to SharePoint automatically — no code change

## Dependent dropdown pattern

Country to State to City, or Account to Branches:

```javascript
// In the page, listen on the parent select:
document.getElementById('companySelect').addEventListener('change', function (e) {
  var companyId = e.target.value;
  if (!companyId) return clearBranches();

  showBranchLoader();
  safeAjax({
    url: '/_api/contoso_officebranches'
       + '?$select=contoso_officebranchid,contoso_officebranch'
       + '&$filter=_contoso_account_value eq ' + companyId
       + '&$orderby=contoso_officebranch'
  })
  .then(function (data) {
    var branchSelect = document.getElementById('branchSelect');
    branchSelect.innerHTML = '<option value="">-- choose branch --</option>';
    data.value.forEach(function (b) {
      var opt = document.createElement('option');
      opt.value = b.contoso_officebranchid;
      opt.textContent = b.contoso_officebranch;
      branchSelect.appendChild(opt);
    });
    hideBranchLoader();
  })
  .catch(function (err) {
    hideBranchLoader();
    showError('Could not load branches: ' + err.message);
  });
});
```

## Error decoding

Power Pages Web API errors come back as OData JSON when the request reaches Dataverse, but as HTML or plain text when the portal layer rejects the request first:

| Error appearance | Likely cause |
|---|---|
| `401 Unauthorized` HTML | User not authenticated; page allows anonymous but table doesn't |
| `403 Forbidden` HTML | Anti-forgery token missing or invalid; or Table Permissions deny scope |
| `404 Not Found` HTML | Site Setting `Webapi/<entity>/enabled` is missing or false |
| `400 Bad Request` JSON | OData payload error — usually navigation property name, field name, or polymorphic lookup |
| `412 Precondition Failed` | Etag mismatch on PATCH (record changed since you read it) |
| `500 Internal Server Error` JSON | Plugin failure or business rule rejection — read the `error.message` field |

For 400, parse the JSON body for the human-readable message:

```javascript
.catch(function (err) {
  try {
    var parsed = JSON.parse(err.message);
    showError(parsed.error && parsed.error.message || err.message);
  } catch (e) {
    showError(err.message);
  }
});
```
