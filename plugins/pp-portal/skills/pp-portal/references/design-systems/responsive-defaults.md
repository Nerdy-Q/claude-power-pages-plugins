# Responsive and Device Defaults for Power Pages

Use this file whenever the user asks for UI help without explicitly mentioning responsive behavior. Responsive design is the default, not an optional enhancement.

## Default stance

Build **mobile-first**, then scale up for tablet and desktop.

Treat these as baseline expectations:

- mobile: primary path must work one-handed and without hover
- tablet: layouts can expand, but controls must remain touch-friendly
- desktop: use extra space for density, secondary actions, and richer filtering

## Core layout rules

- Start with a **single-column mobile layout** unless the task genuinely requires side-by-side content.
- Promote to two columns at tablet widths only when both columns remain readable and actionable.
- Avoid more than three major columns on desktop for transactional portal pages.
- Use stacked cards, sections, or fieldsets on mobile instead of squeezing tables/forms.
- Keep the page's primary action visible without requiring precision scrolling.

## Touch and spacing defaults

- Minimum target size: `44x44` CSS pixels
- Minimum gap between adjacent touch targets: `8px`
- Form controls should be full-width on mobile unless there is a strong reason not to
- Avoid hover-only disclosures; provide tap/click equivalents

## Navigation defaults

- On mobile, collapse broad nav into a simple menu or section jump pattern.
- On tablet, keep nav visible only if it does not crowd task content.
- On desktop, add secondary navigation, filters, summaries, or sidebars.
- Keep current-page indication obvious in every breakpoint.

## Forms

- Prefer one-column forms on mobile.
- Group related fields with headings, not just spacing.
- Put helper text below the field, not in placeholder text alone.
- For two related short fields, side-by-side starts at tablet, not narrow mobile.
- Place destructive or secondary actions after the primary action on mobile.

## Tables and data-heavy views

Default question: should this remain a table on small screens?

If the answer is no, choose one of these:

- transform rows into stacked cards
- show a reduced-column table with horizontal scroll
- split summary and detail into separate views

Keep desktop tables when they add scanning value, but on mobile:

- prioritize 2-4 critical fields
- move secondary metadata below the primary line
- keep filter and sort controls compact and obvious

## Component defaults

### Modals and dialogs

- On mobile, prefer full-height sheet or full-screen dialog behavior.
- On desktop, centered modal is acceptable for short tasks.
- Do not trap essential content in tiny modals on small screens.

### Carousels

- Use only when the user explicitly wants one or the content is genuinely sequential.
- One item visible on mobile is the default.
- Provide previous/next controls, visible labels, optional pagination, pause control if auto-advancing, and reduced-motion behavior.

### Drawers and filter panels

- On mobile, use full-width or near-full-width sheet behavior.
- On desktop, a side panel is fine if it does not hide critical state changes.

### Tabs

- Avoid wide horizontal tab rows on mobile.
- Convert to segmented controls, accordions, or section stacks when labels wrap badly.

## Visual density

- Mobile: relaxed density, shorter line lengths, clear section rhythm
- Tablet: moderate density
- Desktop: denser only when it improves scanning or throughput

Do not apply dense enterprise tables/forms unchanged to phones.

## Typography defaults

- Prioritize readable body copy over dramatic scale shifts.
- Avoid tiny supporting text on mobile.
- Keep line length controlled on desktop; wide text blocks need max-width constraints.

## Motion defaults

- Motion should explain state changes, not decorate them.
- Keep transitions short and purposeful.
- Respect `prefers-reduced-motion: reduce`.
- Avoid parallax or auto-advancing motion in task-heavy portals.

## Power Pages-specific implementation

- Use Bootstrap grid and utilities as the layout baseline.
- Prefer CSS media queries and container discipline over JS-driven layout switching.
- Avoid components that depend on pointer-hover for critical affordances.
- Test custom entity-list or FetchXML-rendered results at small widths before treating them as complete.
- If a Studio-authored section uses inline styles that break responsiveness, override carefully and locally instead of broad global resets.
- Keep responsive enhancements **strict-CSP-safe**: external JS files, no inline event handlers, no runtime script injection. See [strict-csp.md](strict-csp.md).

## Device-specific bias by design system

### USWDS 3

- Lean toward clarity and robust form behavior on mobile.
- Keep layouts restrained and content-first.

### Material Design 3

- Strong source for mobile navigation, sheet, and state-transition behavior.

### Fluent 2

- Strong source for desktop/tablet productivity layouts; reduce density on phones.

### Apple HIG

- Strong source for touch ergonomics, spacing, and calm hierarchy.

### shadcn/ui

- Strong source for web card/dialog/filter patterns, but verify every pattern on mobile because many examples skew desktop-first.
