---
layout: toc
current: ch2
---

---
layout: section
---

# Warmup

ahaslides.com/NEXUSWS

<!--
- "Before I tell you what a Nexus Service is, I want to know what you already think a service contract is. One word."
- "We've got gRPC people, OpenAPI people, schema people. Good news: Nexus's contract is the same idea, expressed in your SDK's native types."
- "Hold those models in your head. We're about to use the same idea."

## Teaching notes

- AhaSlides word cloud trigger: "What does 'service contract' mean to you?"
-->

---
layout: default
---

# What Is a Nexus Service?

A named collection of Nexus Operations that one team exposes for others to call.

<v-clicks>

- In Python: a class decorated with `@nexusrpc.service`, with one typed `Operation[Input, Output]` per cross-team call.
- **One team owns the contract.** They define the surface, ship the implementation, and authorize callers through the Endpoint.
- Other teams import the contract types and call in. They depend on it; they don't change it.

</v-clicks>

<br>

<v-click>

In our workshop, **Compliance is the implementer** and owns `ComplianceNexusService`. Payments imports the types and calls through the Endpoint.

</v-click>

<!--
- **Build 1** In Python: a class decorated with `@nexusrpc.service`, with one typed `Operation[Input, Output]` per cross-team call.
  - Java uses `@Service` annotations. Go uses constants. .NET uses interfaces. Same idea, different surface.
  - Operations are type annotations on the class body. No `def`, no body. Just `name: nexusrpc.Operation[Input, Output]`.
- **Build 2** **One team owns the contract.** They define the surface, ship the implementation, and authorize callers through the Endpoint.
  - Authorization is a real Nexus mechanism. The Endpoint has an allowlist of caller Namespaces. By default, no callers are allowed at all. The owning team decides who gets in.
- **Build 3** Other teams import the contract types and call in. They depend on it; they don't change it.
  - Type-safety dependency, not authority. They use the contract's `Input` and `Output` types so their caller code is typed.
  - The owning team has the only write access. Other teams open PRs against it like they would for any service team.
- **Build 4** **Compliance is the implementer** and owns `ComplianceNexusService`. Payments imports the types and calls through the Endpoint.
  - The Service is named after the team that owns it; the name signals authority.
  - Compliance writes the contract, writes the implementation, registers the Endpoint, and decides Payments is allowed to call. Payments' write access is exactly zero.

## Teaching notes

- Authorization claim sources from `docs.temporal.io/nexus/security` ("No callers are allowed by default").
- A previous draft had a "Lives in source control" Build here; that bullet doesn't appear on this slide. The point lives on the next slide ("Where the Contract Lives").
- Caller-defines-contract is a known but unusual pattern (e.g., a backoffice team owning a proto and per-country integrators implementing it). Mention only if asked; it isn't the workshop's case.
- The Python implementation is one realization of the concept. The workshop teaches Python because that's the lab language, not because the concept is Python-specific.
-->

---
layout: default
---

# The Contract Is the Product

Similar to **gRPC**, **OpenAPI**, or **Avro**.

<v-clicks>

- A typed surface the owner publishes and consumers depend on
- Versioned, reviewable, breakable in a code review
- Defined first. Both sides build to it.

</v-clicks>

<br>

<v-click>

A Nexus **Service** is that contract, expressed in your SDK's native types.

</v-click>

<!--
- **Build 1** A typed surface the owner publishes and consumers depend on
  - The contract is the interface. Consumers depend on it the same way they'd depend on a gRPC service definition.
- **Build 2** Versioned, reviewable, breakable in a code review
  - Lives in source control. Diffs are reviewable. Breaking changes show up in PR.
  - Same change-management story you already have for protobuf or OpenAPI specs.
- **Build 3** Defined first. Both sides build to it.
  - Contract-first discipline. The owner defines the shape, then both teams build their halves in parallel.
  - Same advice you'd give for any cross-team API.
- **Build 4** A Nexus Service is that contract, expressed in your SDK's native types.
  - No code generation step. Just Python (or Java, or Go).
  - "Native types" does not mean "single language." The wire format is JSON, you can also use proto defs, and Nexus rides the same data converters as the rest of Temporal. Polyglot is first-class — the Python contract on this slide can be implemented by a Java handler tomorrow without a Python change.
-->

---
layout: default
---

# Defining the Nexus Service

```python {all|1|3-5|6|7|all}
import nexusrpc

@nexusrpc.service
class ComplianceNexusService:
    """Owned by Compliance. Imported by Payments."""
    check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]
    submit_review:    nexusrpc.Operation[ReviewRequest,    ComplianceResult]
```

<br>

<v-clicks>

- A class. No methods. Just typed Operation declarations.
- Each `Operation[Input, Output]` is one cross-team call.
- This file is **imported by both teams.** Payments calls it; Compliance implements it.

</v-clicks>

<style>
.slidev-layout pre.shiki,
.slidev-layout pre code {
  font-size: 1.20rem;
  line-height: 1.35;
}
</style>

<!--
- **Build 1 (whole code)** The full Service definition.
- **Build 2 (line 1, import)** `import nexusrpc`
  - The Python package. Comes from the same `nexusrpc` library that ships with the Temporal SDK.
- **Build 3 (lines 3-5, decorator + class)** `@nexusrpc.service` on `class ComplianceNexusService`
  - The decorator marks this class as a Service definition.
  - The class is named after the team's domain ("Compliance"), not after the caller.
- **Build 4 (line 6, check_compliance Operation)** `check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]`
  - Operation type signature. Input type, output type. That's the contract for one call.
  - No `def`. No body. Just a type annotation. The class never instantiates.
- **Build 5 (line 7, submit_review Operation)** `submit_review: nexusrpc.Operation[ReviewRequest, ComplianceResult]`
  - Second Operation. Both share the `ComplianceResult` output type.
  - `ReviewRequest` is the input type for the human-review submission Operation.
- **Build 6 (whole code again)**
- **Build 7 (sub-bullet)** A class. No methods. Just typed Operation declarations.
  - The world's most boring class. The whole point is that it's pure shape.
- **Build 8 (sub-bullet)** Each `Operation[Input, Output]` is one cross-team call.
  - One Operation = one call. Add an Operation = add a call. Remove = remove. Versionable.
- **Build 9 (sub-bullet)** This file is **imported by both teams.** Payments calls it; Compliance implements it.
  - Both sides depend on the same Python file. That file is the contract.
  - Compliance writes a handler against it; Payments creates a client from it.
  - The dataclasses (ComplianceRequest, ComplianceResult, ReviewRequest) are also shared.
- This is the entire contract. There is no other config file. This Python class is it.
-->

---
layout: default
---

# Where the Contract Lives

<v-clicks depth="2">

- **Contract**: `shared/service.py`. Both teams import it for type safety.
- **Domain types**: live with the team that owns the data. 
  - `compliance.models` for compliance dataclasses. 
  - `shared.models` for cross-team types like `ReviewRequest`.
- **Versioning**: Additive change is safe; breaking change needs both teams' coordination.
- **Hand-written today.** Future IDL and CodeGen are coming.

</v-clicks>

<br>

<v-click>

Breaking changes require both teams to agree. **That is the boundary.**

</v-click>

<!--
- **Build 1** Contract: shared/service.py. Both teams import it for type safety.
  - The directory layout is intentional. Not under `payments/`, not under `compliance/`. A third location.
  - Strictly, only the implementer needs the contract to register handlers. Callers can call by string name. We import on both sides because the typed shape is the whole point.
- **Build 2** Domain types live with the team that owns the data.
  - `compliance.models.ComplianceRequest` and `ComplianceResult`: Compliance owns those shapes.
  - `shared.models.ReviewRequest`: cross-team type, lives in shared.
  - Each team owns the shapes they introduced.
- **Build 3** Versioning is the same conversation you already have for gRPC or OpenAPI.
  - Additive: add an Operation, add a field. Both teams roll out at their own pace.
  - Breaking: rename or remove. Two-team coordination required. Same playbook as protobuf or OpenAPI.
- **Build 4** Hand-written today. Future IDL and CodeGen are coming.
  - Today: hand-write the Service class in your SDK's native types, both teams import it.
  - Future: an IDL plus a CodeGen tool that generates handlers and stubs across every SDK. Roadmap; not how you do it in 2026.
- **Build 5** Breaking changes require both teams to agree. That is the boundary.

## Teaching notes

- Worker Versioning helps with the workflow-code side; Service contract change is a multi-team API rollout. Different problem; mention only if students conflate them.
- The "future IDL + CodeGen" wording is intentional per Phil Prasek (lead PM, Nexus): do not name the project (`nexus-rpc-gen`) on the slide because the spec story is being reshaped around connectors. "Future IDL and CodeGen" stays accurate regardless of how the underlying tooling lands.
-->

---
layout: default
---

# Why Types Matter Here

<v-clicks>

- **Type-checked on both sides.** Bad inputs and wrong return types fail at CI, not at deploy.
- **Refactor safely.** Rename a field, the type checker shows every reference.
- **Wire format is implied.** Same dataclass, same JSON, same payload across SDKs.

</v-clicks>

<br>

<v-click>

The contract is not metadata. It **is** the integration.

</v-click>

<!--
- **Build 1** Type-checked on both sides. Bad inputs and wrong return types fail at CI, not at deploy.
  - The doc-canonical claim: type safety when invoking, plus the type system ensures handlers fulfill the contract.
  - Add a required field to `ComplianceResult`, the handler's return type fails type-check on Compliance's side. Drop a field the caller depends on, the call site fails on Payments' side. Mismatches surface in CI, both sides.
- **Build 2** Refactor safely. Rename a field, the type checker shows every reference.
  - Cross-team rename is a real risk. The contract is the search index that makes it tractable.
- **Build 3** Wire format is implied. Same dataclass, same JSON, same payload across SDKs.
  - This is the bullet that makes the polyglot demo work.
  - Java handler uses Jackson `@JsonProperty` annotations to align with Python's snake_case dataclasses. Both produce the same JSON. Same Service contract, two languages.
- **Build 4** The contract is not metadata. It is the integration.
  - Once both teams have the contract, they can ship in parallel.

## Teaching notes

- The previous slide's "without the contract" line lives here as a verbal anchor, not on the slide: "the JSON shape lives in a wiki, the wire format drifts on review fatigue, and the failure mode is 'production at 3am realizes Compliance renamed `risk_level` to `risk`.'"
- The slide's three bullets all map to doc-canonical claims (per `docs.temporal.io/develop/python/nexus/quickstart` and the equivalent Java/Go/TS/.NET pages): "type safety when invoking Nexus Operations and ensures that operation handlers fulfill the contract." Polyglot wire format is from the per-SDK feature guides under "Define Nexus Service contract."
- "Caller-side autocomplete" was dropped. Autocomplete is an IDE feature downstream of type annotations, not a Nexus virtue.
- Versioning trivia for Q&A: contract is versionable. Additive change is safe; breaking change requires owner-team coordination. Already covered on the previous slide.
-->

---
layout: section
---

# Quiz Time

ahaslides.com/NEXUSWS

<!--
- "Quick check before you write the contract yourselves. One question, drag the steps into order."
- "Got it? Good. Now go write it. Switch over to Instruqt, you have 12 minutes."

## Teaching notes

- AhaSlides correct order trigger: "Put the steps for defining a Nexus Service in the right order."
- Expected order: import nexusrpc → declare class → add `@nexusrpc.service` decorator → declare typed Operations.
-->

---
layout: exercise
minutes: 12
heading: Exercise 2
---

**Define the Service contract.**

You will write the typed Python contract that both teams import, then
register a Nexus Endpoint that routes calls to the Compliance team.

Full instructions are in the Instruqt tab.

<!--
- "Define the Service contract."
  - Lightweight on purpose. One file. One decorator. Two type annotations.
- Open `shared/service.py`. Decorate `ComplianceNexusService` with `@nexusrpc.service` and declare two typed Operations.
  - `check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]`
  - `submit_review: nexusrpc.Operation[ReviewRequest, ComplianceResult]`

## Teaching notes

- The file already exists in the lab with the class skeleton. The student's job is to add the decorator and two `Operation[...]` annotations.
- Lightweight on purpose: we want the contract in their hands quickly so the rest of the workshop can build on it.
-->

---
layout: default
---

# Review

<v-clicks>

- A Nexus **Service** is a typed Python class decorated with `@nexusrpc.service`
- Each **Operation** is `Operation[Input, Output]` — one cross-team call
- The contract lives in shared source; both teams import it for type safety
- Domain types live with the team that owns the data
- **The contract is the integration.**

</v-clicks>

<!--
- **Build 1** A Nexus Service is a typed Python class decorated with `@nexusrpc.service`.
- **Build 2** Each Operation is `Operation[Input, Output]` — one cross-team call. No methods on the class.
- **Build 3** The contract lives in shared source; both teams import it for type safety.
- **Build 4** Domain types live with the team that owns the data.
- **Build 5** The contract is the integration.
  - Thesis-sentence reassertion. Per CLAUDE.md, this lands at Ch 1 ("From Weld to Contract") close, Ch 2 close (here), and again at the wrap.
-->

---
layout: section
---

# Break

15 minutes — back at 10:00

<!--
- "Quick break before we go hands-on with the sync handler. 15 minutes."
- "Restroom, coffee, walk around. We come back at 10:00 to wire up the Compliance handler and create the Nexus Endpoint."

## Teaching notes

- This is the first of two breaks. After this, Block 2 runs Ch 3 + Ch 4 + Ch 5 back-to-back (75 minutes of active building) before Halftime + Break at 11:15.
- No leaderboard here. Leaderboard moments are at Halftime (after Ch 5) and Final Standings (at the wrap).
- If Ch 2's Exercise 2 ran long, eat into this break before letting it eat into Ch 3.
-->

