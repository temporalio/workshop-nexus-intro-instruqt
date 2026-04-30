---
layout: toc
current: ch2
---

---
layout: section
---

# 02 / The Service Contract

---
layout: section
---

# Warmup

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slide 13** (word cloud, ~30 seconds).
- This warmup runs **before** the lecture content for Ch2. Anchors the new concept to prior models (gRPC, OpenAPI, Avro) before we name them.
- **Lead-in**: "Before I tell you what a Nexus Service is, I want to know what you already think a service contract is. One word."
- **AhaSlides slide 13 (word cloud)**: "What does 'service contract' mean to you?"
  - Watch for: gRPC, OpenAPI, Swagger, IDL, schema, Avro, protobuf, API spec.
  - Read 4-6 responses aloud. Highlight the diversity: "We've got gRPC people, OpenAPI people, schema people. Good news: Nexus's contract is the same idea, expressed in your SDK's native types."
- This is intentionally a lightweight warmup. Just one slide. Don't over-engineer it.
- **Lead-out**: "Hold those models in your head. We're about to use the same idea. Back to slides."
- After this transition, advance to "The Contract Is the Product."
-->

---
layout: default
---

# What Is a Nexus Service?

<br>

A Python class decorated with `@nexusrpc.service`.

<v-clicks>

- One typed `Operation` annotation per cross-team call.
- Both teams **import it.** Neither team **owns it.**
- Lives in source control. Has no UI surface.
- The world's most boring class. That is the goal.

</v-clicks>

<br>

<v-click>

It is the **interface**. Compliance ships an implementation. Payments builds a stub. Both halves depend on this one file.

</v-click>

<!--
- Definition slide. Names the primitive in this workshop's vocabulary before the gRPC analogy slide hits.
- A Python class decorated with @nexusrpc.service.
  - Concrete. Not an abstract concept.
- **Build 1** One typed Operation annotation per cross-team call.
  - Operations are type annotations on the class body. No def, no body. Just `name: nexusrpc.Operation[Input, Output]`.
- **Build 2** Both teams import it. Neither team owns it.
  - This is the structural fact. Lives in `shared/` in this workshop, owned by neither team.
- **Build 3** Lives in source control. Has no UI surface.
  - The Web UI doesn't show it. There is no admin panel. It is just Python.
  - The Endpoint has a UI surface (the description rendered as Markdown). The Service does not.
- **Build 4** The world's most boring class. That is the goal.
  - The whole point is that it's pure shape. No behavior.
- **Build 5** It is the interface. Compliance ships an implementation. Payments builds a stub. Both halves depend on this one file.
  - This is the contract-first thesis. The next two chapters live inside it.
- After this slide, the gRPC/OpenAPI/Avro analogy lands harder because the room has a concrete picture of what the Nexus Service is.
-->

---
layout: default
---

# The Contract Is the Product

<br>

If you've worked with **gRPC**, **OpenAPI**, or **Avro**, you already know this idea.

<v-clicks>

- A typed surface that both teams agree on
- Versioned, reviewable, breakable in a code review
- The thing you ship before you ship anything else

</v-clicks>

<br>

<v-click>

A Nexus **Service** is that contract, expressed in your SDK's native types.

</v-click>

<!--
- If you've worked with **gRPC**, **OpenAPI**, or **Avro**, you already know this idea.
  - Anchor on things the audience has touched. Most rooms have all three covered.
  - Quick show of hands: "Who's used gRPC? OpenAPI?" gets the room engaged.
- **Build 1** A typed surface that both teams agree on
  - The contract is the **interface**. Both teams depend on it the same way they'd depend on a gRPC service definition.
- **Build 2** Versioned, reviewable, breakable in a code review
  - Lives in source control. Diffs are reviewable. Breaking changes show up in PR.
  - Same change-management story you already have for protobuf or OpenAPI specs.
- **Build 3** The thing you ship before you ship anything else
  - Contract-first is the workflow: agree on the shape, then the two teams implement in parallel.
  - This is the same advice you'd give for any cross-team API.
- **Build 4** A Nexus **Service** is that contract, expressed in your SDK's native types.
  - This is the punchline. No separate IDL. No code generation step. Just Python (or Java, or Go).
  - The same wire format works across SDKs because the SDKs all serialize their native types to the same JSON.
- The Service contract is not "another thing to learn." It's the same idea you already know, with the friction removed.
-->

---
layout: default
---

# `@nexusrpc.service` in One Slide

<br>

```python {all|1|3-5|6|7|all}
import nexusrpc

@nexusrpc.service
class ComplianceNexusService:
    """The shared contract between Payments and Compliance."""
    check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]
    submit_review:    nexusrpc.Operation[ReviewRequest,    ComplianceResult]
```

<br>

<v-clicks>

- A class. No methods. Just typed Operation declarations.
- Each `Operation[Input, Output]` is one cross-team call.
- This file is **imported by both teams.** Payments calls it; Compliance implements it.

</v-clicks>

<!--
- Five-build click-through. Whole-code-then-zoom-in pattern.
- **Build 1 (whole code)** The full Service definition appears.
  - Read it left to right once. Then we'll zoom in.
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
- **Build 6 (whole code again)** Pull back out for the closing bullets.
- **Build 7 (sub-bullet)** A class. No methods. Just typed Operation declarations.
  - "It's the world's most boring class." Hammer that. The whole point is that it's pure shape.
- **Build 8 (sub-bullet)** Each `Operation[Input, Output]` is one cross-team call.
  - One Operation = one call. Add an Operation = add a call. Remove = remove. Versionable.
- **Build 9 (sub-bullet)** This file is **imported by both teams.** Payments calls it; Compliance implements it.
  - Both sides depend on the same Python file. That file is the contract.
  - Compliance writes a handler against it; Payments creates a client from it.
  - The dataclasses (ComplianceRequest, ComplianceResult, ReviewRequest) are also shared.
- This is the entire contract. There is no other config file. There is no IDL. This Python class is it.
-->

---
layout: default
---

# Where the Contract Lives

<br>

<v-clicks>

- **Contract**: `shared/service.py`. Both teams import it.
- **Domain types**: live with the team that owns the data. `compliance.models` for compliance dataclasses. `shared.models` for cross-team types like `ReviewRequest`.
- **Versioning**: same conversation you already have for gRPC or OpenAPI. Additive change is safe; breaking change needs both teams' coordination.
- **Codegen alternative**: prefer IDL? `nexus-rpc-gen` exists. The hand-written contract this workshop uses is the more common shape.

</v-clicks>

<br>

<v-click>

Neither team can change the contract unilaterally. **That is the boundary.**

</v-click>

<!--
- Where ownership lives. Answers a question the room will ask.
- **Build 1** Contract: shared/service.py. Both teams import it.
  - The directory layout is intentional. Not under `payments/`, not under `compliance/`. A third location.
  - Forces a conversation when either team wants to change it.
- **Build 2** Domain types live with the team that owns the data.
  - `compliance.models.ComplianceRequest` and `ComplianceResult`: Compliance owns those shapes.
  - `shared.models.ReviewRequest`: cross-team type, lives in shared.
  - Pattern: each team owns the shapes they introduced.
- **Build 3** Versioning is the same conversation you already have for gRPC or OpenAPI.
  - Additive: add an Operation, add a field. Both teams roll out at their own pace.
  - Breaking: rename or remove. Two-team coordination required. Same playbook as protobuf or OpenAPI.
  - Worker Versioning helps with the workflow-code side; Service contract change is a multi-team API rollout.
- **Build 4** Codegen alternative: prefer IDL? nexus-rpc-gen exists.
  - For the room that wants schema-first generation, the option is there.
  - For everyone else, hand-written typed Python is the more common shape and what this workshop uses.
- **Build 5** Neither team can change the contract unilaterally. That is the boundary.
  - The structural intent. Code-as-contract is the enforcement mechanism.
- This is a 45-60 second slide. Don't get into version-bump war stories; just plant the principle.
-->

---
layout: default
---

# Why Types Matter Here

<br>

<v-clicks>

- **Caller-side autocomplete.** Payments engineers see `ComplianceResult` fields without reading Compliance code.
- **Compile-time mismatch.** Change the `Operation` signature, both sides break loudly in CI.
- **Wire format is implied.** Same dataclass, same JSON, same payload shape across SDKs.
- **Without the contract:** the JSON shape lives in a wiki, the wire format drifts on review fatigue, and the failure mode is "production at 3am realizes Compliance renamed `risk_level` to `risk`."

</v-clicks>

<br>

<v-click>

The contract is not metadata. It **is** the integration.

</v-click>

<!--
- Lean into the typing argument. Without typed Operations, the cross-team boundary becomes "read the wiki, hope you got the JSON right."
- **Build 1** **Caller-side autocomplete.** Payments engineers see `ComplianceResult` fields without reading Compliance code.
  - Open VSCode, hit dot, see the fields. That's the developer experience.
  - The contract becomes self-documenting at the IDE level.
- **Build 2** **Compile-time mismatch.** Change the `Operation` signature, both sides break loudly in CI.
  - Add a required field to `ComplianceResult`, the Payments-side `await ... .execute_operation` line still type-checks (because the result is consumed), but a missing field on the handler return type fails Compliance's CI.
  - Mismatches surface in CI, not in production at 3am.
- **Build 3** **Wire format is implied.** Same dataclass, same JSON, same payload shape across SDKs.
  - This is the bullet that makes the polyglot demo work.
  - Java handler uses Jackson `@JsonProperty` annotations to align with Python's snake_case dataclasses.
  - Both produce the same JSON on the wire. Same Service contract, two languages.
- **Build 4** **Without the contract:** the JSON shape lives in a wiki, the wire format drifts on review fatigue, and the failure mode is "production at 3am realizes Compliance renamed `risk_level` to `risk`."
  - Land the self-deprecation under your breath: "and we all know engineers are great at keeping wikis up to date, right." 🤣
  - Drop into dramatic-ellipsis on the wince beat: "Until someone changes the format of the event…. ….and they didn't know you were ingesting that event…." Some of the room has lived this exact 3am page.
- **Build 5** The contract is not metadata. It **is** the integration.
  - Strong landing line. The contract IS the integration. There's nothing else.
  - **Key point:** this is the second exposure of the workshop's thesis sentence. First exposure was on the welcome "What Is Nexus?" slide. The third exposure lives in the wrap.
  - Once both teams have the contract, they can ship in parallel.
- The contract is also versionable: add an Operation, both sides see it. Remove an Operation, both sides break loudly. Standard SemVer hygiene applies.
-->

---
layout: section
---

# Quiz Time

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slide 14** (correct order, graded, ~45 seconds).
- This is one slide, but it's graded. Allow an extra beat for reading the steps.
- **Lead-in**: "Quick check before you write the contract yourselves. One question, drag the steps into order."
- **AhaSlides slide 14 (correct order)**: "Put the steps for defining a Nexus Service in the right order."
  - The expected order: import nexusrpc → declare class → add `@nexusrpc.service` decorator → declare typed Operations.
  - If they trip on this, they'll trip on TODO 1 in the exercise. This is the gating concept.
- After the timer, walk through the correct order on screen. Tie each step back to the code on the previous slide.
- **Lead-out**: "Got it? Good. Now go write it. Switch over to Instruqt, you have 12 minutes."
- After this transition, advance to Exercise 2 card and ship them to Instruqt.
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
- 12 minute exercise. First TODO of the workshop.
- "Define the Service contract."
  - Lightweight on purpose. One file. One decorator. Two type annotations.
- Open `shared/service.py`. Decorate `ComplianceNexusService` with `@nexusrpc.service` and declare two typed Operations.
  - The file already exists with the class skeleton. Their job is to add the decorator and two `Operation[...]` annotations.
  - `check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]`
  - `submit_review: nexusrpc.Operation[ReviewRequest, ComplianceResult]`
- That's TODO 1 in the Instruqt tab.
  - The Instruqt `check` script greps the file for `@nexusrpc.service` and the two Operation lines.
  - If they're stuck on dataclass imports, point them at the existing imports at the top of the file.
- Why so short? Because we want the contract in their hands quickly so the rest of the workshop can build on it.
- After they finish, advance straight into Chapter 3. The Ch2 AhaSlides activities (slides 13-14) already ran before this exercise.
-->
