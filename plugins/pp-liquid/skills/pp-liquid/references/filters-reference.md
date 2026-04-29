# DotLiquid Filter Reference (Power Pages flavor)

A consolidated table of every Liquid filter that works in Power Pages. Standard DotLiquid filters plus Power Pages-specific extensions. Examples are tested against real DotLiquid behavior — there are several places where Power Pages diverges from Shopify Liquid, marked clearly.

## Standard string filters

| Filter | Example | Output | Notes |
|---|---|---|---|
| `append` | `{{ 'foo' \| append: 'bar' }}` | `foobar` | |
| `prepend` | `{{ 'bar' \| prepend: 'foo-' }}` | `foo-bar` | |
| `capitalize` | `{{ 'hello world' \| capitalize }}` | `Hello world` | First char only |
| `upcase` | `{{ 'foo' \| upcase }}` | `FOO` | |
| `downcase` | `{{ 'FOO' \| downcase }}` | `foo` | |
| `strip` | `{{ '  foo  ' \| strip }}` | `foo` | Both ends |
| `lstrip` / `rstrip` | `{{ '  foo  ' \| lstrip }}` | `foo  ` | One end |
| `truncate` | `{{ 'longstring' \| truncate: 5 }}` | `lo...` | Default ellipsis is `...` (3 chars in the count) |
| `truncatewords` | `{{ 'one two three four' \| truncatewords: 2 }}` | `one two...` | |
| `replace` | `{{ 'hello' \| replace: 'l', 'L' }}` | `heLLo` | Literal replace, **not regex** |
| `replace_first` | `{{ 'foofoo' \| replace_first: 'foo', 'bar' }}` | `barfoo` | |
| `remove` | `{{ 'a-b-c' \| remove: '-' }}` | `abc` | |
| `remove_first` | `{{ 'a-b-c' \| remove_first: '-' }}` | `ab-c` | |
| `split` | `{{ 'a,b,c' \| split: ',' }}` | array `[a,b,c]` | |
| `join` | `{{ arr \| join: ', ' }}` | comma-joined | |
| `size` | `{{ 'hello' \| size }}` | `5` | Works on strings AND arrays |
| `slice` | `{{ 'hello' \| slice: 0, 3 }}` | `hel` | First arg is index, second is length |
| `escape` | `{{ '<a>' \| escape }}` | `&lt;a&gt;` | HTML entities only — NOT for JSON |
| `escape_once` | `{{ '<a>' \| escape_once }}` | `&lt;a&gt;` | Won't double-escape `&amp;` |
| `strip_html` | `{{ '<p>x</p>' \| strip_html }}` | `x` | |
| `strip_newlines` | `{{ "a\nb" \| strip_newlines }}` | `ab` | |
| `newline_to_br` | `{{ "a\nb" \| newline_to_br }}` | `a<br/>b` | |
| `url_encode` | `{{ 'a b' \| url_encode }}` | `a+b` | For querystring values |
| `url_escape` | `{{ 'a b' \| url_escape }}` | `a%20b` | DotLiquid alias for url_encode in newer versions |

## Numeric filters

| Filter | Example | Output | Notes |
|---|---|---|---|
| `plus` | `{{ 5 \| plus: 2 }}` | `7` | |
| `minus` | `{{ 5 \| minus: 2 }}` | `3` | |
| `times` | `{{ 5 \| times: 2 }}` | `10` | |
| `divided_by` | `{{ 10 \| divided_by: 3 }}` | `3` | Integer division if both ints |
| `divided_by` | `{{ 10 \| divided_by: 3.0 }}` | `3.333` | Float division if either is float |
| `modulo` | `{{ 10 \| modulo: 3 }}` | `1` | |
| `round` | `{{ 3.456 \| round: 2 }}` | `3.46` | |
| `ceil` | `{{ 3.1 \| ceil }}` | `4` | |
| `floor` | `{{ 3.9 \| floor }}` | `3` | |
| `abs` | `{{ -5 \| abs }}` | `5` | |

## Conversion / coercion

| Filter | Example | Output | Notes |
|---|---|---|---|
| `default` | `{{ x \| default: 'fallback' }}` | x or fallback | Falls back on **blank**, including `0` and `false` (gotcha) |
| `to_string` | `{{ 5 \| to_string }}` | `'5'` | Explicit cast |
| `to_integer` | `{{ '5' \| to_integer }}` | `5` | Less common; `\| plus: 0` is the idiomatic form |

**`default` gotcha**: blank includes `0` and `false`, so `{{ 0 \| default: 'none' }}` → `'none'` (probably surprising). Check explicitly:

```liquid
{% if count == 0 or count > 0 %}{{ count }}{% else %}none{% endif %}
```

## Date filters

| Filter | Example | Output |
|---|---|---|
| `date` | `{{ 'now' \| date: '%Y-%m-%d' }}` | `2026-04-28` |
| `date` | `{{ now \| date: '%B %-d, %Y' }}` | **DotLiquid: not supported** — strip leading zero in output instead |
| `date` | `{{ '2026-04-28' \| date: '%m/%d/%Y' }}` | `04/28/2026` |

**Supported strftime tokens**:
- `%Y` `%m` `%d` `%H` `%M` `%S` `%B` `%b` `%A` `%a` `%I` `%p` `%Z` — OK
- `%-d` `%-m` (no leading zero) — **NOT supported** in DotLiquid
- `%s` (Unix timestamp) — **NOT supported**

For numeric-only dates (GCC environment requirement), stick to `%m/%d/%Y`.

## Array filters

| Filter | Example | Output | Notes |
|---|---|---|---|
| `first` | `{{ arr \| first }}` | first element | |
| `last` | `{{ arr \| last }}` | last element | |
| `size` | `{{ arr \| size }}` | length | |
| `join` | `{{ arr \| join: ', ' }}` | comma-joined string | |
| `reverse` | `{{ arr \| reverse }}` | reversed array | |
| `sort` | `{{ arr \| sort }}` | sorted ascending (case-sensitive) | |
| `sort_natural` | `{{ arr \| sort_natural }}` | sorted, case-insensitive | DotLiquid 2.x+ |
| `uniq` | `{{ arr \| uniq }}` | duplicates removed | |
| `where` | `{{ rows \| where: 'statecode', 0 }}` | filter by attr=value | DotLiquid version-dependent |
| `where_exp` | NOT supported | — | DotLiquid lacks Shopify's expression form |
| `concat` | `{{ a \| concat: b }}` | concatenated array | |
| `compact` | `{{ arr \| compact }}` | nils removed | |
| `map` | `{{ rows \| map: 'fullname' }}` | array of attr values | |

## Power Pages-specific filters

These are extensions Power Pages adds on top of standard DotLiquid:

| Filter | Example | Output / Use |
|---|---|---|
| `has_role` | `{% if user \| has_role: 'State Employee' %}…{% endif %}` | true if user has the named Web Role |
| `current_culture` | `{{ '' \| current_culture }}` | request locale (`en-US`, `es-MX`, etc.) |
| `display_name` | `{{ row.statecode \| display_name }}` | OptionSet display name from value |
| `metafield` | `{{ row \| metafield: 'tier' }}` | resolves a metafield/custom property |
| `liquid` | `{{ snippet_html \| liquid }}` | parses and renders the string as Liquid |
| `boolean` | `{{ 'true' \| boolean }}` | parse string to bool — exists in some PP versions |
| `decimal` | `{{ '3.14' \| decimal }}` | parse string to decimal — exists in some PP versions |
| `json` | `{{ row \| json }}` | dump object as JSON (debugging) |

## JSON output filters (combination patterns)

For emitting JSON that JS will consume:

```liquid
<script id="dataJSON" type="application/json">
[
  {% for row in rows %}
    {
      "id":   "{{ row.contactid }}",
      "name": "{{ row.fullname | replace: '"', '"' }}"
    }{% unless forloop.last %},{% endunless %}
  {% endfor %}
]
</script>
```

Key choices:

1. `<script type="application/json">` — browser doesn't execute, syntax errors don't crash.
2. `replace: '"', '"'` — Unicode escape, NOT `\\"` (which produces 3 chars in DotLiquid).
3. **Do NOT use `| escape`** — produces HTML entities (`&quot;`) that stay literal in `<script>`.
4. `JSON.parse` on the client side, with try/catch.

## Filter chaining

Filters chain left-to-right:

```liquid
{{ 'Hello, World!' | downcase | replace: ',', '' | strip }}
{# → "hello world!" #}

{{ rows | map: 'fullname' | sort | join: ', ' }}
{# → "Alice, Bob, Charlie" #}
```

DotLiquid does NOT support nested filter calls in expressions — assign first:

```liquid
{# Doesn't work in some DotLiquid versions: #}
{% if (request.params['x'] | strip) != '' %}

{# Works everywhere: #}
{% assign x = request.params['x'] | strip %}
{% if x != '' %}…
```

## Common patterns by use case

### Format a phone number for display

```liquid
{# Liquid lacks regex; do it client-side or accept the unformatted display #}
{{ contact.telephone1 }}                            (whatever's in Dataverse)
```

### Format currency

```liquid
${{ amount | round: 2 }}
${{ amount | divided_by: 100.0 | round: 2 }}        if stored in cents
```

For locale-aware currency, do it client-side with `Intl.NumberFormat`.

### Truncate a description with ellipsis

```liquid
{{ description | strip_html | truncate: 200, '…' }}
```

`truncate` accepts a custom ellipsis as the second argument.

### Build a querystring URL safely

```liquid
{% assign encoded = request.params['search'] | url_encode %}
<a href="/results?search={{ encoded }}&page=1">Reset to page 1</a>
```

### Pluralize

DotLiquid lacks `pluralize`. Roll your own:

```liquid
{{ count }} item{% if count != 1 %}s{% endif %}
```

### "X minutes ago" relative time

DotLiquid lacks `time_ago_in_words`. Format absolute instead:

```liquid
{{ row.modifiedon | date: '%b %-d, %Y at %-I:%M %p' }}
```

(But remember `%-d` and `%-I` are not supported in DotLiquid — use `%d` and `%I` and accept leading zeros, or format client-side.)

### Conditional CSS class

```liquid
<a class="nav-link {% if request.path == link.url %}active{% endif %}" href="{{ link.url }}">
  {{ link.name }}
</a>
```

## Filters that DON'T exist in DotLiquid (despite Shopify docs implying they should)

| Filter | Status |
|---|---|
| `where_exp` | Not supported |
| `pluralize` | Not supported |
| `time_ago_in_words` | Not supported |
| `t` (translation) | Not supported |
| `url_for` | Not supported (Power Pages uses `sitemarkers` instead) |
| `image_tag` | Not supported (Shopify-specific) |
| `stylesheet_tag` / `script_tag` | Not supported (Shopify-specific) |
| `asset_url` / `asset_img_url` | Not supported (use `/<filename>` for `web-files/`) |

If you see a Shopify Liquid example using one of these, find a Power Pages equivalent before assuming it works.
