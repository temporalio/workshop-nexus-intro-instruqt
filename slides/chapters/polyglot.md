---
layout: toc
current: polyglot
---

---
layout: section
---

# Polyglot Connector

---
layout: default
---

# Same Contract, Different Language

<br>

The Compliance team rewrites their Worker in Java. We change **nothing** in Python.

<br>

<v-clicks>

- Stop the Python Compliance Worker.
- Start the pre-built Java Compliance Worker on the same task queue.
- Run `python -m payments.starter` and watch TXN-A.

</v-clicks>

<br>

<v-click>

TXN-A returns LOW and completes against a **Java-authored** workflow in `compliance-namespace`. We Ctrl+C after that; the Instruqt exercise covers the full A/B/C flow against the same Java handler.

</v-click>

<br>

<v-click>

What Java had to do to earn "no Python change": `@Operation(name = "snake_case_name")` on each method, and `@JsonProperty("snake_case_name")` on every dataclass field. Without both, Python's call fails with `NOT_FOUND` or `UnrecognizedPropertyException`. **The contract earns its claim through wire-level discipline, not magic.**

</v-click>

<!--
- This is the demo. Five minutes. Presenter-driven, not an exercise.
- The Compliance team rewrites their Worker in Java. We change **nothing** in Python.
  - Frame this as the company's evolution: a year from now, Compliance hired Java engineers.
  - The Python caller team has zero changes to ship.
- **Build 1** Stop the Python Compliance Worker.
  - In a terminal: `pkill -f "python -m compliance.worker"` (or your Instruqt control).
  - The Python and Java compliance workers cannot share `compliance-risk` safely; only one runs at a time.
- **Build 2** Start the pre-built Java Compliance Worker on the same task queue.
  - The Java worker is pre-built and on the `java-legacy` container. Start it via the Instruqt control.
  - Same task queue (`compliance-risk`), same namespace (`compliance-namespace`).
  - Same Endpoint (`compliance-endpoint`) routes to it.
- **Build 3** Run `python -m payments.starter` and watch TXN-A.
  - From the Chapter 7 solution directory. Same Python caller, no code changes.
  - Note: the starter runs all three transactions sequentially. TXN-A returns LOW and completes; TXN-B then blocks waiting for a `review` Update against the Java handler (just like Chapter 6 against the Python handler). For the live demo, **Ctrl+C after TXN-A's result block prints**, ahead of the TXN-B pause. The Instruqt exercise has attendees run `payments.review_starter` to see the full A/B/C flow against the Java handler.
- **Build 4** TXN-A returns LOW and completes against a **Java-authored** workflow in `compliance-namespace`.
  - Show the Web UI live. Filter compliance-namespace. Find `compliance-ch07-TXN-A` (the Java handler reuses the Ch 7 chapter prefix to stay consistent with the Python convention).
  - Inspect the workflow type or stack trace; it'll show Java metadata.
  - This is the punchline. Sell the surprise.
- About the Java handler:
  - Equivalent of Chapter 6 solution: workflow-backed check_compliance + review path.
  - MEDIUM still pauses for review. HIGH still declines. Same business behavior.
  - Lifecycle scenarios from Chapter 7 (TXN-FAIL-*, TXN-CIRCUIT-*) are out of scope: the Java handler doesn't implement the Python failure branches.
- Why no code changes? Because the Service contract is expressed in each SDK's native types.
  - Python dataclasses on one side, Java POJOs with `@JsonProperty` on the other.
  - Both serialize to the same snake_case JSON on the wire.
  - The Endpoint, the Service, the Operation names: identical.
- Run a poll right after this slide: AhaSlides slide 33 captures the surprise in real time.
-->

---
layout: default
---

# Why This Matters

<br>

<v-clicks>

- A team that prefers Java doesn't need a Python rewrite to integrate.
- A vendor library that ships in Go doesn't block a TypeScript adopter.
- An old service in JVM-land doesn't need a sidecar to talk to new Temporal apps. Wrap one method as a Nexus handler and let any new Temporal application in any SDK call it.
- **Agentic AI** workflows and traditional business workflows live under one observability story across the two codebases.

</v-clicks>

<br>

<v-click>

The Service contract is the universal interface. Every SDK speaks it.

</v-click>

<!--
- The strategic point. Why this matters for adopting Temporal in real organizations.
- **Build 1** A team that prefers Java doesn't need a Python rewrite to integrate.
  - Adoption story #1: language preference at the team level.
  - Each team picks the SDK that fits their existing skill set.
- **Build 2** A vendor library that ships in Go doesn't block a TypeScript adopter.
  - Adoption story #2: third-party integration.
  - Wrap the Go library in a Nexus handler. Call from TypeScript. Done.
- **Build 3** An old service in JVM-land doesn't need a sidecar to talk to new Temporal apps.
  - Adoption story #3: legacy modernization.
  - Old Java service exposes a Nexus handler. New apps in any SDK can call it.
  - No HTTP API, no protobuf schema, no sidecar process.
- **Build 4** The Service contract is the universal interface. Every SDK speaks it.
  - Strong landing line. The contract is the unlock.
  - This is the closing thought of the workshop's content. The wrap-up follows.
- Multi-language teams can each write in the language that fits, on the SDK that fits, and still cooperate through Nexus.
  - This is the unlock for adopting Temporal in a heterogeneous codebase without forcing a rewrite up front.
- Capture the surprise immediately on AhaSlides, that's the next transition.
-->

---
layout: section
---

# Reaction Time

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slides 33-34** (one poll, one word cloud, ~1 minute).
- These run **immediately after** the Java handler completes TXN-A. Capture the surprise in real time.
- **Lead-in**: "Java handler. Same Service contract. Same Endpoint. Same wire format. Zero changes in Python. Two quick questions on AhaSlides while it sinks in."
- **AhaSlides slide 33 (poll)**: "Reaction to the Java handler running the same Service contract?"
  - Lightweight emotional pulse. Read the breakdown out loud.
  - Look for "huh, that was easy" or "wait, really?" reactions; those are the ones worth amplifying.
- **AhaSlides slide 34 (word cloud)**: "What language would YOU bridge to Temporal next?"
  - This is **the strategic gold for booth conversations** afterward. Read 5-8 responses aloud.
  - Common responses: Go, Rust, .NET, Ruby, PHP, Kotlin, Scala.
  - Note any unusual ones; those are great post-workshop talking points.
- **Lead-out**: "Hold those answers in your head, find me at the booth if you want to talk about a specific bridge. Now let's wrap."
- After this transition, advance to the Wrap-Up section divider.
-->
