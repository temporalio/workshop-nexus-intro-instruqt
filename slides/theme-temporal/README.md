# slidev-theme-temporal

A [Slidev](https://sli.dev) theme that matches Temporal's brand. Inter typography, mint-and-purple palette, grid and starfield backgrounds, and layouts tuned for workshops and technical talks.

## Install

The theme ships as a private git dependency. Both install paths require GitHub access to the `temporalio` org.

### Option 1: Git dependency (recommended)

Add the theme to an existing Slidev deck:

```bash
pnpm add github:temporalio/slidev-theme-temporal
```

Then set the theme in your `slides.md` frontmatter:

```yaml
---
theme: temporal
---
```

Pin to a tag or commit for reproducibility:

```bash
pnpm add github:temporalio/slidev-theme-temporal#v0.1.0
```

Update the theme later with:

```bash
pnpm update slidev-theme-temporal
```

### Option 2: Copy files in

If you prefer to vendor the theme into your deck:

```bash
pnpm dlx tiged temporalio/slidev-theme-temporal theme
```

Then reference it by path in your `slides.md`:

```yaml
---
theme: ./theme
---
```

## What's included

Layouts:

- `cover` , title slide with Temporal gradient backdrop
- `default` , standard body slide
- `section` , section divider
- `exercise` , workshop exercise card
- `two-cols` , two-column layout
- `toc` , workshop table of contents
- `end` , closing slide

Components:

- `TemporalLogo` , inline Temporal wordmark
- `TemporalFooter` , persistent footer for body slides
- `WorkshopToc` , auto-generated workshop table of contents

Setup:

- Custom `temporal-dark` Shiki theme
- Mermaid defaults tuned to the Temporal palette

## Development

Clone the repo and link it into a local Slidev deck for live editing:

```bash
git clone git@github.com:temporalio/slidev-theme-temporal.git
cd your-deck
pnpm add link:../slidev-theme-temporal
```

## License

MIT. See [LICENSE](./LICENSE).
