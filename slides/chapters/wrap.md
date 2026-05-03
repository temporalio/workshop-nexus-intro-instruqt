---
layout: toc
current: wrap
---

---
layout: section
---

# Final Standings

ahaslides.com/NEXUSWS

<!--
- "Alright, final standings. The whole morning's points are on this board. Let's see who's taking it home."
- "First place, name. Second, name. Third, name. Big round of applause."
- "If you missed the podium by one or two questions, catch me at the booth if you want to argue."
- "Congratulations to the top three. Before you go, let's recap what you actually did this morning, then I want one specific commitment from each of you."

## Teaching notes

- AhaSlides leaderboard: Final standings.
-->

---
layout: default
---

# Essential Points (1)

The shape of the integration:

<v-clicks>

- Cross-team Temporal integration needs cross-team Nexus Endpoints. **Namespaces become tenancy boundaries with real teeth.**
- A Nexus **Service** is a typed Python class both teams import. **Operations** are the typed methods on it.
- An **Endpoint** is a routing entry the operator creates with the Temporal CLI. Caller code names only the Endpoint.
- Service and Operation are **code-level**. Endpoint and Registry are **operator-level**.

</v-clicks>

<!--
- **Build 1** Cross-team Temporal integration needs cross-team Nexus Endpoints. Namespaces become tenancy boundaries with real teeth.
  - Namespaces are not "groupings" anymore; they are tenancy units.
- **Build 2** A Nexus Service is a typed Python class both teams import. Operations are the typed methods on it.
  - The contract is the integration.
- **Build 3** An Endpoint is a routing entry the operator creates with the Temporal CLI. Caller code names only the Endpoint.
  - DNS-entry mental model. The operator-side artifact.
- **Build 4** Service and Operation are code-level. Endpoint and Registry are operator-level.
  - Two halves of the responsibility.
-->

---
layout: default
---

# Essential Points (2)

The two handler shapes:

<v-clicks>

- **Synchronous handlers** run inline on the handler Worker, return a result directly, and must respond within a **10-second** per-request deadline.
- **Asynchronous handlers** return a `WorkflowHandle` to a workflow that produces the result. Up to **60 days** on Temporal Cloud.
- Choose sync when the work fits comfortably under five seconds. Choose async for everything else, especially anything that needs cancellation.
- Set all three timeouts (`schedule_to_close`, `schedule_to_start`, `start_to_close`) on every async caller. Use `WorkflowIDConflictPolicy.USE_EXISTING` for idempotent retries.

</v-clicks>

<!--
- **Build 1** Synchronous handlers run inline on the handler Worker, return a result directly, and must respond within a 10-second per-request deadline.
- **Build 2** Asynchronous handlers return a WorkflowHandle to a workflow that produces the result. Up to 60 days on Temporal Cloud.
- **Build 3** Choose sync when the work fits comfortably under five seconds. Choose async for everything else, especially anything that needs cancellation.
- **Build 4** Set all three timeouts on every async caller. Use `WorkflowIDConflictPolicy.USE_EXISTING` for idempotent retries.
  - The two production gotchas of async.
-->

---
layout: default
---

# Essential Points (3)

The Update path:

<v-clicks>

- A **Workflow Update** has two stages: a **validator** that reads state and raises, then a **handler** that writes state and returns.
- A sync Nexus handler that resolves a running workflow and forwards an Update is the canonical cross-team **"tell-a-running-workflow-X"** pattern.
- A short-lived caller workflow lets reviewers route human input through the same Service contract every other caller uses.
- The handler workflow's Event History records `WorkflowExecutionUpdateAccepted` and `WorkflowExecutionUpdateCompleted` for a successful Update.

</v-clicks>

<!--
- **Build 1** A Workflow Update has two stages: a validator that reads state and raises, then a handler that writes state and returns.
- **Build 2** A sync Nexus handler that resolves a running workflow and forwards an Update is the canonical cross-team "tell-a-running-workflow-X" pattern.
- **Build 3** A short-lived caller workflow lets reviewers route human input through the same Service contract every other caller uses.
- **Build 4** The handler workflow's Event History records `WorkflowExecutionUpdateAccepted` and `WorkflowExecutionUpdateCompleted` for a successful Update.
-->

---
layout: default
---

# Essential Points (4)

Production reflexes:

<v-clicks>

- Sync events on the caller: **Scheduled, Completed.** Async events: **Scheduled, Started, Completed.**
- Cancellation crosses the boundary automatically. Pick `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, or `WAIT_COMPLETED` based on what you need to wait for.
- `OperationError` is **permanent**. `HandlerError` is **transient** and retries with backoff.
- **5 consecutive retryable errors** on the same caller-Namespace and Endpoint pair open the circuit breaker for **60 seconds**.

</v-clicks>

<!--
- **Build 1** Sync events on the caller: Scheduled, Completed. Async events: Scheduled, Started, Completed.
- **Build 2** Cancellation crosses the boundary automatically. Pick the cancel type based on what you need to wait for.
- **Build 3** OperationError is permanent. HandlerError is transient and retries with backoff.
- **Build 4** 5 consecutive retryable errors on the same caller-Namespace and Endpoint pair open the circuit breaker for 60 seconds.
  - "Most circuit breaker trips in the wild are handler workers not running."
-->

---
layout: default
---

# Essential Points (5)

One contract, every SDK:

<v-clicks>

- The same Nexus Service contract serves a Python handler today and a Java handler tomorrow without a Python change.
- The wire format is HTTP-based and language-agnostic, anchored by **snake_case field names** on both sides.
- Multi-language teams can each pick the SDK that fits their domain and still cooperate through Nexus.
- **The contract is the integration.**

</v-clicks>

<!--
- **Build 1** The same Nexus Service contract serves a Python handler today and a Java handler tomorrow without a Python change.
- **Build 2** The wire format is HTTP-based and language-agnostic, anchored by snake_case field names on both sides.
  - The wire-level discipline that earns the "no Python change" claim.
- **Build 3** Multi-language teams can each pick the SDK that fits their domain and still cooperate through Nexus.
- **Build 4** The contract is the integration.

## Teaching notes

- Thesis-sentence reassertion. Per CLAUDE.md, "The contract is the integration." lands three times across the deck: Ch 1 ("From Weld to Contract"), Ch 2 ("Why Types Matter Here"), and here. Same vocabulary each time; the room remembers a sentence, not a section. Land it slowly.
- **Anecdotal close (verbal-only, optional).** If the room is engaged and pacing allows, anchor the thesis in production language without naming a customer: "Real Temporal teams are deleting their bespoke gateways and replacing them with this." Concrete pre-Nexus pain (anonymized): a multi-team org maintaining a custom gRPC reverse-proxy gateway just to glue workflows together; with Nexus, that gateway is decommissioned and every team's workflows talk over the same managed contract. Don't put company names on the slide. The contract-is-the-integration thesis is the takeaway; the production-pain framing is optional color.
-->

---
layout: default
---

# Patterns We Didn't Cover Today

<v-clicks>

- **In-workflow cancellation with `asyncio.create_task`**: cancel a long-running Nexus Operation from inside a workflow without cancelling the whole workflow.
- **Handler cleanup with `asyncio.shield`**: cleanup runs even when the caller cancels.
- **Multi-handler endpoints**: one Endpoint serving multiple Service handlers.
- **Standalone activities for unreliable external HTTP**: GA-imminent on Temporal Cloud. The right tool for wrapping flaky third-party APIs that would trip the Nexus circuit breaker.
- **Cross-region and cross-account on Temporal Cloud**: Nexus crosses namespaces. Crossing regions and accounts has more considerations.

</v-clicks>

<br>

<v-click>

The SDK samples repos cover the in-workflow patterns. **Standalone activities** ship alongside the Nexus features it pairs with.

</v-click>

<!--
- **Build 1** In-workflow cancellation with asyncio.create_task.
  - The pattern for cancelling a long-running Nexus Operation from inside a workflow without cancelling the whole workflow.
  - See samples-python.
- **Build 2** Handler cleanup with asyncio.shield.
  - Making handler cleanup work even when the caller has cancelled.
  - See samples-python.
- **Build 3** Multi-handler endpoints.
  - One Endpoint serving multiple Service handlers, registry-style routing.
- **Build 4** Standalone activities for unreliable external HTTP. GA-imminent on Temporal Cloud.
  - For wrapping flaky third-party APIs that would otherwise trip the Nexus circuit breaker if called directly from a sync handler.
  - Per Phil Prasek (lead PM, Nexus): "the only way to wrap arbitrary external HTTP calls that are not super rock solid in reliability is going to be using the standalone activities." Coinbase co-launch Wed 2026-05-06.
  - **Live-workshop hook (verbal-only):** "This becomes GA the day after this workshop, on Wednesday 2026-05-06." Memorable date the room can carry away. Co-launch with **Coinbase** (do not name them on the slide; the customer name lives in this note for delivery context only).
- **Build 5** Cross-region and cross-account on Temporal Cloud.
  - Nexus crosses namespaces. Cross-region and cross-account each have additional considerations.
  - docs.temporal.io/cloud/nexus is the entry point.
- **Build 6** The SDK samples repos cover the in-workflow patterns. Standalone activities ship alongside the Nexus features it pairs with.
  - In-workflow patterns are documented in samples-python and equivalent SDK repos. Standalone activities will follow the same publication path.
-->

---
layout: default
---

# What's Different on Temporal Cloud

The Service contract you wrote today works on both self-hosted and Cloud. The operator-side surface is where Cloud differs.

<v-clicks>

- **Per-Endpoint allowlist**: default-deny security on every Endpoint. Self-hosted relies on Namespace-level controls only.
- **mTLS Envoy mesh + audit logs**: Cloud-managed wire-level security and observability on every Nexus call.
- **Account-scoped Endpoints**: one Endpoint reachable from every Namespace in your Cloud account, governed by the allowlist. Self-hosted Endpoints are cluster-scoped.
- **HA Namespaces and cross-region routing**: cross-region and cross-account Nexus is a Cloud feature; self-hosted gets Nexus per cluster.
- **Production limits and Worker tuning**: the 60-day async ceiling and the 30 in-flight Operations per caller workflow are Cloud caps; self-hosted operators tune the same dials via dynamic config.

</v-clicks>

<!--
- The contract is portable. The Cloud differentiators sit on the operator surface (security, routing, ceilings), not the developer surface.
- **Build 1** Per-Endpoint allowlist.
  - Already covered as a Ch3 punchline. Reiterate here in the wrap context: this is the single biggest enterprise-security selling point of Cloud Nexus.
- **Build 2** mTLS Envoy mesh + audit logs.
  - Cloud manages the wire-level transport and gives you audit/metrics for free. Self-hosted teams build (or skip) this themselves.
- **Build 3** Account-scoped Endpoints.
  - Endpoint is global within an account. Self-hosted is global per cluster, which is different topology.
- **Build 4** HA Namespaces and cross-region routing.
  - Federated control plane is Cloud-only. Self-hosted clusters can do Nexus inside a cluster, but cross-cluster federation is not a feature.
- **Build 5** Production limits and Worker tuning.
  - Same dials, different defaults. Cloud locks the 60-day async ceiling; self-hosted can raise it via `component.nexusoperations.limit.scheduleToCloseTimeout`. Cloud caps in-flight Operations per caller workflow at 30 today.

## Teaching notes

- This slide exists per Phil Prasek's 2026-05-01 PM call: a wrap-side recap of the Cloud-specific Nexus differentiators that the workshop bumps into chapter by chapter (allowlist in Ch3, 60-day ceiling in Ch1/Ch5, the 30 cap in Ch5 Teaching notes).
- **Self-Service Portal pattern (verbal-only, optional).** The combination of account-scoped Endpoints + per-Endpoint allowlist is what makes the cross-namespace self-service portal pattern practical on Cloud. On self-hosted you can build the same shape but you'd assemble the security yourself. Mention if the room asks "is this a Cloud feature or a pattern?"
- **Project-scoped security (verbal-only, forward-looking).** Tighter project-level governance on top of the allowlist is on the roadmap. Mention only if asked; the exact shape is not yet documented.
- Cross-region/cross-account stays as a bullet in `Patterns We Didn't Cover Today` because it deserves its own pointer; the bullet here is the "what's the Cloud surface story" framing.
-->

---
layout: default
---

# What's Next for Nexus

<v-clicks>

- **Connectors**: inbound gateways and outbound connectors for HTTP, Kafka, MCP, and more. Lets non-Workflow callers join the durable-RPC story.
- **Agentic AI workflows over Nexus**: AI agents reach Nexus through the same durable-RPC contract. The MCP gateway is the entry point.
- **Contract-first development**: future IDL and CodeGen. Define the Service once, generate handlers and stubs for every SDK.
- **Per-caller rate limiting and fine-grained authorization** on Nexus Endpoints. Matters when one Endpoint is shared by many internal teams.
- **Enhanced routing rules**: today one Endpoint targets one Namespace and one Task Queue. Richer routing is on the way.

</v-clicks>

<br>

<v-click>

Today's Workflow-to-Workflow case is one application of a broader durable-RPC story. The platform is leaning in.

</v-click>

<!--
- **Build 1** Connectors: invoke Nexus Operations from any protocol via inbound gateways and outbound connectors. HTTP, Kafka, MCP, and more.
  - Mental model: an inbound gateway converts an HTTP / Kafka / MCP request into a Nexus Operation call. An outbound connector goes the other direction.
  - "I have a non-Temporal service that wants to invoke a Workflow durably" is real and common. The connector layer is how that lands. Roadmap, actively being built.
- **Build 2** Agentic AI workflows over Nexus.
  - The MCP gateway in the connector model is the entry point for agentic callers. An AI agent that needs to invoke a workflow durably reaches the same Nexus Service contract every team-to-team caller already uses.
  - Same observability story for agentic and traditional workflows; the polyglot chapter already touched this.
- **Build 3** Contract-first development: future IDL and CodeGen.
  - For teams that prefer declarative IDL service definitions over decorator-on-class.
  - Define once, generate handlers and stubs across every SDK.
- **Build 4** Per-caller rate limiting and fine-grained authorization.
  - Operator-side. Matters when a Nexus Endpoint is shared by many internal teams.
- **Build 5** Enhanced routing rules.
  - Today: one Endpoint maps to one (Namespace, Task Queue). Future: more flexible routing.
- **Build 6** Today's Workflow-to-Workflow case is one application of a broader durable-RPC story. The platform is leaning in.
  - The "durable RPC" framing from Ch 1 generalizes here. The connector layer eliminates the Workflow-only-caller asterisk.

## Teaching notes

- The connectors framing comes from Phil Prasek's 2026-05-01 PM call: "Think of it as an inbound gateway and an outbound connector, for HTTP, for Kafka, for MCP, etc, right? And then those basically make it easy to use Nexus services from other protocols."
- The Ch 1 slide already says "a way of invoking" rather than "a Workflow invoking" so it stays accurate when the connector layer ships.
- Standalone activities are a separate-but-related work stream (GA-imminent on Temporal Cloud, Coinbase co-launch). They are the canonical answer for unreliable external HTTP today; mention only if asked.
- **Standalone Activities vs Standalone Nexus Operations (verbal-only, easy to confuse).** These are different products.
  - **Standalone Activities** runs an Activity without a workflow (1 Cloud Action vs 2; the building block for outbound connectors that wrap unreliable external HTTP).
  - **Standalone Nexus Operations** invokes a Nexus Endpoint without a caller workflow (durably executed by Nexus Machinery; the building block for inbound connectors).
  - Standalone Activities lands first. Documented internal confusion point at Temporal; expect to clarify if attendees ask.
-->

---
layout: default
---

# See It in Production

The cross-namespace self-service pattern this workshop teaches, at production scale.

<v-clicks>

- **Replay 2026 talk** (Thursday 10:30 - 11:15 AM): [`replay.temporal.io/schedule/bottlenecks-self-service-duolingo-workflow-as-a-service-temporal-nexus`](https://replay.temporal.io/schedule/bottlenecks-self-service-duolingo-workflow-as-a-service-temporal-nexus)
- **Case study**: [`temporal.io/resources/case-studies/duolingo-temporal-nexus`](https://temporal.io/resources/case-studies/duolingo-temporal-nexus)

</v-clicks>

<!--
- This slide isolates the two production-grounded pointers so they get their own beat before the general resources list. Mason: "add it prominently."
- **Build 1** Replay 2026 talk: Workflow-as-a-Service in production.
  - Live, this week. "From Bottlenecks to Self-Service: How Duolingo Built Workflow-as-a-Service with Temporal Nexus" by Zhihao Wang (Staff Software Engineer, Duolingo). The conference talk version of the published case study; same shape, deeper detail. If the room is still on-site, point them at this talk explicitly.
- **Build 2** Case study.
  - The published Duolingo case study. Concrete numbers (30+ workflows shared across teams, hundreds of engineering hours saved), production architecture, the same Workflow-as-a-Service pattern this workshop teaches at smaller scale.

## Teaching notes

- Replay talk speaker is **Zhihao Wang**, Staff Software Engineer at **Duolingo**. Title: "From Bottlenecks to Self-Service: How Duolingo Built Workflow-as-a-Service with Temporal Nexus." Customer name lives in the URL slug and the speaker bio; the on-slide bullet text is topic-led.
- Case study reports 30+ workflows shared across teams, hundreds of engineering hours saved.
- This slide was split off from "Where to Go Next" because the two long URL slugs caused that slide's closing v-click to overflow. Splitting also gives the talk + case study the prominence Mason asked for.
-->

---
layout: default
---

# Where to Go Next

<v-clicks>

- **Evaluate**: [`temporal.io/nexus`](https://temporal.io/nexus)
- **Docs**: [`docs.temporal.io/nexus`](https://docs.temporal.io/nexus)
- **Temporal Cloud-specific Nexus**: [`docs.temporal.io/cloud/nexus`](https://docs.temporal.io/cloud/nexus). Cross-account and cross-region considerations.
- **Versioning**: Service contract changes are an additive-and-rollout problem. [`docs.temporal.io/worker-versioning`](https://docs.temporal.io/worker-versioning) helps on the workflow-code side.
- **Tutorial**: [Java sync Nexus tutorial on learn.temporal.io](https://learn.temporal.io/tutorials/nexus/nexus-sync-tutorial-java/)
- **Samples**: [`samples-python/nexus`](https://github.com/temporalio/samples-python) and the equivalent in your SDK
- **Community**: `#nexus` channel in the Temporal Community Slack

</v-clicks>

<br>

<v-click>

Bring the contract you wrote today back to your team. Pick one cross-team call. Ship it through Nexus.

</v-click>

<!--
- **Build 1** Docs: `docs.temporal.io/nexus`
  - The reference. Conceptual overview, API specs per SDK, FAQs.
- **Build 2** Temporal Cloud-specific Nexus: `docs.temporal.io/cloud/nexus`
  - Cross-account and cross-region considerations live here, not in the main Nexus docs.
- **Build 3** Versioning: Service contract changes are an additive-and-rollout problem.
  - `docs.temporal.io/worker-versioning` covers the workflow-code side. The Service-contract side follows the same playbook as gRPC or OpenAPI.
- **Build 4** Tutorial: Java sync Nexus tutorial on learn.temporal.io
  - The published tutorial this workshop is built on top of.
  - Worth pointing at attendees who want to do the same thing in Java.
- **Build 5** Samples: `samples-python/nexus` and the equivalent in your SDK
  - Working code in every SDK. The fastest way to bootstrap a new project.
  - The samples-python repo has the cleanest Python examples.
- **Build 6** Community: `#nexus` channel in the Temporal Community Slack
  - SDK maintainers hang out there. So do early Nexus adopters.
  - Get an invite from temporal.io/slack if they don't already have one.
- **Build 7** Bring the contract you wrote today back to your team. Pick one cross-team call. Ship it through Nexus.
  - "Pick one call" is the right scope: not "rewrite your platform," just one call.
-->

---
layout: section
---

# Reflection

ahaslides.com/NEXUSWS

<!--
- "Three last questions on AhaSlides. The first one is the only one that matters for you, pick something specific to try when you get back to your team."
- "Even one word. 'Refunds.' 'KYC.' 'The Go service.' Pick one."
- "Updates feels fuzzy? Let me give you the one-sentence summary right now."
- "I'll address these in a follow-up post in the #nexus channel."
- "Thank you. Final slide, Q&A is open. I'm staying right here, and I'm at the booth all afternoon."

## Teaching notes

- AhaSlides brainstorm trigger: "What will you try first when you get back to your team?"
- AhaSlides scale 0-10 trigger: "Likelihood to recommend Nexus to a colleague."
- AhaSlides open-ended trigger: "What still feels fuzzy?"
-->

---
layout: end
---

# Thank you for your time and attention

**Please take 30 seconds to share your feedback.** Scan the QR or open the link. It shapes the next workshop.

[**t.mp/replay26-ws-feedback**](https://t.mp/replay26-ws-feedback)

<br>

**Mason Egger** | mason@temporal.io

<img src="/exit-survey-feedack.png" alt="Workshop feedback QR code" class="feedback-qr" />

<style>
.feedback-qr {
  position: absolute;
  right: 3.5rem;
  bottom: 3.5rem;
  width: 14rem;
  height: 14rem;
  border-radius: 0.5rem;
}
</style>

<!--
- "Thank you for your time and attention."
- "Before you go, please take 30 seconds and fill out the feedback survey. Scan the QR or hit the URL. It genuinely shapes how I run this next time."
- "If your question takes more than two minutes, find me throughout the conference."
- "What's the first cross-team call you're going to put through Nexus when you get back?"
-->
