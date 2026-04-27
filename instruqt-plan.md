# Instruqt Build Plan: Introduction to Temporal Nexus

A planning document for the Instruqt portion of the workshop. Captures the
target structure, sandbox environment, lifecycle scripts, and per-challenge
detail so a future build session can implement without re-deriving decisions.

This plan deliberately **simplifies away** parts of `course-plan.md` that the
user has now overruled. Where the course plan describes a multi-container
layout (payments / compliance / java-legacy) on Linux VMs, the user has asked
for "simplest possible" and "Docker over VMs if we can get away with it". This
plan therefore proposes **one Docker container running everything**, with the
Temporal dev server started as a background process inside that container.

The plan makes no source-tree changes. It is for review.

## Reference workshops

Three existing workshops are the source material for this plan:

- **Tailscale** at `/Users/masonegger/Code/Temporal-Community/workshop-tailscale-replay-2026/instruqt/`
  is the canonical style guide for assignment.md voice, frontmatter, tabs,
  step button references, and the setup/solve script shapes. The Nexus
  workshop will mimic its authoring style.
- **Versioning** at `/Users/masonegger/Code/temporal-versioning-workshop/instruqt/`
  is the canonical pattern for running a local Temporal dev server inside the
  attendee's environment.
- **Java hands-on** at `https://github.com/mmerrell/temporal-java-hands-on`
  is the canonical pattern for **baking everything into a custom Docker image
  published to GHCR**.

The Nexus workshop combines the three: Tailscale's authoring style, Java
hands-on's bake-it-into-the-image build pipeline, Versioning's in-process
dev server pattern.

## Goals and constraints

1. **Simplest possible environment.** One container with all tooling and
   the workshop source baked in. Avoid the three-container payments /
   compliance / java-legacy split from `course-plan.md`. All workers and
   the Temporal dev server run in the same container.
2. **Bake the install into a custom Docker image.** Python, uv, Temporal CLI,
   JDK, Maven, the workshop source code, and the warmed Maven and uv caches
   all live in the image. Built and published via GitHub Actions to GHCR.
   Per-challenge `setup-workshop` scripts do almost nothing because the
   environment is already complete.
3. **One challenge per exercise.** With the quiz now handled outside Instruqt,
   the track has **8 challenges**: 7 code (Ch 1 to Ch 7) plus 1 polyglot demo.
4. **More explanation in Instruqt than in the per-chapter README.** The
   READMEs are concise and code-focused. The Instruqt `assignment.md` should
   carry the lecture context that would otherwise live only in the slides:
   why this concept matters, the problem framing, the before-and-after
   diagrams, plus the step-by-step commands.
5. **No `check-workshop` scripts in the Replay 2026 release.** The user
   explicitly said: skip-and-kill-workers is enough; real validation can be
   added in a later iteration. Each challenge ships only `setup-workshop`,
   `solve-workshop`, and `cleanup-workshop`. The "Check" button (if
   surfaced) becomes a soft pass-through.
6. **Exit scripts must kill workers before moving on.** Every code challenge
   ships a `cleanup-workshop` script that pkills the payments and compliance
   workers (separate `pkill -f` calls per pattern, not alternation).
7. **Attendees start workers themselves.** No `nohup` worker pre-launching
   in setup. The act of `uv run python -m payments.worker` is part of the
   pedagogical surface in every chapter.
8. **No em-dashes anywhere or non-ASCII characters in prose other than
   directory symbols.** Per the user's standing memory.

## Sandbox environment

### Single-container layout (in-process dev server)

```yaml
# instruqt/config.yml
version: "3"
containers:
  - name: workshop
    image: ghcr.io/temporalio/workshop-nexus-intro-sandbox:latest
    shell: /bin/bash
    memory: 4096
```

**Decision recorded during scaffolding:** earlier drafts of this plan
proposed a two-container layout with a `temporalio/temporal:latest` sidecar
running `temporal server start-dev`. That depended on a `command:` field in
Instruqt's `containers:` schema which is **not in the public docs**. When
the actual config.yml of the inspiration workshop
(`mmerrell/temporal-java-hands-on`) was inspected, that workshop turned out
to use `virtualmachines:` with nested Docker, not native `containers:`. To
avoid relying on undocumented Instruqt features, this plan reverts to the
**versioning-workshop pattern**: one native container with the Temporal dev
server running as a background process inside it (started by
`track_scripts/setup-workshop`).

Rationale:

- One image to build (the `workshop` sandbox).
- No undocumented Instruqt fields.
- Versioning workshop has proven this pattern works.
- The dev server is a background process inside the same container as the
  workers; the per-challenge `cleanup-workshop` scripts only kill workers,
  the track-level `cleanup-workshop` kills the dev server.
- Service tab points at `workshop:8233` (the local container's port).
- 4 GB ceiling on the workshop container. The dev server, two Python
  workers, an occasional Java worker, IDE, and shells fit comfortably.
- No `secrets:` block. The repo source is baked in; no runtime credentials
  needed.

### What runs in the container

| Process                           | Started where        | Killed where                |
| :-------------------------------- | :------------------- | :-------------------------- |
| `temporal server start-dev`       | `track_scripts/setup-workshop` (nohup, PID written to `/tmp/temporal-server.pid`) | `track_scripts/cleanup-workshop` |
| `payments` worker (foreground)    | Attendee, in **Payments Worker** terminal tab | Per-challenge `cleanup-workshop` |
| `compliance` worker (foreground)  | Attendee, in **Compliance Worker** terminal tab | Per-challenge `cleanup-workshop` |
| `java-legacy` worker (Ch 8 only)  | Attendee, in **Compliance Worker** terminal tab (after stopping Python) | Per-challenge `cleanup-workshop` |

Per-challenge cleanup never kills the dev server. Only track-level cleanup
does. This way the attendee does not lose dev server state when moving
between challenges.

## Custom Docker image

### `docker/Dockerfile`

Adapted from the Java hands-on workshop's Dockerfile, plus Python tooling.

```dockerfile
# workshop-nexus-intro-sandbox
# Base image for the Temporal Nexus workshop (Instruqt sandbox).
#
# Contains:
#   - Python 3.13 (via deadsnakes PPA)
#   - uv (Python package manager)
#   - Eclipse Temurin JDK 21 (LTS)
#   - Maven 3.9
#   - Temporal CLI (pinned)
#   - The full workshop-nexus-intro-code repo at /opt/workshop
#   - Pre-warmed uv venv at /opt/workshop/.venv
#   - Pre-built Java polyglot worker at /opt/workshop/polyglot/java-legacy/target/
#
# The Temporal dev server runs as a background process inside this same
# container (started by track_scripts/setup-workshop), matching the
# temporal-versioning-workshop pattern.

FROM eclipse-temurin:21-jdk-jammy

# --- System packages -----------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl wget git vim nano less unzip ca-certificates bash-completion \
      software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      python3.13 python3.13-venv python3.13-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Maven 3.9 -----------------------------------------------------------
ARG MAVEN_VERSION=3.9.9
RUN wget -q "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      -O /tmp/maven.tar.gz \
    && tar -xzf /tmp/maven.tar.gz -C /opt \
    && ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven \
    && ln -s /opt/maven/bin/mvn /usr/local/bin/mvn \
    && rm /tmp/maven.tar.gz
ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# --- uv (Python package manager) ----------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# --- Temporal CLI -------------------------------------------------------
ARG TEMPORAL_CLI_VERSION=1.3.0
RUN curl -sSL \
      "https://github.com/temporalio/cli/releases/download/v${TEMPORAL_CLI_VERSION}/temporal_cli_${TEMPORAL_CLI_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin temporal \
    && chmod +x /usr/local/bin/temporal

# --- Bake in the workshop source ----------------------------------------
# The build context must include the workshop-nexus-intro-code repo at
# ./workshop-nexus-intro-code/ (the GHA workflow checks it out alongside
# this repo, see .github/workflows/build-image.yml).
COPY workshop-nexus-intro-code/ /opt/workshop/

# --- Pre-warm Python venv -----------------------------------------------
WORKDIR /opt/workshop
RUN uv sync

# --- Pre-build Java polyglot worker -------------------------------------
WORKDIR /opt/workshop/polyglot/java-legacy
RUN mvn -q -DskipTests package

# --- Shell environment --------------------------------------------------
RUN echo 'export TEMPORAL_ADDRESS="${TEMPORAL_ADDRESS:-127.0.0.1:7233}"' >> /root/.bashrc \
    && echo 'export WORKSHOP_REPO=/root/workshop' >> /root/.bashrc \
    && echo 'export PATH="/usr/local/bin:${PATH}"' >> /root/.bashrc

WORKDIR /root
CMD ["/bin/bash"]
```

Key design decisions:

- **Base image: `eclipse-temurin:21-jdk-jammy`**. JDK 21 LTS, matching the Java
  hands-on workshop's pattern (they use 17, but our polyglot story benefits
  from latest LTS for SDK compat).
- **Python via deadsnakes**. Python 3.13 to match the workshop-nexus-intro-code
  repo's `pyproject.toml`. Could downgrade to 3.12 (Ubuntu Jammy default) if
  3.13 proves troublesome; the repo currently declares `>=3.10` but the user
  wants 3.13 per `lessons-learned.md`.
- **Source baked at `/opt/workshop`, runtime working tree at
  `/root/workshop`**. The track-level `setup-workshop` script symlinks or
  copies `/opt/workshop` to `/root/workshop` at first run. Keeps the
  attendee's edits separate from the read-only source. (Alternatively, copy
  on entry per challenge to support reset.)
- **Maven dependency cache pre-warmed**. `mvn package` during build means
  the Ch 8 polyglot challenge starts instantly.
- **uv venv pre-warmed**. `uv sync` during build means the first
  `uv run python -m payments.worker` starts without a network round trip.
- **Temporal CLI pinned**. `1.3.0` matches the Java hands-on. We may bump
  if a newer release is required for Nexus features.

### `.github/workflows/build-image.yml`

Builds the image on every push to `main` of the workshop-nexus-intro repo
that touches `docker/`, and also on every push to the
workshop-nexus-intro-code repo (via `repository_dispatch`).

```yaml
name: Build sandbox image
on:
  push:
    branches: [main]
    paths:
      - 'docker/**'
      - '.github/workflows/build-image.yml'
  repository_dispatch:
    types: [code-repo-updated]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout instruqt repo
        uses: actions/checkout@v4

      - name: Checkout workshop-nexus-intro-code (private)
        uses: actions/checkout@v4
        with:
          repository: temporalio/workshop-nexus-intro-code
          token: ${{ secrets.WORKSHOP_CODE_PAT }}
          path: workshop-nexus-intro-code
          ref: main   # or a stable tag, see "Pinning" below

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/Dockerfile
          push: true
          tags: |
            ghcr.io/temporalio/workshop-nexus-intro-sandbox:latest
            ghcr.io/temporalio/workshop-nexus-intro-sandbox:sha-${{ github.sha }}
```

Notes:

- The `WORKSHOP_CODE_PAT` secret is a fine-grained GitHub PAT scoped to
  `Contents: Read` on the private `workshop-nexus-intro-code` repo. Created
  once by the workshop owner and stored as a repo-level secret in the
  workshop-nexus-intro repo.
- The `repository_dispatch` hook lets the code repo trigger a rebuild when
  it pushes new exercise content. Add a corresponding workflow on the code
  repo side that calls `gh api -X POST repos/temporalio/workshop-nexus-intro/dispatches`
  on push.
- The image is published to GHCR under the temporalio org. **Open question:**
  confirm the destination org and whether the published image should be
  public or private.

### Pinning the workshop source

Two options for what `ref:` to check out in the GHA build:

- **Latest `main` (default).** Image is always current. Risk: a broken push
  to `main` breaks the Instruqt sandbox until reverted.
- **Stable release tag** (e.g. `v1.0.0-replay-2026`). Image is reproducible.
  Required for the Replay event to avoid surprise breakage. Bump the tag in
  the GHA workflow when ready to ship a new build.

Recommendation: **default to a stable tag for the Replay event**, and use
`latest` only during active development. The GHA workflow's `ref:` field
controls this; the image tag should match (e.g.
`workshop-nexus-intro-sandbox:v1.0.0-replay-2026`).

## Top-level directory layout

```
workshop-nexus-intro/
|-- course-plan.md
|-- lessons-learned.md
|-- instruqt-plan.md             <- this file
|-- docker/
|   `-- Dockerfile
|-- .github/
|   `-- workflows/
|       `-- build-image.yml
`-- instruqt/
    |-- track.yml
    |-- config.yml
    |-- track_scripts/
    |   |-- setup-workshop       <- runs once at track start
    |   `-- cleanup-workshop     <- runs once at track end
    |-- 01-run-monolith/
    |   |-- assignment.md
    |   |-- setup-workshop
    |   |-- solve-workshop
    |   `-- cleanup-workshop
    |-- 02-service-contract/
    |-- 03-sync-handler/
    |-- 04-caller-swap/
    |-- 05-async-operations/
    |-- 06-updates/
    |-- 07-lifecycle/
    `-- 08-polyglot-demo/
```

The challenge directories are zero-padded with two digits and slug-cased,
matching the Tailscale workshop. The order is:

| #   | Challenge slug              | Course-plan chapter | Type      |
| :-- | :-------------------------- | :------------------ | :-------- |
| 01  | run-monolith                | Ch 1                | challenge |
| 02  | service-contract            | Ch 2                | challenge |
| 03  | sync-handler                | Ch 3                | challenge |
| 04  | caller-swap                 | Ch 4                | challenge |
| 05  | async-operations            | Ch 5                | challenge |
| 06  | updates                     | Ch 6                | challenge |
| 07  | lifecycle                   | Ch 7                | challenge |
| 08  | polyglot-demo               | Polyglot reinforce  | challenge |

The Comp 1 quiz from `course-plan.md` is **not** an Instruqt challenge per
the user's instruction. It will be delivered in slides (Live Event) and as
a callout block in the assignment.md preamble for Ch 1 (self-paced).

## track.yml

```yaml
slug: introduction-to-temporal-nexus
id: <generate-on-first-push>
title: Introduction to Temporal Nexus
teaser: Decouple a Temporal monolith into namespace-isolated services connected by a Nexus Endpoint. Layer in async operations, human-in-the-loop updates, cancellation, and a polyglot connector demo.
description: |-
  A 3.5-hour hands-on workshop introducing Temporal Nexus through a payment
  processing scenario. You will decouple a monolith into Payments and
  Compliance services running in separate namespaces, connect them with a
  Nexus Endpoint, then layer in asynchronous operations, human-in-the-loop
  updates, lifecycle controls (cancellation, errors, circuit breaker), and a
  polyglot connector demo where the same Service contract is fulfilled by a
  Java handler.
icon: ""
tags:
  - temporal
  - nexus
  - python
  - java
  - workflows
  - cross-namespace
  - integration-patterns
owner: temporal
developers:
  - mason.egger@temporal.io
idle_timeout: 7200   # 120 min idle ceiling, generous for Q&A pauses
timelimit: 16200     # 270 min = 4.5h, gives 1h headroom over the 3.5h plan
lab_config:
  extend_ttl: 900
  sidebar_enabled: true
  feedback_recap_enabled: true
  feedback_tab_enabled: true
  loadingMessages: true
  theme:
    name: modern-dark
  override_challenge_layout: true
  hideStopButton: false
  default_layout: AssignmentRight
  default_layout_sidebar_size: 40
```

The Tailscale workshop uses an identical `lab_config:` block. Cribbing it
keeps look-and-feel consistent across Temporal-authored Instruqt content.

## Track-level lifecycle scripts

Because the Docker image bakes the entire toolchain and source in,
track-level setup is **drastically simpler** than in either the Tailscale or
the versioning workshops. No apt-get, no curl, no git clone, no `uv sync`,
no `mvn package`, no `temporal server start-dev`. All of that happened at
image build time.

### `track_scripts/setup-workshop`

```bash
#!/bin/bash
set -euo pipefail

# Wait for Instruqt host bootstrap.
until [ -f /opt/instruqt/bootstrap/host-bootstrap-completed ]; do
    sleep 1
done

# Stage source into the attendee's writable working tree.
if [ ! -d /root/workshop ]; then
    cp -r /opt/workshop /root/workshop
fi

# Start the dev server in the background.
nohup temporal server start-dev \
    --ip 0.0.0.0 \
    --db-filename /root/temporal.db \
    --log-level warn \
    > /tmp/temporal-server.log 2>&1 &
echo $! > /tmp/temporal-server.pid

# Wait for it to accept gRPC connections.
echo "Waiting for Temporal dev server..."
for i in $(seq 1 60); do
    if temporal operator cluster health \
         --address 127.0.0.1:7233 >/dev/null 2>&1; then
        echo "Temporal server is ready."
        break
    fi
    sleep 1
done

# Pre-create namespaces. The dev server boots with only "default";
# the workshop uses payments-namespace and compliance-namespace from Ch 2 onwards.
temporal operator namespace create payments-namespace \
    --address 127.0.0.1:7233 || true
temporal operator namespace create compliance-namespace \
    --address 127.0.0.1:7233 || true

echo "==> Setup complete."
```

Heavy lifting (apt, mvn, uv sync) all happens at image build time. This
script just wires up the runtime: stage source, start the dev server,
create namespaces.

### `track_scripts/cleanup-workshop`

```bash
#!/bin/bash
set -euo pipefail
pkill -f "payments.worker"     || true
pkill -f "compliance.worker"   || true
pkill -f "ComplianceWorkerApp" || true
pkill -f "temporal server"     || true
```

One pkill call per pattern, not alternation. Per the user's standing memory
on macOS pkill, alternation is fragile; explicit per-pattern calls are
unambiguous on every platform. Track-level cleanup also kills the dev
server. Per-challenge cleanup scripts only kill workers, leaving the dev
server alive for the next challenge.

## Per-challenge structure

### Lifecycle scripts

Each code challenge ships **three** scripts (no `check-workshop` for the
Replay 2026 release):

| Script              | Behavior                                                                                       |
| :------------------ | :--------------------------------------------------------------------------------------------- |
| `setup-workshop`    | Reset the chapter's working tree from the baked-in source, kill any stragglers from the prior challenge, run any chapter-specific bootstrap (e.g. idempotent endpoint create from Ch 2 onward). |
| `solve-workshop`    | Copy the chapter's `solution/` over `exercise/` and run an end-to-end demonstration so downstream challenges see the expected state. |
| `cleanup-workshop`  | Kill payments and compliance workers (and the Java worker for Ch 8). Left intact: the dev server (track-level cleanup handles it). |

No `check-workshop` is intentional. The user explicitly said: skip-and-kill
is enough for Replay 2026; real validation can be added in a later
iteration. Instruqt's "Check" button (if surfaced) becomes a soft
pass-through: clicking it does nothing visible, the attendee proceeds when
ready.

### `setup-workshop` (per challenge) -- generic shape

```bash
#!/bin/bash
set -euxo pipefail
source /root/.bashrc

# Belt-and-braces: kill any workers the previous challenge's cleanup missed.
pkill -f "payments.worker"     || true
pkill -f "compliance.worker"   || true
pkill -f "ComplianceWorkerApp" || true

# Reset this chapter's working tree from the read-only baked-in source.
# Other chapters' working trees are left as the attendee left them.
CHAPTER=<this-chapter>            # e.g. 02_service_contract
SRC=/opt/workshop/exercises/$CHAPTER
DST=/root/workshop/exercises/$CHAPTER
rm -rf "$DST"
cp -r "$SRC" "$DST"

# Chapter-specific extras (idempotent endpoint create for Ch 2 onwards) go here.
```

Idempotent and safe to re-run if the attendee re-enters the challenge.

### `solve-workshop` pattern

```bash
#!/bin/bash
set -euxo pipefail
source /root/.bashrc

# Ensure no zombies are still polling task queues.
pkill -f "payments.worker"   || true
pkill -f "compliance.worker" || true
sleep 1

# Drop the chapter's solution over the exercise dir.
SOLUTION=/root/workshop/exercises/<chapter>/solution
EXERCISE=/root/workshop/exercises/<chapter>/exercise
cp -r "$SOLUTION/." "$EXERCISE/"

# Run the chapter's end-to-end starter and exit cleanly.
cd "$EXERCISE"
uv run python -m compliance.worker &
COMPLIANCE_PID=$!
uv run python -m payments.worker &
PAYMENTS_PID=$!
sleep 3

uv run python -m payments.starter

kill $COMPLIANCE_PID $PAYMENTS_PID 2>/dev/null || true
wait $COMPLIANCE_PID 2>/dev/null || true
wait $PAYMENTS_PID   2>/dev/null || true
```

`cp -r solution/. exercise/` overlays solution files without removing files
that are not in the solution.

Note that the `solve-workshop` is the **only** place workers get auto-started
in the entire track. During the regular flow, the attendee starts workers
themselves; `solve-workshop` exists for skip-ahead users who want to see
the chapter completed without doing it.

### `cleanup-workshop` (per challenge)

```bash
#!/bin/bash
set -euo pipefail
pkill -f "payments.worker"     || true
pkill -f "compliance.worker"   || true
pkill -f "ComplianceWorkerApp" || true
sleep 1
# Verify (per the user's pkill rule from lessons-learned).
ps aux | grep -E "(payments\.worker|compliance\.worker|ComplianceWorkerApp)" \
       | grep -v grep || true
```

The trailing `ps aux | grep` is a deliberate paranoia step: if a worker
survives the pkill (which has happened during testing per
`lessons-learned.md`), it shows up in the cleanup log so the next
challenge's `setup-workshop` knows what to chase.

## Tab layout

Per challenge, four to five tabs:

```yaml
tabs:
  - id: <random-12-char-id>
    title: Code Editor
    type: code
    hostname: workshop
    path: /root/workshop/exercises/<chapter>/exercise
  - id: <random-12-char-id>
    title: Compliance Worker
    type: terminal
    hostname: workshop
    workdir: /root/workshop/exercises/<chapter>/exercise
  - id: <random-12-char-id>
    title: Payments Worker
    type: terminal
    hostname: workshop
    workdir: /root/workshop/exercises/<chapter>/exercise
  - id: <random-12-char-id>
    title: Starter
    type: terminal
    hostname: workshop
    workdir: /root/workshop/exercises/<chapter>/exercise
  - id: <random-12-char-id>
    title: Temporal UI
    type: service
    hostname: workshop
    port: 8233
```

Notes:

- **Code Editor** scopes to the chapter's `exercise/` directory so the file
  tree stays tight. Other chapters' working trees exist on disk but are
  invisible to the editor view because `path:` is chapter-scoped.
- **Compliance Worker** and **Payments Worker** are separate terminal tabs so
  the attendee can read both workers' logs side-by-side without flipping
  shells. This is the primary reason a single container works for a "two
  teams" story.
- **Starter** is the third terminal, used for one-shot starter scripts and
  ad-hoc `temporal` CLI commands. Splitting it off the worker terminals lets
  attendees keep workers running while they start workflows.
- **Temporal UI** is a `service` tab with `hostname: workshop` and
  `port: 8233`. Instruqt proxies the local container port to the
  attendee's iframe. No reverse proxy needed; the dev server's UI does
  not set X-Frame-Options.

The Ch 1 (monolith) challenge needs only a Compliance + Payments distinction
inside one process, so the **Compliance Worker** tab is unused in Ch 1 (or
relabelled to "Logs"). Ch 8 (polyglot) reuses the Compliance Worker tab to
host the Java worker after the Python one is stopped.

## assignment.md authoring approach

This is the "more explanation in Instruqt than in READMEs" requirement. The
authoring rule:

> The assignment.md is the **single source of truth** that an attendee reads
> while doing the chapter. It must contain every piece of context the
> attendee needs that is not in the code itself. The slides are reinforcement
> in Live Event mode; the assignment.md must stand alone in self-paced mode.

Concretely, each `assignment.md` will include:

1. **Frontmatter:** challenge metadata (slug, id, type, title, teaser,
   notes, tabs, difficulty, timelimit). The `notes:` block in the right
   sidebar pre-frames the chapter for the attendee before they read the
   step-by-step body.

2. **Body Section: Why this chapter exists.** The lecture context that
   motivates the exercise. Pulled from `course-plan.md` competency framing
   and from the chapter's lecture activities. This is the part the README
   does not have.

3. **Body Section: What you will build.** A two-or-three bullet list of
   end-state criteria. Maps to the chapter's performance criteria from
   `course-plan.md`.

4. **Body Section: Steps.** Numbered, with inline `bash,run` blocks for
   commands and inline `python` blocks for code-edit "before / after"
   diffs. Step buttons reference tabs as
   `[button label="Compliance Worker" background="#444CE7"](tab-1)`.

5. **Body Section: Verify.** What the attendee should see in the Temporal
   Web UI or in the worker logs. Specific event names called out so the
   attendee can self-verify. (No automated `check-workshop` script for
   Replay 2026; the attendee uses these instructions to confirm by eye.)

6. **Body Section: Wrapping Up.** Bullet summary of what the attendee
   accomplished, then a forward-looking sentence into the next chapter.

The voice matches Tailscale's `01-hello-tailnet/assignment.md`: second person,
narrative, explanatory, with admonition blockquotes for caveats.

The Ch 1 assignment.md additionally includes a **knowledge-check callout**
that captures the four "secondary" Comp 1 quiz questions (multi-select,
two numerics) as a self-paced reading prompt, since the quiz is no longer
an Instruqt challenge. The Live Event delivery handles these via slide
polls.

### Length budget

Tailscale `assignment.md` files are 200 to 270 lines (8 to 14 KB). The Nexus
chapters are concept-heavier; budget 250 to 350 lines per chapter. Polyglot
is short (about 100 lines) because the code is pre-built.

### Reusing chapter README content

The existing per-chapter READMEs (in `workshop-nexus-intro-code/exercises/<n>/`)
are well-written and concept-rich. They are the kernel of each
`assignment.md`. The Instruqt version layers on:

- The "Why this chapter exists" preamble (drawn from `course-plan.md` and the
  lecture activities for that competency).
- Tab references and `bash,run` annotations for executable steps.
- Self-verification instructions (visual cues, event names to look for)
  that align with what a future `check-workshop` would have validated.
- A wrapping-up section pointing to the next chapter.

It is acceptable for the assignment.md to copy/paste prose from the README,
since the Instruqt version is what most attendees will read and the README
serves the local-first fallback path.

## Per-challenge plan

The build details for each challenge follow. Each subsection lists frontmatter
slug/teaser/timelimit, the chapter-specific setup steps, and any warnings.

### 01 -- `run-monolith`

- **Source:** `course-plan.md` Activity 1.3 ("Run the monolith and feel the problem").
- **Code:** `workshop-nexus-intro-code/exercises/01_run_monolith/solution/`
  (no `exercise/`, since this chapter has no TODOs; attendees just run it).
- **Teaser:** Run the payment processing monolith and observe the activity-style
  compliance check baked into the Payments Worker.
- **Difficulty:** basic. **Timelimit:** 600 seconds.
- **Setup:** copy `01_run_monolith` from `/opt/workshop`; set CWD to the
  solution dir.
- **Solve:** run worker + starter end-to-end and exit cleanly.
- **Cleanup:** kill workers.

### 02 -- `service-contract`

- **Source:** `course-plan.md` Activity 2.3.
- **Code:** `02_service_contract/`.
- **Teaser:** Define the `ComplianceNexusService` contract and create the Nexus Endpoint.
- **Difficulty:** basic. **Timelimit:** 1200 seconds.
- **Setup:** copy `02_service_contract`; namespaces are pre-created in
  track setup, so the attendee only creates the Endpoint in this chapter
  (the README's Part B "create namespaces" step becomes a "verify
  namespaces exist" step in the assignment.md).
- **Solve:** apply solution patches and run `temporal operator nexus
  endpoint create` for the attendee.
- **Cleanup:** kill workers.

### 03 -- `sync-handler`

- **Source:** `course-plan.md` Activity 3.3.
- **Code:** `03_sync_handler/`.
- **Teaser:** Implement the synchronous `check_compliance` Nexus handler and register it on the Compliance Worker.
- **Difficulty:** intermediate. **Timelimit:** 1800 seconds.
- **Setup:** copy `03_sync_handler`; idempotently re-create the Endpoint
  (`endpoint create ... || true`) in case the attendee skipped Ch 2 via
  solve.
- **Solve:** apply solution patches; run worker+starter end-to-end.
- **Cleanup:** kill workers.

### 04 -- `caller-swap`

- **Source:** `course-plan.md` Activity 4.3.
- **Code:** `04_caller_swap/`.
- **Teaser:** Swap the activity call to a Nexus call, drop compliance from the caller worker, and witness the two-event sync pattern in Event History.
- **Difficulty:** intermediate. **Timelimit:** 1500 seconds.
- **Setup:** copy `04_caller_swap`; idempotent endpoint create.
- **Solve:** apply solution patches; run worker+starter end-to-end.
- **Cleanup:** kill workers.

### 05 -- `async-operations`

- **Source:** `course-plan.md` Activity 5.4.
- **Code:** `05_async_operations/`.
- **Teaser:** Convert `check_compliance` to a workflow-backed async Operation and observe the three-event lifecycle.
- **Difficulty:** intermediate. **Timelimit:** 1500 seconds.
- **Setup:** copy `05_async_operations`; idempotent endpoint create.
- **Solve:** apply solution patches; run worker+starter end-to-end.
- **Cleanup:** kill workers.

### 06 -- `updates`

- **Source:** `course-plan.md` Activity 6.4.
- **Code:** `06_updates/`.
- **Teaser:** Add a human-review path to ComplianceWorkflow and propagate Workflow Updates through Nexus.
- **Difficulty:** advanced. **Timelimit:** 1800 seconds.
- **Special:** This is the chapter `lessons-learned.md` flags as the
  highest-friction. Plan the assignment.md with extra care: explicit
  troubleshooting block, plus a "what should I see in the worker logs"
  callout so attendees can self-diagnose without instructor intervention.
- **Setup:** copy `06_updates`; idempotent endpoint create.
- **Solve:** apply solution patches; run worker+starter+review_starter end-to-end.
- **Cleanup:** kill workers.

### 07 -- `lifecycle`

- **Source:** `course-plan.md` Activity 7.4.
- **Code:** `07_lifecycle/`.
- **Teaser:** Inject failure modes into the Nexus handler and observe cancellation, retryable errors, non-retryable errors, and the circuit breaker.
- **Difficulty:** advanced. **Timelimit:** 1500 seconds.
- **Setup:** copy `07_lifecycle`; idempotent endpoint create.
- **Solve:** apply solution patches; run lifecycle starter end-to-end.
- **Cleanup:** kill workers.

### 08 -- `polyglot-demo`

- **Source:** `course-plan.md` "Reinforcement: Polyglot Connector Demo".
- **Code:** `polyglot/java-legacy/` (Java) plus the Ch 7 solution state on the Python side.
- **Teaser:** Stop the Python compliance worker, start the pre-built Java compliance worker, and re-run the same Nexus operation. Same Service contract, different language, no Python code change.
- **Difficulty:** basic (no code edits). **Timelimit:** 600 seconds.
- **Setup:** copy `07_lifecycle/solution/` plus the polyglot tree; the Java
  JAR is already built (image build time).
- **Solve:** stop Python compliance worker, run
  `mvn -q exec:java@compliance-worker` in the polyglot dir, run
  `python -m payments.starter` for `TXN-A`, kill Java worker.
- **Cleanup:** kill Java worker (`pkill -f ComplianceWorkerApp`),
  do NOT auto-restart the Python compliance worker (the workshop ends here).

## Self-paced vs Live Event configuration

The `lab_config:` block in track.yml is identical for both modes. Live Event
features (instructor dashboard, real-time progress, hand-raising) are
**enabled at the Instruqt account / event level**, not in the track
definition. This means:

- One track definition serves both modes.
- Hot Start can be toggled on the event level in the Instruqt UI.
- Pausable Tracks can be toggled in the track UI (default: off in Live Event,
  on in self-paced).
- IP concurrency limits and invite claim caps are event-level configuration.

The plan is therefore **build once, deploy twice**: the same `instruqt/`
directory pushes to a Live Event invite for Replay and to a Self-paced
catalog entry for the public version. The only differences are the event
configuration in Instruqt's web UI.

## Local-first fallback

The Instruqt setup must remain compatible with the local-first fallback
described in `course-plan.md`:

- `uv sync` from the repo root.
- `temporal server start-dev`.
- `temporal operator namespace create payments-namespace` and
  `... compliance-namespace`.
- `temporal operator nexus endpoint create ...` from Ch 2 onwards.

Concretely: the per-challenge `setup-workshop` scripts must NOT do anything
that would prevent the same chapter from running outside Instruqt. Specifically
they must not write into the source tree (other than the `cp -r` from the
read-only `/opt/workshop`), must not depend on `INSTRUQT_*` environment
variables for correctness, and must not pre-fill any TODOs that the
attendee is supposed to complete.

The local-first runner is just a `make` target (or a `justfile`) at the
code repo root that mirrors what `track_scripts/setup-workshop` does. That
is a separate deliverable in the code repo.

## Build sequence (recommended)

1. **Dockerfile and GHA workflow.** Build the custom image and verify it
   pushes to GHCR successfully. Pull-and-run locally to confirm the baked
   uv venv and Java JAR work.
2. **Scaffold:** create `instruqt/` directory with `track.yml`, `config.yml`,
   `track_scripts/`, and empty challenge directories.
3. **Track-level setup script:** write and test the `setup-workshop` and
   `cleanup-workshop` scripts. Push a one-challenge stub track to confirm
   the dev server boots in-container and the Temporal UI tab renders.
4. **Ch 1 (monolith):** simplest challenge, no Nexus yet. Build assignment.md,
   setup, solve, cleanup. Push and dry-run.
5. **Ch 2 (service-contract):** first real Nexus chapter. Confirm namespace
   pre-creation works, Endpoint creation flow.
6. **Ch 3 through Ch 7:** build in sequence, each one inheriting state from
   the prior chapter's solution. Verify `solve-workshop` produces a clean
   downstream starting point.
7. **Ch 8 (polyglot):** last because it reuses Ch 7 solution state and
   exercises the Java worker startup.
8. **End-to-end run:** play through the entire track as a fresh attendee.
   Time each chapter; tune `timelimit` if a chapter runs long.
9. **Hot Start pool:** configure for Replay event.

Estimated build time: 3 to 5 days for one engineer who is fluent with
Instruqt and the Nexus code repo. The Docker image bake-in saves ~1 day
of setup-script iteration compared to the runtime-install approach.

## Open questions for the user

These are the remaining decisions. Some are resolved from the prior round.

### Resolved (from the user's last round of feedback)

- Single application container: yes.
- Quiz handling: outside Instruqt; not in the track.
- Polyglot: in. JDK and Maven baked into the custom image.
- Worker auto-start in setup: no. Attendee starts workers in every chapter.
- Private workshop-nexus-intro-code repo: bake into the Docker image at GHA
  build time using a fine-grained PAT secret.
- Java SDK pinning: any stable release with Nexus support. Plan currently
  proposes JDK 21 LTS for the runtime; SDK version pinned in
  `polyglot/java-legacy/pom.xml` to a recent stable release with Nexus
  support (verify exact version when polyglot is built).

### Resolved during scaffolding

- **In-process dev server, not sidecar.** While building the scaffolding
  the team discovered that the `containers[].command:` field this plan
  needed for the sidecar is **not in the public Instruqt docs**, and the
  Java hands-on workshop that inspired the sidecar pattern is actually
  using `virtualmachines:` with nested Docker. To avoid relying on
  undocumented Instruqt features, the implementation runs `temporal server
  start-dev` as a background process inside the single workshop container
  (versioning workshop pattern). config.yml is now a single `containers:`
  entry; track_scripts/setup-workshop launches the dev server with nohup
  and writes its PID to `/tmp/temporal-server.pid`.

- **GHCR image visibility: public.** Simplest path: anyone with the URL
  can `docker pull` and Instruqt does not need registry credentials. The
  workshop source baked into the image becomes world-readable via
  `docker cp`, which is acceptable since the workshop ships publicly
  post-Replay anyway. The **source** repo stays private; only the
  **image** is public. After the first GHA run, flip the package's
  visibility once in GitHub Packages settings:
  `Settings -> Packages -> workshop-nexus-intro-sandbox ->
  Change visibility -> Public`. After that flip it persists.

### Still open

1. **GHCR org / namespace.** The plan publishes to
   `ghcr.io/temporalio/workshop-nexus-intro-sandbox`. Confirm the owning
   org (`temporalio`, `temporal-community`, or another).

2. **Where does `docker/` and `.github/workflows/` live?**
   - Option A: in the workshop-nexus-intro repo (this one), as the plan
     currently proposes. Keeps slides + course plan + Instruqt definition
     + image-build pipeline together. Code repo stays focused on code.
   - Option B: in the workshop-nexus-intro-code repo. Keeps the image-build
     close to the source it bundles. But the workshop repo is what we
     edit when the Instruqt structure changes, so coupling them is
     inconvenient.
   - Recommendation: A. Confirm.

3. **Stable tag vs `main` for the source baked into the image.** Plan
   recommends a stable tag for Replay (e.g.
   `workshop-nexus-intro-code:v1.0.0-replay-2026`). Confirm tag scheme,
   and whether the GHA workflow should default to `main` for development
   builds and require a manual tag bump for releases.

4. **Python version: 3.13 (per the user's `lessons-learned.md` style note)
   or 3.12 (Ubuntu Jammy default, simpler image)?** Plan currently proposes
   3.13 via deadsnakes, matching the spirit of the `lessons-learned.md`
   tooling notes. 3.12 would shrink the image by ~50 MB. Confirm preference.

5. **Instructor "take control" workflow.** Live Event mode supports
   instructor screen-share / take-control. The plan does not require any
   special hooks for this, but `lessons-learned.md` flags Ch 6 (updates) as
   the chapter where instructor intervention is most likely. Should the
   `assignment.md` for Ch 6 include explicit "if you are stuck, raise your
   hand" callouts, and should `cleanup-workshop` for Ch 6 dump worker logs
   to `/tmp/ch6-debug.log` so the instructor can read them remotely on
   take-control?

## Risks and mitigations

| Risk                                                                 | Mitigation                                                                                  |
| :------------------------------------------------------------------- | :------------------------------------------------------------------------------------------ |
| Image size balloons (JDK + Maven + Python + uv venv + Maven cache + repo)        | Acceptable. Comparable images for Java workshops are ~1.5 GB. Instruqt pre-pulls images; first-pull cost is amortized across attendees in Hot Start. |
| Private repo PAT leakage in GHA logs                                | Use Docker BuildKit's `--secret` mount, or scope the PAT to single-repo Contents:Read and rotate post-event. |
| Attendee leaves a worker running across challenges and pollutes the next chapter's task queue | Per-challenge `cleanup-workshop` pkill; per-challenge `setup-workshop` belt-and-braces pkill; assignment.md callouts. |
| Dev server background process inside the workshop container conflicts with attendee shells or memory pressure | Versioning workshop has run this pattern reliably. 4 GB ceiling, `--log-level warn`, output goes to /tmp/temporal-server.log. PID tracked in /tmp/temporal-server.pid for targeted kill. |
| Image rebuild fails on a code-repo push and Instruqt sandbox starts serving stale exercises | GHA workflow runs on `repository_dispatch`; verify dispatch is wired before relying on it. Until then, manual workflow_dispatch is the trigger. |
| Java SDK Nexus support changes API between SDK releases             | Pin `temporal-sdk` Maven artifact to a specific version, not `LATEST`. Bump deliberately. |
| Instruqt's `code` tab editor cannot scope to a multi-root workspace | Single-root workspace per challenge is fine. The plan's per-challenge `path:` uses one directory. |
| Removing `check-workshop` means attendees can skip past unfinished work and break later challenges | `solve-workshop` is the safety net: clicking "Solve" applies the chapter's solution state so downstream challenges work even if the attendee skipped. Document this in the assignment.md preamble. |

## Appendix: schema cross-reference

A reminder of the Instruqt schema fields the plan relies on, with confirmed-vs-inferred status:

| Field                                       | Confirmed by docs?  | Confirmed by reference workshops? |
| :------------------------------------------ | :------------------ | :-------------------------------- |
| `containers:` block in `config.yml`         | Yes                 | Yes (versioning, java-hands-on)   |
| Single `containers:` entry, dev server in-process | Yes | Yes (versioning workshop)         |
| `containers[].memory`                       | Yes                 | No (versioning omits it)          |
| `containers[].image: ghcr.io/...`           | Yes (any image)     | Yes (java-hands-on)               |
| `track_scripts/setup-<hostname>`            | Yes                 | Yes (versioning, java-hands-on)   |
| `track_scripts/cleanup-<hostname>`          | Yes                 | Yes (versioning)                  |
| Per-challenge `setup-<hostname>`            | Yes                 | Yes (Tailscale, versioning)       |
| Per-challenge `solve-<hostname>`            | Yes                 | Yes (Tailscale)                   |
| Per-challenge `cleanup-<hostname>`          | Yes                 | Yes (java-hands-on)               |
| `tabs[].type: code/terminal/service`        | Yes                 | Yes (Tailscale)                   |
| `tabs[].id: <12-char>`                      | Inferred (Tailscale frontmatter) | Yes (Tailscale; docs do not mention `id` in the public ref) |
| `notes:` frontmatter block                  | Inferred (Tailscale frontmatter) | Yes (Tailscale)                   |
| `tabs[].hostname:` matching the local container name | Yes | Yes (Tailscale, versioning) |

Items marked "inferred" are the ones to verify first when scaffolding starts.
