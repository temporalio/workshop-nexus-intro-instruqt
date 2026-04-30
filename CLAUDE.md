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

`docker/Dockerfile` builds the Instruqt sandbox image. The image bakes the Python source from `temporalio/workshop-nexus-intro-code` into `/opt/workshop`, pre-warms the uv venv, and builds the Java polyglot worker. CI (`.github/workflows/build-image.yml`) rebuilds the image on push to `main` or `init` when `docker/**` or the workflow itself changes, **and** on a `repository_dispatch` from the code repo so a code change there republishes the image.

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
- **Thesis sentence reassertion.** *"The contract is the integration."* lands three times: welcome ("What Is Nexus?"), Chapter 2 close ("Why Types Matter Here"), and `Essential Points (5)` at the wrap. Same vocabulary each time; the room remembers a sentence, not a section.
- **No em-dashes anywhere.** Hyphens, semicolons, commas, or rephrase. Em-dashes read as AI-generated.
- **No forward references.** Do not write "Chapter N covers", "we'll see", or "AhaSlides slide N tests" in slides or labs. Backward references in speaker notes ("Recall the contract from earlier") are fine.
- **Slidev imports.** When adding a new chapter, add the chapter file under `slides/chapters/` and import it from `slides/slides.md` via a frontmatter-only slide with `src: ./chapters/<file>.md`.
- **Slide font sizes.** The vendored theme has been tuned for content density (base 1.15rem, h1 2.4rem, code 0.95rem, tightened margins). If you reduce further, re-audit overflow with `slides/dist/export/` after a build.
- **Course plan vs aha.md timing.** The mermaid in `aha.md` puts the Ch1 graded quiz **before** the Ch1 Instruqt exercise (lecture, quiz, exercise), which differs from `course-plan.md`. The Slidev deck follows `aha.md`.
