# Strict CSP and Design-System Work in Power Pages

Assume **strict CSP is on by default** for modern Power Pages sites unless the user tells you otherwise. Design guidance that only works with lax CSP is incomplete guidance.

For the full setting model, see [`../data/site-settings.md`](../data/site-settings.md). This file is the design-system translation layer.

## Default implementation bias

When proposing or generating UI patterns:

- prefer semantic HTML
- prefer external page/site JS files over inline scripts
- prefer local CSS over third-party runtime styling systems
- prefer local assets over CDN dependencies
- avoid anything that needs `unsafe-eval`
- avoid runtime script injection

## What strict CSP changes in practice

### Do this by default

- Put behavior in `*.webpage.custom_javascript.js` or `web-files/**/*.js`
- Put styling in page/site CSS files, not JS-generated style tags
- Keep components implementable with HTML, CSS, and small deterministic JS
- Use libraries only when they can run from allowed sources without eval-like behavior

### Avoid by default

- inline `onclick=`, `onchange=`, and similar event attributes
- ad hoc `<script>` blobs pasted into markup when an external file would do
- dynamically injecting `<script src=...>` at runtime
- libraries that depend on `eval`, `new Function`, or opaque runtime compilation
- design approaches that assume Tailwind build tooling, React hydration, or npm bundling inside the portal runtime

## Nonce-aware rule

Power Pages can nonce inline scripts, but that is not a license to design around inline JS.

Use this bias:

- **Small legacy page already uses an inline script block**: acceptable if necessary
- **New reusable component pattern**: move behavior to external JS
- **Anything that loads additional scripts dynamically**: redesign it

The reason is simple: runtime-created scripts cannot reliably inherit the portal nonce, so patterns based on loader scripts are fragile under strict CSP.

## Design-system-specific guidance under strict CSP

### USWDS 3

- Favor token/style translation and semantic structure over importing the full front-end stack
- Rebuild missing interactions locally

### Material Design 3

- Borrow component behavior and state patterns, not framework-specific packages
- Keep motion and behavior in local JS

### Apple HIG

- Mostly unaffected because the value comes from principles, not a required library

### Fluent 2

- Use Fluent-inspired structure and tokens locally
- Be careful with component packages that assume a heavier app runtime

### shadcn/ui

- Treat it as a pattern source, not a package-install instruction
- Recreate the component with portal-safe HTML/CSS/JS instead of assuming React/Radix/Tailwind plumbing

## Asset allowlist mindset

If the user wants external fonts, icons, analytics, embedded media, maps, or CDN-served component assets, check whether the design requires CSP changes.

Common consequences:

- new font host may require `font-src` and `style-src`
- image/media hosts may require `img-src` or `media-src`
- iframe/embed providers may require `frame-src`
- third-party JS may require `script-src`

Default recommendation: if the component can be built without a new external origin, do that first.

## Safe recommendation patterns

Good:

- "Use a local carousel implementation in page JS and style it with existing portal tokens."
- "Build the drawer with semantic HTML, ARIA state, and CSS transforms; keep all logic in the page JS file."
- "Recreate the shadcn/ui card/filter pattern using Bootstrap layout and local CSS variables."

Bad:

- "Paste this inline script and load two CDN packages from unpkg."
- "Inject a script tag after page load to initialize the component."
- "Use a React-only library for this one page inside the classic portal."

## Review checklist for generated UI

Before approving a UI recommendation or code sample, check:

- Does it rely on inline event handlers?
- Does it rely on runtime script injection?
- Does it introduce new external origins?
- Would it fail if `script-src` is tight?
- Can the same pattern be implemented with local files already supported by the portal?

If the answer exposes CSP fragility, revise the approach before returning it.
