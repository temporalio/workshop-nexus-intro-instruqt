---
layout: toc
current: wrap
---

---
layout: section
---

# Final Standings

ahaslides.com/O8RSE

<!--
- "Alright, final standings. The whole morning's points are on this board. Let's see who's taking it home."
- AhaSlides leaderboard: Final standings.
  - "First place, name. Second, name. Third, name. Big round of applause."
  - "If you missed the podium by one or two questions, that one was on slide [X]. Catch me at the booth if you want to argue."
- "Congratulations to the top three. Before you go, let's recap what you actually did this morning, then I want one specific commitment from each of you."
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
-->

---
layout: default
---

# Patterns We Didn't Cover Today

<v-clicks>

- **In-workflow cancellation with `asyncio.create_task`**: cancel a long-running Nexus Operation from inside a workflow without cancelling the whole workflow.
- **Handler cleanup with `asyncio.shield`**: cleanup runs even when the caller cancels.
- **Multi-handler endpoints**: one Endpoint serving multiple Service handlers.
- **Cross-region and cross-account on Temporal Cloud**: Nexus crosses namespaces. Crossing regions and accounts has more considerations.

</v-clicks>

<br>

<v-click>

All three patterns are in the SDK samples repos.

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
- **Build 4** Cross-region and cross-account on Temporal Cloud.
  - Nexus crosses namespaces. Cross-region and cross-account each have additional considerations.
  - docs.temporal.io/cloud/nexus is the entry point.
- **Build 5** All three patterns are in the SDK samples repos.
-->

---
layout: default
---

# What's Next for Nexus

<v-clicks>

- **Non-Workflow callers**: invoke Nexus Operations from bash, services, or any app. Today the caller must be a Workflow. That constraint is going away.
- **Contract-first development**: IDL definitions and code generation via [`nexus-rpc-gen`](https://github.com/nexus-rpc/nexus-rpc-gen). Define the Service once, generate handlers and stubs for every SDK.
- **Per-caller rate limiting and fine-grained authorization** on Nexus Endpoints. Matters when one Endpoint is shared by many internal teams.
- **Enhanced routing rules**: today one Endpoint targets one Namespace and one Task Queue. Richer routing is on the way.

</v-clicks>

<br>

<v-click>

Today's Workflow-to-Workflow case is one application of a broader durable-RPC story. The platform is leaning in.

</v-click>

<!--
- Source: Temporal's "The road ahead" section in the Nexus GA announcement (temporal.io/blog/temporal-nexus-now-available) and the Public Preview blog's "What's next" (temporal.io/blog/announcing-nexus-connect-temporal-applications-across-isolated-namespaces).
- **Build 1** **Non-Workflow callers**: invoke Nexus Operations from bash, services, or any app.
  - This is the biggest one for the room. "I have a non-Temporal service that wants to invoke a Workflow durably" is real and common. Today not supported. Roadmap, actively being built per Slack threads as of late 2025.
  - This is what makes today's "Workflow caller" requirement temporary. The Ch 1 slide already says "a way of invoking" rather than "a Workflow invoking" so it stays accurate when this lands.
- **Build 2** **Contract-first development** via nexus-rpc-gen.
  - For teams that prefer declarative IDL service definitions over decorator-on-class.
  - Define once, generate handlers and stubs across every SDK.
- **Build 3** **Per-caller rate limiting and fine-grained authorization.**
  - Operate-side. Matters when a Nexus Endpoint is shared by many internal teams.
- **Build 4** **Enhanced routing rules.**
  - Today: one Endpoint maps to one (Namespace, Task Queue). Future: more flexible routing.
- **Build 5** Today's Workflow-to-Workflow case is one application of a broader durable-RPC story. The platform is leaning in.
  - The "durable RPC" framing from Ch 1 generalizes here. Non-Workflow callers eliminate the last asterisk.
-->

---
layout: default
---

# Where to Go Next

<v-clicks>

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
- **Build 1** **Docs**: `docs.temporal.io/nexus`
  - The reference. Conceptual overview, API specs per SDK, FAQs.
- **Build 2** **Tutorial**: Java sync Nexus tutorial on learn.temporal.io
  - The published tutorial this workshop is built on top of.
  - Worth pointing at attendees who want to do the same thing in Java.
- **Build 3** **Samples**: `samples-python/nexus` and the equivalent in your SDK
  - Working code in every SDK. The fastest way to bootstrap a new project.
  - The samples-python repo has the cleanest Python examples.
- **Build 4** **Community**: `#nexus` channel in the Temporal Community Slack
  - SDK maintainers hang out there. So do early Nexus adopters.
  - Get an invite from temporal.io/slack if they don't already have one.
- **Build 5** Bring the contract you wrote today back to your team. Pick one cross-team call. Ship it through Nexus.
  - "Pick one call" is the right scope: not "rewrite your platform," just one call.
-->

---
layout: section
---

# Reflection

ahaslides.com/O8RSE

<!--
- "Three last questions on AhaSlides. The first one is the only one that matters for you, pick something specific to try when you get back to your team."
- AhaSlides brainstorm: "What will you try first when you get back to your team?"
  - "Even one word. 'Refunds.' 'KYC.' 'The Go service.' Pick one."
- AhaSlides scale 0-10: "Likelihood to recommend Nexus to a colleague."
- AhaSlides open-ended: "What still feels fuzzy?"
  - "Updates feels fuzzy? Let me give you the one-sentence summary right now."
  - "I'll address these in a follow-up post in the #nexus channel."
- "Thank you. Final slide, Q&A is open. I'm staying right here, and I'm at the booth all afternoon."
-->

---
layout: end
---

# Thank you for your time and attention

We welcome your feedback: **ahaslides.com/O8RSE**

<br>

**Mason Egger** | mason.egger@temporal.io

Questions, horror stories, or follow-ups: find me at the booth or in `#nexus` on Temporal Slack.

<!--
- "Thank you for your time and attention."
- "We welcome your feedback."
- "If your question takes more than two minutes, find me at the booth. I'm there all afternoon."
- "What's the first cross-team call you're going to put through Nexus when you get back?"
-->
