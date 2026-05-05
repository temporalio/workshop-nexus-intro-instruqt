---
layout: toc
current: polyglot
---

---
layout: default
---

# Same Contract, Different Language

The Compliance team rewrites their Worker in Java. We change **nothing** in Python.

<v-clicks>

- Stop the Python Compliance Worker.
- Start the pre-built Java Compliance Worker on the same task queue.
- Run `python -m payments.starter` and watch TXN-A.

</v-clicks>

<v-click>

TXN-A returns LOW against a **Java-authored** workflow in `compliance-namespace`. Same caller, same contract.

</v-click>

<v-click>

What Java has to do: `@Operation(name = "snake_case_name")` on methods, `@JsonProperty(...)` on fields. **Wire-level discipline, not magic.**

</v-click>

<!--
- The Compliance team rewrites their Worker in Java. We change nothing in Python.
  - A year from now, Compliance hired Java engineers.
  - The Python caller team has zero changes to ship.
- **Build 1 -** Stop the Python Compliance Worker.
  - In a terminal: `pkill -f "python -m compliance.worker"` (or your Instruqt control).
  - The Python and Java compliance workers cannot share `compliance-risk` safely; only one runs at a time.
- **Build 2 -** Start the pre-built Java Compliance Worker on the same task queue.
  - The Java worker is pre-built and on the `java-legacy` container.
  - Same task queue (`compliance-risk`), same namespace (`compliance-namespace`).
  - Same Endpoint (`compliance-endpoint`) routes to it.
- **Build 3 -** Run `python -m payments.starter` and watch TXN-A.
  - From the Chapter 7 solution directory. Same Python caller, no code changes.
- **Build 4 -** TXN-A returns LOW and completes against a Java-authored workflow in `compliance-namespace`.
  - In the Web UI, filter compliance-namespace. Find `compliance-ch07-TXN-A` (the Java handler reuses the Ch 7 chapter prefix to stay consistent with the Python convention).
  - The workflow type or stack trace will show Java metadata.
- **Build 5 -** What Java had to do to earn "no Python change": `@Operation(name = "snake_case_name")` on each method, and `@JsonProperty("snake_case_name")` on every dataclass field. Without both, Python's call fails with `NOT_FOUND` or `UnrecognizedPropertyException`. The contract earns its claim through wire-level discipline, not magic.
  - The wire-level rule: snake_case names on both sides, every field, every method.

## Teaching notes

- The starter runs all three transactions sequentially. TXN-A returns LOW and completes; TXN-B then blocks waiting for a `review` Update against the Java handler (just like Chapter 6 against the Python handler). For the live demo, Ctrl+C after TXN-A's result block prints, ahead of the TXN-B pause. The Instruqt exercise has attendees run `payments.review_starter` to see the full A/B/C flow against the Java handler.
- About the Java handler: equivalent of Chapter 6 solution (workflow-backed `check_compliance` + review path). MEDIUM still pauses for review. HIGH still declines. Same business behavior. Lifecycle scenarios from Chapter 7 (TXN-FAIL-*, TXN-CIRCUIT-*) are out of scope: the Java handler doesn't implement the Python failure branches.
- Why no code changes? Because the Service contract is expressed in each SDK's native types. Python dataclasses on one side, Java POJOs with `@JsonProperty` on the other. Both serialize to the same snake_case JSON on the wire. The Endpoint, the Service, the Operation names are identical.
-->

---
layout: default
---

# Why This Matters

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
- **Build 1 -** A team that prefers Java doesn't need a Python rewrite to integrate.
  - Each team picks the SDK that fits their existing skill set.
- **Build 2 -** A vendor library that ships in Go doesn't block a TypeScript adopter.
  - Wrap the Go library in a Nexus handler. Call from TypeScript. Done.
- **Build 3 -** An old service in JVM-land doesn't need a sidecar to talk to new Temporal apps.
  - Old Java service exposes a Nexus handler. New apps in any SDK can call it.
  - No HTTP API, no protobuf schema, no sidecar process.
- **Build 4 -** Agentic AI workflows and traditional business workflows live under one observability story across the two codebases.
  - Same Service contract, same Endpoint surface, same Event History shape. One observability story regardless of which codebase the work runs in.
- **Build 5 -** The Service contract is the universal interface. Every SDK speaks it.

## Teaching notes

- Multi-language teams can each write in the language that fits, on the SDK that fits, and still cooperate through Nexus. This is the unlock for adopting Temporal in a heterogeneous codebase without forcing a rewrite up front.
- **Anecdotal close (verbal-only).** The polyglot demo isn't just a feature; it's the proof that you can replace a custom integration layer (a bespoke gRPC reverse-proxy gateway maintained just to glue workflows together) with a managed service contract. Multiple Temporal customers in the field — multi-microservice orgs, multi-language platforms, enterprise integrators — are explicitly deprecating their bespoke gateways once they adopt Nexus. The Java handler swap you just watched is the same shape. Mention if the room has built or is maintaining a custom gateway; do not name the customer on the slide.
-->

---
layout: section
---

# Reaction Time

ahaslides.com/NEXUSWS

<!--
- **AhaSlides live 33 to 34** (one poll + one word cloud, neither graded).
- "Java handler. Same Service contract. Same Endpoint. Same wire format. Zero changes in Python. Two quick questions on AhaSlides while it sinks in."
- AhaSlides live 33, poll: "Reaction to the Java handler running the same Service contract?"
- AhaSlides live 34, word cloud: "What language would YOU bridge to Temporal next?" Common responses: Go, Rust, .NET, Ruby, PHP, Kotlin, Scala.
- "Hold those answers in your head, find me at the booth if you want to talk about a specific bridge. Now let's wrap."
-->
