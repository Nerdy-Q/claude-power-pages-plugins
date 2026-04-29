# Power Pages Entity Tags

Power Pages ships three high-level Liquid tags that render Dataverse-bound UI from configured metadata: `{% entitylist %}`, `{% entityform %}`, and `{% webform %}`. They trade flexibility for development speed — you configure them via Power Pages Studio (the no-code Maker Portal), then drop a one-liner in Liquid to render.

## When to use which

| Tag | What it renders | Configure via | Use when |
|---|---|---|---|
| `{% entitylist %}` | A read-only list bound to a Dataverse view, with built-in pagination, search, and column sort | Power Pages Studio → Lists | List page where Dataverse view metadata already does what you need |
| `{% entityform %}` | A single-step CRUD form bound to a Dataverse main form | Power Pages Studio → Forms | Standard create/edit page that mirrors a back-office form |
| `{% webform %}` | A multi-step wizard with conditional branching, between-step events, attachments | Power Pages Studio → Multistep Forms | Complex application or wizard with steps |

Choose **custom hybrid pages** ([hybrid-page-idiom.md](hybrid-page-idiom.md)) when entity tags can't express your UI — non-Dataverse layouts, dependent dropdowns, custom validation flows, or branded UI that doesn't fit the entity-form chrome.

## entitylist

```liquid
{% entitylist name:"Active Contacts" key:"contactid" %}
  {% if entitylist.records.size > 0 %}
    <table class="table">
      <thead><tr>
        {% for col in entitylist.columns %}<th>{{ col.label | escape }}</th>{% endfor %}
      </tr></thead>
      <tbody>
        {% for row in entitylist.records %}
          <tr>
            {% for col in entitylist.columns %}
              <td>{{ row[col.attribute] | escape }}</td>
            {% endfor %}
          </tr>
        {% endfor %}
      </tbody>
    </table>
  {% else %}
    <p>No records.</p>
  {% endif %}
{% endentitylist %}
```

The `name:` attribute matches the Entity List record name in Studio. The list config (entity, view, columns, page size, search fields, default filters) lives in Dataverse — Liquid only consumes it.

`entitylist.records` honors **Table Permissions** automatically. Anonymous users see anonymous-allowed rows only; authenticated users see what their Web Role allows.

## entityform

```liquid
{% entityform name:"Contact Edit Form" %}
```

That's the entire snippet. The form's entity, mode (Insert / Edit / ReadOnly), Dataverse form, success message, and post-submit redirect all live in the Entity Form record in Studio.

To pre-fill values via querystring, configure **URL parameters** on the Entity Form record. Power Pages will read `?firstname=Jane` and pre-populate the matching field automatically — you don't read it in Liquid.

To run client-side JavaScript on form events:

```liquid
{% entityform name:"Contact Edit Form" %}

<script>
$(document).ready(function () {
  // Power Pages exposes its form events via jQuery on $(document)
  $(document).on('click', '#InsertButton', function () {
    // pre-submit hook
  });

  // Field-level validation
  if (typeof webFormClientValidate === 'function') {
    var oldValidate = webFormClientValidate;
    webFormClientValidate = function () {
      if (!oldValidate.apply(this, arguments)) return false;
      // your custom validation here
      return true;
    };
  }
});
</script>
```

## webform

```liquid
{% webform name:"Application Wizard" %}
```

Same one-liner. Multi-step Forms in Studio define steps, conditions for moving between steps, and per-step JS. The wizard handles state persistence between steps automatically (saves a partial record on each Next).

To handle step transitions:

```javascript
$(document).on('webform-step-change', function (event, data) {
  // data.fromStep, data.toStep
});

$(document).on('webform-pre-submit', function () {
  // pre-submit hook for last step
});
```

## Other useful tags

### `{% editable %}`

Make a content snippet inline-editable for users with the right Web Role:

```liquid
{% editable snippets['Footer Disclaimer'] type: 'html' %}
{% editable page 'adx_copy' type: 'html', liquid: true %}
```

`liquid: true` means the snippet body is itself parsed as Liquid before rendering — so admins can drop expressions into editable content. Use sparingly; security implication is that editor users can run Liquid.

### `{% chart %}`

Renders a Dataverse chart by name:

```liquid
{% chart id:"chart-guid-here" viewid:"view-guid-here" %}
```

Chart and view IDs are GUIDs — get them from the Maker Portal URL when you open the chart designer. Less commonly used than `entitylist`/`entityform` because charts have limited customization.

### `{% include %}`

Include a Web Template by name:

```liquid
{% include 'Page Header' %}
{% include 'Customer Card' with customer: row %}
```

Web Templates are reusable Liquid components stored in the `web-templates/` directory. Pass parameters with `with name: value`.

### `{% block %}` and `{% extends %}`

Power Pages supports template inheritance via Page Templates. A Page Template defines `{% block name %}{% endblock %}` regions; a Web Page selects a Page Template via metadata, and the page's `webpage.copy.html` content fills the blocks.

```liquid
{# In a Page Template (web-template) #}
<!DOCTYPE html>
<html>
<head><title>{% block title %}Site Name{% endblock %}</title></head>
<body>
  <header>{% include 'Site Header' %}</header>
  <main>{% block content %}{% endblock %}</main>
  <footer>{% include 'Site Footer' %}</footer>
</body>
</html>
```

```liquid
{# In a webpage.copy.html #}
{% extends 'Site Layout' %}
{% block title %}Customers — Site Name{% endblock %}
{% block content %}
  <h1>Customers</h1>
  ...
{% endblock %}
```

### `{% fetchxml %}`

Covered in detail in [fetchxml-patterns.md](fetchxml-patterns.md).

## Tag attribute syntax

Most Power Pages tags accept attributes after the tag name:

```liquid
{% entitylist name:"Active Contacts" key:"contactid" page:"2" %}
```

Attribute values can be Liquid expressions:

```liquid
{% entitylist name:"Active Contacts" page:request.params['page'] %}
```

This is **non-standard Liquid** — generic Liquid uses comma-separated attributes. Power Pages' DotLiquid extension allows the colon-prefixed form for entity tags only.

## Tag combinations and gotchas

- **`{% entityform %}` and `{% webform %}` cannot coexist on the same page.** Power Pages renders only one form per page. If you need two, split into two pages.
- **`{% entitylist %}` honors Table Permissions automatically.** No additional security wiring is needed — but a 0-row result with a populated Dataverse view often means the calling Web Role lacks Read scope on the underlying table.
- **Entity tag styling is locked to Power Pages' generated chrome** — you can override with CSS, but adding/removing fields requires editing the underlying Dataverse form/view, not the Liquid.
- **Anonymous users can see `{% entityform %}`** if the form's auth setting allows it, but submission requires either authentication or a captcha challenge configured on the form.
