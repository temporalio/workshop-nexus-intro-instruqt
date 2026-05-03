# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is the **Replay 2026 Introduction to Temporal Nexus workshop**, a 3.5-hour hands-on workshop. The repo holds the lab definition, presentation deck, and sandbox image. The actual Python and Java exercise code lives in a sibling repo, `temporalio/workshop-nexus-intro-code`, and is baked into the sandbox image at build time.

## Three surfaces

The workshop has three runtime surfaces, each rooted in its own top-level directory:

1. **`instruqt/`** is the Instruqt lab. `track.yml` is the track manifest; `config.yml` declares the sandbox container; `track_scripts/` holds global setup/cleanup; each `NN-chapter-name/` directory holds one challenge with `assignment.md` + `setup-workshop` + `cleanup-workshop` + `solve-workshop`. Pushed via the Instruqt CLI.
2. **`slides/`** is the Slidev deck (Vue/Vite SPA). `slides.md` is the master file that imports per-chapter `chapters/*.md` via `src:`. The Temporal-branded theme is **vendored** at `slides/theme-temporal/`; do not treat it as upstream-pristine because the footer text and `WorkshopToc.vue` chapter list are workshop-specific edits.
3. **AhaSlides** is off-repo, but the integration plan lives in `aha.md`. Presentation id `9123470`. The Slidev deck has dedicated transition slides ("Quiz Time", "Halftime!", etc.) at every AhaSlides switch point; speaker notes there script the lead-in/lead-out.

`course-plan.md` is the canonical course design (competencies, learning objectives, timing). `aha.md` is the canonical AhaSlides slide-by-slide spec.

## Local-only references (`tmp/`, not tracked)

`tmp/` is gitignored (`tmp/*` in `.gitignore`). Files here are working references that future Claude sessions should read but never commit:

| Path | Purpose |
| :--- | :--- |
| `tmp/style.md` | Mason's compiled style guide, synthesized from the two source decks below. **Read this before editing slides.** |
| `tmp/Temporal 102 in Python - 20250416me.pptx` | Canonical workshop-register source deck. Read with `uvx --from "markitdown[pptx]" markitdown <path>` to inventory slide-type patterns Mason actually uses. |
| `tmp/Events are the Wrong Abstraction.pptx` | Canonical talk-register source deck (PyBay 2025). |
| `tmp/audit/`, `tmp/audit*.md`, `tmp/last-audit.md`, `tmp/lessons-learned.md`, `tmp/instruqt-plan.md` | Older planning and audit artifacts; reference only. |

**Important:** `tmp/style.md` is a synthesis and can overgeneralize. Before applying any slide-type pattern (Outcomes, Review, Essential Points, About Me form, etc.) **verify it against the actual PPTX**. The PPTX is canonical; the style guide is a synthesis.

## Common commands

All recipes live in `justfile`. Run from anywhere in the repo.

```bash
# Instruqt track (requires `instruqt auth login` once)
just push          # push instruqt/ to Instruqt
just pull          # pull canonical state from Instruqt
just validate      # validate locally without pushing
just diff          # diff local vs deployed

# Slidev deck
just slides-install    # pnpm install
just slides-dev        # pnpm dev on http://localhost:3030
just slides-build      # static build to slides/dist/
```

The Slidev deck has additional commands: `pnpm export` builds the PDF (requires `playwright-chromium`, already a devDep), and `pnpm build -- --without-notes --download` produces a notes-stripped public artifact with the PDF baked in.

## Sandbox image

`docker/Dockerfile` builds the Instruqt sandbox image. The image bakes the Python source from `temporalio/workshop-nexus-intro-code` into `/opt/workshop`, pre-warms the uv venv, and builds the Java polyglot worker. CI (`.github/workflows/build-image.yml`) rebuilds the image on push to `main` when `docker/**` or the workflow itself changes, and is also manually triggerable via `workflow_dispatch` from the GitHub Actions UI (with an optional `code_ref` input to pick the code-repo ref to bake in). There is no `repository_dispatch` from the code repo; republishing after a code-repo change is a deliberate manual click.

`config.yml` pins the sandbox containers to `ghcr.io/temporalio/workshop-nexus-intro-sandbox:<tag>`. Update the tag here when you cut a new image.

## Sparse-stage pattern

Each chapter's `setup-workshop` script wipes `/root/workshop/exercises/` and copies in **only** the current chapter from `/opt/workshop/exercises/<chapter>/` to `/root/workshop/exercises/<chapter>/`. This is intentional: each chapter starts clean, with only its own files visible. Shared root files (`.venv`, `pyproject.toml`, `uv.lock`, `compliance-endpoint.md`) stay intact at `/root/workshop/`.

`setup-workshop` also defensively kills any stragglers from a prior chapter (`pkill -f payments.worker`, etc.). On macOS pkill alternation does not work; write separate calls per pattern, not `pkill -f "a|b"`.

## Exercise frontmatter is canonical

Each `instruqt/<chapter>/assignment.md` has YAML frontmatter that includes:
- `id:` (Instruqt-assigned, do not regenerate)
- `slug:`, `type: challenge`, `title:`, `teaser:`
- `tabs:` definitions for the editor, terminal, Temporal UI, and solution panes (each with its own Instruqt-assigned id)

Treat the assigned ids as load-bearing. `instruqt pull` is the source of truth after the first push.

## What lives where

| Path | Purpose |
| :--- | :--- |
| `course-plan.md` | Course design: competencies, LOs, timing |
| `aha.md` | AhaSlides integration spec, slide-by-slide |
| `instruqt/track.yml` | Track manifest (slug, id, tags, sandbox config) |
| `instruqt/config.yml` | Sandbox container image pin |
| `instruqt/track_scripts/` | Global setup/cleanup that runs once per session |
| `instruqt/NN-*/assignment.md` | Per-chapter challenge body + frontmatter |
| `slides/slides.md` | Slidev master deck (imports chapters via `src:`) |
| `slides/chapters/*.md` | Per-chapter slide content + speaker notes |
| `slides/theme-temporal/` | Vendored Temporal theme (workshop-customized) |
| `slides/DEPLOY.md` | VPS hosting guide for live presenter-follow (Caddy + Slidev dev server, PDF at `/export.pdf`) |
| `docker/Dockerfile` | Sandbox image build |
| `.github/workflows/build-image.yml` | CI for the sandbox image |

## Brand rules

**The Temporal logo MUST NEVER be rendered in Temporal mint green** (`#59FDA0` / `var(--temporal-green)`). White on dark, or black on light, only. Mint green is reserved for accent text, links, code highlights, and footer page numbers - never the plus mark or wordmark. This is a non-negotiable Temporal brand rule. If you find the logo tinted green in `theme-temporal/layouts/cover.vue`, `theme-temporal/layouts/end.vue`, or anywhere else, revert it to `#ffffff`. Do not "fix" the white back to `var(--temporal-green)` thinking it matches the palette - it does not, and it is a deadly sin.

## Slide-deck conventions

These mirror the patterns in `tmp/Temporal 102 in Python - 20250416me.pptx`. Verify against the source PPTX before introducing a new pattern.

- **Workshop register only on slide bodies.** Workshop slides stay declarative; no first-person opinion ("I believe", "I think"), no tag questions ("ya?"), no dramatic ellipsis, no mock dialogue, no SRE anecdotes on the slide itself. All of that personality lives in the `<!-- ... -->` speaker notes block.
- **Speaker notes use the "Build N" convention.** Each on-slide bullet appears verbatim in the speaker-note HTML comment, prefixed with `**Build N**` matching the v-click order. Sub-bullets add color/coaching. AhaSlides transition slides include scripted Lead-in / Lead-out lines.
- **Workshop-level Outcomes slide.** One slide near the open of the workshop (in `welcome.md`): *"During this workshop, you will…"* with verb-led bullets (Distinguish, Define, Implement, Recognize, etc.). There is no per-chapter Outcomes slide; the 102 source deck only does this at the workshop level.
- **Per-chapter Review slide.** Used at consequential chapter boundaries (Ch01, Ch04, Ch05, Ch06, Ch07 in this deck). Title is `Review`, body is 4-6 declarative synthesis bullets, built one at a time. Lands after the chapter's last lecture/exercise, before the next chapter's TOC. Skipped for short / non-consequential chapters.
- **Wrap close.** Final TOC, then `Essential Points (1)` through `Essential Points (N)` numbered slides (this deck has 5), each 3-4 synthesis bullets grouped by theme. The closing slide combines the thank-you line and the feedback URL into one slide: *"Thank you for your time and attention / We welcome your feedback: <URL>"*. There is no separate `Questions?` slide; the thank-you slide stays up during Q&A.
- **Thesis sentence reassertion.** *"The contract is the integration."* lands three times: Chapter 1 ("From Weld to Contract", as the closing v-click after the credibility bullet), Chapter 2 close ("Why Types Matter Here"), and `Essential Points (5)` at the wrap. Same vocabulary each time; the room remembers a sentence, not a section.
- **No em-dashes anywhere.** Hyphens, semicolons, commas, or rephrase. Em-dashes read as AI-generated.
- **No forward references.** Do not write "Chapter N covers", "we'll see", or "AhaSlides slide N tests" in slides or labs. Backward references in speaker notes ("Recall the contract from earlier") are fine.
- **Slidev imports.** When adding a new chapter, add the chapter file under `slides/chapters/` and import it from `slides/slides.md` via a frontmatter-only slide with `src: ./chapters/<file>.md`.
- **Slide font sizes match PowerPoint defaults from the canonical Temporal 102 deck.** Base 1.375rem (22pt body), h1 3rem (48pt title), h2 2.2rem, h3 1.7rem, code 1.375rem (22pt), inline code 1.2rem. Conversion rule: Slidev's default canvas is 980 CSS px wide and PPT 16:9 is 960pt wide, so 1pt ≈ 1px and rem = pt ÷ 16. Footer sits 18px from canvas bottom via `margin-bottom: -1.875rem` on `.temporal-footer` (the layout's `padding-bottom: 3rem` reserves a content-protection zone; the negative margin lets the footer extend past it without changing where content can sit). If you change font sizes, re-audit overflow with `slides/dist/export/` after a build.
- **Per-slide style overrides use `<style>` blocks.** Each Slidev slide compiles as its own Vue component, so a plain `<style>` block in the slide markdown is auto-scoped to that slide. Frontmatter `class: text-sm` does not reliably override the theme's explicit font sizes (specificity loses); use `<style>` blocks instead. Examples in the deck: the Agenda table's tighter cell padding, the Patterns slide's centered mint-green punchline.
- **Chapters open with the TOC slide only.** Each chapter file starts with `layout: toc` (which highlights the current chapter) and jumps directly into content. There is no separate `# 01 / Why Nexus` section-divider title slide between the TOC and the first content slide; the TOC already signals the chapter transition. Do not re-add section dividers.
- **Ch 1 pacing is intentional and asymmetric to other chapters.** Ch 1 is the only chapter where the Instruqt lab runs *before* the chapter's main solution lecture: frame the problem → AhaSlides warmup poll → Instruqt lab ("Run the Monolith") → Slidev Nexus intro → AhaSlides graded quiz → Slidev review. The room feels the architecture before being told what's wrong with it. Every other chapter follows the standard lecture → exercise → quiz pattern. `course-plan.md`, `aha.md`, and `slides/chapters/ch01-why-nexus.md` all agree on this ordering.

## Vocabulary convention: handler vs implementer

The Temporal docs use "handler" for three different referents: a **side** (a team or namespace), a **piece of code** (a function or class with `@sync_operation` or `@workflow_run_operation`), and a **Worker** process. The metaphor is internally consistent but the referent shifts sentence to sentence, which is the single biggest pedagogical friction in introducing Nexus. This workshop disambiguates:

- **handler** = the code only (a function or class with `@sync_operation` or `@workflow_run_operation`).
- **implementer** = the side, the team, the role.
- **Worker** stays "Worker." Already its own well-known concept.
- **caller** stays "caller." The docs only use that word one way.

Ch 1 has a dedicated **"Same Word, Three Different Things"** slide that explicitly explains this convention to the room before any other chapter uses the terminology. Subsequent chapters use **"implementer-side"** instead of "handler-side" wherever the role/side is meant. Code-level references (sync handler, async handler, handler Worker, handler Workflow, decorator names) are kept because they match SDK and doc canon. Do not sweep these back to "handler" for the role.

When editing slides or speaker notes, watch for the role-level usage specifically: phrases like "the handler picks", "the handler decides", "handler-side team", "handler side", or "the handler can choose" all belong to the role and should use "implementer." Phrases like "@sync_operation handler", "OperationHandler.sync", or "the handler Workflow" are code-level and stay.
