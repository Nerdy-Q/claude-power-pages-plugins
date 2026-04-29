# FetchXML in Liquid — Production Patterns

Power Pages' `{% fetchxml %}` block runs a Dataverse query at **page render time** and exposes the results to the rest of the Liquid template. Results are filtered by the **current user's Table Permissions** automatically — there's no separate auth.

## The block syntax

```liquid
{% fetchxml my_query %}
<fetch mapping="logical">
  <entity name="contact">
    <attribute name="contactid" />
    <attribute name="fullname" />
  </entity>
</fetch>
{% endfetchxml %}

{% assign rows = my_query.results.entities %}
{% for row in rows %}
  {{ row.fullname }}
{% endfor %}
```

The variable name after `fetchxml` (`my_query` here) is what you reference downstream. Results live at `<name>.results.entities` (an array). Total count for paged queries is at `<name>.results.total_record_count`.

## Pattern: count + paginate + filter (the bread-and-butter list page)

This is the canonical pattern for any "list of records with search and pagination" page. You do **two** queries — one aggregate for the total count, one paged for the visible rows.

```liquid
{% assign search = request.params['search'] | default: '' | strip %}
{% assign current_page = request.params['page'] | default: 1 | plus: 0 %}
{% if current_page < 1 %}{% assign current_page = 1 %}{% endif %}
{% assign page_size = 200 %}
{% assign search_wild = '%' | append: search | append: '%' %}

{% fetchxml count_query %}
<fetch mapping="logical" aggregate="true">
  <entity name="contact">
    <attribute name="contactid" alias="total" aggregate="count" />
    {% if search != '' %}
    <filter type="or">
      <condition attribute="fullname"        operator="like" value="{{ search_wild }}" />
      <condition attribute="emailaddress1"   operator="like" value="{{ search_wild }}" />
      <condition attribute="telephone1"      operator="like" value="{{ search_wild }}" />
    </filter>
    {% endif %}
  </entity>
</fetch>
{% endfetchxml %}

{% assign total = 0 %}
{% for item in count_query.results.entities %}
  {% if forloop.first %}{% assign total = item.total | plus: 0 %}{% endif %}
{% endfor %}

{% assign total_pages = total | minus: 1 | divided_by: page_size | plus: 1 %}
{% if total == 0 %}{% assign total_pages = 1 %}{% endif %}
{% if current_page > total_pages %}{% assign current_page = total_pages %}{% endif %}

{% fetchxml results_query %}
<fetch mapping="logical" count="{{ page_size }}" page="{{ current_page }}" returntotalrecordcount="true">
  <entity name="contact">
    <attribute name="contactid" />
    <attribute name="fullname" />
    <attribute name="companyname" />
    <attribute name="telephone1" />
    <attribute name="emailaddress1" />
    <order attribute="fullname" />
    {% if search != '' %}
    <filter type="or">
      <condition attribute="fullname"      operator="like" value="{{ search_wild }}" />
      <condition attribute="emailaddress1" operator="like" value="{{ search_wild }}" />
      <condition attribute="telephone1"    operator="like" value="{{ search_wild }}" />
    </filter>
    {% endif %}
  </entity>
</fetch>
{% endfetchxml %}

{% assign rows = results_query.results.entities %}
```

Notes:

- `mapping="logical"` is required — without it lookup attribute reads fail
- `aggregate="true"` on the count fetch; the inner `<attribute aggregate="count" />` is the standard counting pattern
- `count` and `page` on the paged fetch (1-indexed)
- `returntotalrecordcount="true"` is optional but populates `results.total_record_count`
- `request.params['x']` reads querystring values; `| default: '' | strip` is the safe coercion
- `| plus: 0` coerces strings to numbers — `request.params` values are always strings
- Search fallback uses SQL `LIKE` wildcards (`%`); for full-text use `Contains` (case-insensitive in CRM English collations)

## Pattern: link-entity for joining

Joining to a parent record, with a left join (outer):

```liquid
{% fetchxml results_query %}
<fetch mapping="logical">
  <entity name="contact">
    <attribute name="contactid" />
    <attribute name="fullname" />
    <link-entity name="account" from="accountid" to="parentcustomerid" link-type="outer" alias="parent_account">
      <attribute name="name"    alias="parent_account_name" />
      <attribute name="address1_city" alias="parent_account_city" />
    </link-entity>
  </entity>
</fetch>
{% endfetchxml %}

{% for row in results_query.results.entities %}
  {{ row.fullname }} — {{ row.parent_account_name }} ({{ row.parent_account_city }})
{% endfor %}
```

- `link-type="outer"` = LEFT JOIN. Default is `inner`.
- `alias` is **required** when you reference the joined attributes from Liquid; without it the columns get cryptic auto-aliases (`account1.name`).
- Aliased attributes appear as flat properties on the result row, not nested.

## Pattern: filter by current user

Power Pages exposes the current user as `user` (a Contact record). Common filters:

```liquid
{# Records this user owns / is the contact for #}
<filter>
  <condition attribute="contoso_applicant_contact" operator="eq" value="{{ user.contactid }}" />
</filter>

{# Records belonging to this user's parent Account #}
{% assign parent_account_id = user.parentcustomerid.id %}
<filter>
  <condition attribute="contoso_account" operator="eq" value="{{ parent_account_id }}" />
</filter>

{# Anonymous-safe — fall back to no-records when not logged in #}
{% if user %}
<filter>
  <condition attribute="contoso_applicant_contact" operator="eq" value="{{ user.contactid }}" />
</filter>
{% else %}
<filter>
  <condition attribute="contactid" operator="null" />  {# returns zero rows #}
</filter>
{% endif %}
```

## Pattern: aggregate with grouping

Sum or count grouped by a field:

```liquid
{% fetchxml summary_query %}
<fetch mapping="logical" aggregate="true">
  <entity name="invoice">
    <attribute name="invoiceid" alias="total_count" aggregate="count" />
    <attribute name="totalamount" alias="total_amount" aggregate="sum" />
    <attribute name="statecode" alias="state" groupby="true" />
  </entity>
</fetch>
{% endfetchxml %}

{% for row in summary_query.results.entities %}
  state {{ row.state }}: {{ row.total_count }} invoices, ${{ row.total_amount | round: 2 }}
{% endfor %}
```

`groupby="true"` is required on every dimension; only aggregated columns may appear without `groupby`.

## Pattern: get a single record by ID

```liquid
{% assign rec_id = request.params['id'] %}
{% fetchxml record_query %}
<fetch mapping="logical">
  <entity name="contact">
    <all-attributes />
    <filter>
      <condition attribute="contactid" operator="eq" value="{{ rec_id }}" />
    </filter>
  </entity>
</fetch>
{% endfetchxml %}

{% assign rec = record_query.results.entities | first %}
{% if rec %}
  {{ rec.fullname }}
{% else %}
  <p>Record not found.</p>
{% endif %}
```

`<all-attributes />` selects everything. Useful for detail pages where you want the full record without listing each column. **Trade-off**: heavier query and you can't alias lookups, so you read raw `_<attr>_value` columns.

## Reading lookup values

A lookup column on the result row exposes three flat properties:

| Liquid | Meaning |
|---|---|
| `{{ row.parentcustomerid.id }}` | GUID |
| `{{ row.parentcustomerid.name }}` | display name (formatted value) |
| `{{ row.parentcustomerid.logicalname }}` | target entity logical name (for polymorphic) |

**Warning**: when you use `<all-attributes />`, you instead see `_parentcustomerid_value` (the GUID only). For consistent dot-notation access, list lookup columns explicitly with `<attribute name="parentcustomerid" />` instead of `<all-attributes />`.

## Performance gotchas

- **`{% fetchxml %}` runs synchronously during render.** A page with 8 unrelated queries makes 8 sequential round-trips. If first-byte time matters, consolidate or move slow queries to client-side Web API.
- **Default page size is 50** if you don't specify `count`. Production pages should set `count` explicitly (200 is a common ceiling; 5000 is a hard server cap).
- **`fetchxml` results are NOT cached by the portal.** Every page render re-runs every query. Use Site Settings or content snippets for genuinely static lookups.
- **Aggregation queries can fail with "AggregateQueryRecordLimit exceeded"** when the underlying dataset is over ~50000 rows. Increase `aggregate.recordlimit` site setting or filter the dataset first.

## Debugging

- Add `<all-attributes />` temporarily to confirm data shape
- Use `{{ row | json }}` filter to dump a single row's JSON inline
- Use `{{ query.results.total_record_count }}` to verify pagination math
- `<filter type="or">` requires explicit `type` — bare `<filter>` is implicit AND
- A 0-row result with no error = silent permission filtering. Check Table Permissions for the calling Web Role.
