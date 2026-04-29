# Power Pages Liquid Objects Reference

Power Pages exposes a set of global Liquid objects available in any web template, web page copy, content snippet, or page template. These are NOT the same as Shopify's globals (`product`, `cart`, `section`, etc.) — Power Pages has its own.

## user

The currently authenticated user's Contact record. `nil` for anonymous visitors.

| Property | Meaning |
|---|---|
| `user.id` | Contact GUID |
| `user.contactid` | Contact GUID (alias) |
| `user.fullname` | Full display name |
| `user.firstname` / `user.lastname` | Name components |
| `user.emailaddress1` | Primary email |
| `user.parentcustomerid` | Lookup to parent Account (`.id`, `.name`, `.logicalname`) |
| `user.roles` | Array of Web Role names the user has |
| `user.roles_string` | Comma-separated Web Role names (legacy) |
| `user.<custom_attr>` | Any other Contact attribute the portal exposes |

Common patterns:

```liquid
{% if user %}                                      Hello {{ user.firstname }}
{% else %}                                         <a href="/SignIn">Sign in</a>
{% endif %}

{% if user.roles contains 'State Employee' %}      State-only block
{% endif %}

{% assign account_id = user.parentcustomerid.id %} GUID of user's Account
```

`user` reads honor field-level security on the Contact entity. Custom attributes only work if the portal has read access via the user's Web Role.

## page

The currently rendering Web Page record.

| Property | Meaning |
|---|---|
| `page.id` | Web Page GUID |
| `page.title` | Page title |
| `page.url` | Page URL (relative) |
| `page.adx_copy` | The page's HTML body (raw) |
| `page.adx_summary` | Summary content |
| `page.children` | Array of child Web Page records |
| `page.parent` | Parent Web Page (`nil` if root) |
| `page.<custom_attr>` | Any custom attribute on the Web Page entity |

Used heavily in page templates:

```liquid
<title>{{ page.title }} — {{ website.name }}</title>
<h1>{{ page.title }}</h1>
{{ page.adx_copy }}
```

## website

The current site (Power Pages portal record).

| Property | Meaning |
|---|---|
| `website.id` | Website GUID |
| `website.name` | Site display name |
| `website.<custom_attr>` | Any attribute on the Website entity |

## request

The HTTP request context.

| Property | Meaning |
|---|---|
| `request.url` | Full request URL |
| `request.path` | Path portion (e.g., `/customers/`) |
| `request.path_and_query` | Path + querystring |
| `request.params['name']` | A single querystring or form value |
| `request.params` | Hash-like access to all querystring + form values |

Always coerce `request.params` carefully — values are strings, possibly nil:

```liquid
{% assign search       = request.params['search']  | default: '' | strip %}
{% assign current_page = request.params['page']    | default: 1 | plus: 0 %}
```

## now

Current date/time (server time).

```liquid
{{ now }}                                          ISO timestamp
{{ now | date: '%Y-%m-%d' }}                       2026-04-28
{{ now | date: '%m/%d/%Y' }}                       04/28/2026
{{ now | date: '%B %-d, %Y' }}                     April 28, 2026
```

## sitemarkers

Hash of named URL anchors. Sitemarker records map a logical name to a Web Page, so Liquid code can refer to pages by intent without hardcoding URLs.

```liquid
{% assign customers_url = sitemarkers['Customers'].url | default: '/customers' %}
<a href="{{ customers_url }}">All customers</a>
```

| Property | Meaning |
|---|---|
| `sitemarkers['Name'].url` | Resolved page URL |
| `sitemarkers['Name'].title` | Target page title |
| `sitemarkers['Name'].id` | Target page GUID |

The `| default: '/customers'` fallback is defensive — if a sitemarker is renamed in Studio, the page won't 404.

## snippets

Hash of Content Snippet values by name. Snippets are editable content blocks for non-developers.

```liquid
{{ snippets['Footer Disclaimer'] }}
{% editable snippets['Footer Disclaimer'] type: 'html' %}      makes it inline-editable
```

Snippets are localizable — Power Pages picks the right language version based on the user's locale automatically.

## weblinks

Hash of Web Link Sets. Used for navigation menus, footer links, anything with a curated link list.

```liquid
{% assign main_menu = weblinks['Main Menu'] %}
<nav>
  <ul>
    {% for link in main_menu.weblinks %}
      <li><a href="{{ link.url }}">{{ link.name }}</a></li>
    {% endfor %}
  </ul>
</nav>
```

Web Links can be nested (parent/child) — descend with `link.weblinks` for sub-menus.

## settings

Hash of Site Setting values by name. Site Settings are arbitrary key/value pairs configured in Dataverse.

```liquid
{% assign max_size = settings['UploadMaxSizeBytes'] | default: '10485760' | plus: 0 %}

{% if settings['Maintenance/Enabled'] == 'true' %}
  <div class="alert alert-warning">{{ settings['Maintenance/Message'] }}</div>
{% endif %}
```

All Site Setting values are **strings** — coerce to numbers with `| plus: 0`, to bools by string-comparing.

## Querystring + Form access shortcut

Liquid offers `params` as a shortcut to `request.params`:

```liquid
{% assign id = params['id'] %}                     same as request.params['id']
```

Both work; `request.params` is more explicit, `params` reads better.

## Other useful objects

| Object | Use |
|---|---|
| `forloop` | Inside `{% for %}` — `.index`, `.first`, `.last`, `.length` |
| `tablerowloop` | Inside `{% tablerow %}` — same as forloop |
| `current_user` | Synonym for `user` (legacy) |
| `entities['contact'][guid]` | Direct lookup of a Dataverse record by GUID — needs Read permission |

## Cheat sheet — common patterns

```liquid
{# Login redirect with return URL #}
<a href="/SignIn?returnurl={{ request.path_and_query | url_encode }}">Sign in</a>

{# Active nav class #}
<a class="nav-link {% if request.path == link.url %}active{% endif %}" href="{{ link.url }}">{{ link.name }}</a>

{# Localized "X minutes ago" — DotLiquid lacks `time_ago_in_words`, so format directly #}
{{ record.modifiedon | date: '%b %-d, %Y at %-I:%M %p' }}

{# Anonymous-safe user context #}
{% if user %}
  <p>Hello, {{ user.firstname }}</p>
{% else %}
  <p>Welcome, guest</p>
{% endif %}

{# Resolve sitemarker with fallback #}
{% assign customers_url = sitemarkers['Customers'].url | default: '/customers' %}
```
