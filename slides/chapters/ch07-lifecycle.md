---
layout: toc
current: ch7
---

---
layout: default
---

# Four Ways Off the Happy Path

A successful Operation flows `Scheduled -> Started -> Completed`.

<v-clicks>

A Nexus Operation can also leave the happy path **four** ways:

- **Non-retryable failure** (`OperationError`)
- **Retryable failure** (`HandlerError`, with backoff)
- **Cancellation** (propagating from the caller through the Endpoint to the handler workflow)
- **Circuit breaker** (5 retryable errors in a row, breaker opens for 60s)

</v-clicks>

<br>

<v-click>

Each leaves a distinct trace in the caller's Event History or `temporal workflow describe`. **The chapter teaches you to recognize each one in production.**

</v-click>

<!--
- A successful Operation flows Scheduled to Started to Completed.
  - This is the happy path you saw with TXN-A in Chapter 5.
- **Build 1 -** A Nexus Operation can also leave the happy path four ways.
- **Build 2 -** Non-retryable failure (`OperationError`).
  - The first off-ramp. Permanent business-reason failure.
- **Build 3 -** Retryable failure (`HandlerError`, with backoff).
  - The second off-ramp. Transient infrastructure problem.
- **Build 4 -** Cancellation (propagating from the caller through the Endpoint to the handler workflow).
  - The third off-ramp. The caller decides to stop.
- **Build 5 -** Circuit breaker (5 retryable errors in a row, breaker opens for 60s).
  - The fourth off-ramp. The platform stops trying.
- **Build 6 -** Each leaves a distinct trace in the caller's Event History or `temporal workflow describe`.
  - Production reflex: when something is wrong, you should know which of the four modes you're looking at.

## Teaching notes

- The chapter is dense but the framing is simple: four modes, four traces, four production reflexes.
- The exercise is mostly observation: see each mode in the UI and CLI.
-->

---
layout: default
---

# Cancellation Crosses the Boundary

When a caller Workflow is canceled, the in-flight Nexus Operation cancels too.

<br>

<v-clicks>

- The platform sends cancellation through the Endpoint.
- The handler workflow receives `CancelledError` at its next `await`.
- Both sides end in the **Canceled** state.

</v-clicks>

<br>

<v-click>

You don't write any plumbing for this. You **choose how long to wait**.

</v-click>

<!--
- When a caller Workflow is canceled, the in-flight Nexus Operation cancels too.
  - Cancellation crosses the namespace boundary automatically.
  - This is one of the things Nexus gives you that ad-hoc HTTP integration doesn't.
- **Build 1 -** The platform sends cancellation through the Endpoint.
  - Same path as the original call, in reverse direction. The Endpoint is the only routing surface.
- **Build 2 -** The handler workflow receives `CancelledError` at its next `await`.
  - Standard Workflow cancellation. The handler workflow can catch it, do cleanup, then re-raise.
- **Build 3 -** Both sides end in the **Canceled** state.
  - Caller: Canceled. Handler workflow: Canceled. Symmetric.
  - In the exercise: caller workflow `payment-ch07-TXN-CANCEL-1` and handler workflow `compliance-ch07-TXN-CANCEL-1` both Canceled.
- **Build 4 -** You don't write any plumbing for this. You **choose how long to wait**.
  - The platform handles the wire-level propagation.
  - What you control is the **cancellation type**: do we wait for acknowledgement? Or move on?
-->

---
layout: default
---

# Pick Your Cancel

| Type                | Caller waits until...                        | Use when                                  |
| :------------------ | :------------------------------------------- | :---------------------------------------- |
| `ABANDON`           | nothing, returns immediately                 | Caller is being torn down                 |
| `TRY_CANCEL`        | the cancel is **delivered**                  | Want guaranteed delivery, not result      |
| `WAIT_REQUESTED`    | the handler **acknowledges** the cancel      | Mid-strict: need a receipt                |
| `WAIT_COMPLETED`    | the handler **finishes** (canceled or done)  | Strictest: shutdown order matters         |

<v-click>

Default is `WAIT_COMPLETED`. Strictest, slowest, safest.

</v-click>

<v-click>

**Sync Operations cannot be cancelled.** They hold no operation token. Only async, workflow-backed handlers support cancellation.

</v-click>

<style>
.slidev-layout table { font-size: 1.1rem; }
.slidev-layout th, .slidev-layout td { padding: 0.3rem 0.6rem; }
</style>

<!--
- Four levels of strictness. ABANDON is least strict; WAIT_COMPLETED is most strict.
- `ABANDON`: caller waits for **nothing**. Returns immediately. Use when the caller is being torn down anyway.
  - "Fire-and-forget cancel."
  - The handler may run to completion; the caller doesn't care.
- `TRY_CANCEL`: caller waits until the cancel is **delivered**.
  - You have a receipt that the cancel was sent. You don't have a receipt that the handler heard it.
- `WAIT_REQUESTED`: caller waits until the handler **acknowledges** the cancel.
  - The handler has registered the cancellation request. Cleanup may still be running.
- `WAIT_COMPLETED`: caller waits until the handler **finishes** (canceled or done).
  - Strictest, slowest, safest. Use when shutdown order matters (e.g., before retrying).
- **Build 1 -** Default is `WAIT_COMPLETED`. The strictest, the slowest, the safest.
  - Default exists because most callers want correctness over speed.
  - Override the default explicitly when you know the trade-off.
- **Build 2 -** Decision flowchart: do you need a result, just delivery, handler ack, or handler completion?
  - Walk the four branches in order. Each one drops one level of strictness.
- **Build 3 -** Sync Nexus Operations cannot be cancelled. They hold no operation token. Only async, workflow-backed handlers support cancellation.
  - Cancellation rides on the operation token. No token, no cancellation surface.
- **Build 4 -** Wire-format aside: at the proto layer, `WAIT_REQUESTED` is named `WAIT_CANCELLATION_REQUESTED`.
  - Replay output and raw event payloads use the longer form. Your code uses the shorter SDK-side name.

## Teaching notes

- Practical examples for the room:
  - For a caller workflow that's terminating, ABANDON: don't make the shutdown wait.
  - For a payment that needs to know the compliance check truly stopped before retrying, WAIT_COMPLETED.
  - For a UI that shows a "canceling..." state, TRY_CANCEL or WAIT_REQUESTED gives a faster confirmation.
-->

---
layout: default
---

# Two Error Types, Two Behaviors

```python {all|1-3|5-7|all}
# Permanent failure. No retry. Fails the Operation.
raise nexusrpc.OperationError("blocked by sanctions list")

# Transient failure. Retries with backoff.
raise nexusrpc.HandlerError("downstream KYC API timed out")
```

<v-clicks>

- **OperationError**: caller sees `NexusOperationFailed` immediately. Workflow ends `Failed`.
- **HandlerError**: caller sees `Pending Nexus Operations`, growing attempts, `BackingOff` state.

</v-clicks>

<v-click>

Same model as Activity errors. `OperationError` ≈ `ApplicationError(non_retryable=True)`; `HandlerError` ≈ regular retrying exception.

</v-click>

<style>
.slidev-layout pre.shiki,
.slidev-layout pre code { font-size: 1.0rem; line-height: 1.3; }
</style>

<!--
- The error model maps to the Activity error model. Non-retryable + retryable.
- **Build 1 (whole code) -** Both error types side by side.
- **Build 2 (lines 1-3, OperationError) -** `raise nexusrpc.OperationError("blocked by sanctions list")`
  - **Permanent** failure. No retry. Fails the Operation immediately.
  - Use for business-reason failures. "This payment is blocked by sanctions and will never succeed."
  - Analogue of Activity's `ApplicationError(non_retryable=True)`.
- **Build 3 (lines 5-7, HandlerError) -** `raise nexusrpc.HandlerError("downstream KYC API timed out")`
  - **Transient** failure. Retries with exponential backoff.
  - Use for infrastructure problems. "The downstream API is timing out, but it usually works."
  - Analogue of Activity's regular exceptions, which retry by default.
- **Build 4 (whole code) -**
- **Build 5 -** **OperationError**: caller sees `NexusOperationFailed` immediately. Workflow ends in `Failed`.
- **Build 6 -** HandlerError: caller sees `Pending Nexus Operations` with growing attempt count, `BackingOff` state.
- **Build 7 -** Activity-error analogy. The room already knows the Activity error model. Bridge the analogy explicitly.
- The HandlerError type taxonomy (BAD_REQUEST etc.) and the "raise INTERNAL for BAD_REQUEST" production warning live on the next slide ("HandlerError Types") since the table doesn't fit here.

## Teaching notes

- If the handler is a workflow, failures can also come from the handler workflow itself failing (workflow-level), separate from `HandlerError` raised inside the Nexus handler. Both surface in the caller's history.
-->

---
layout: default
---

# HandlerError Types

`HandlerError` carries a **type**. Retryability follows the type (default/untrapped error is `INTERNAL`):

| Non-retryable | Retryable |
| :--- | :--- |
| `BAD_REQUEST` | `RESOURCE_EXHAUSTED` |
| `UNAUTHENTICATED` | `INTERNAL` |
| `UNAUTHORIZED` | `UNAVAILABLE` |
| `NOT_FOUND` | `UPSTREAM_TIMEOUT` |
| `NOT_IMPLEMENTED` | |

<v-click>

Picking the right type is API design. **Raise `INTERNAL` for what is actually `BAD_REQUEST` and callers retry forever** on something that will never succeed.

</v-click>

<style>
.slidev-layout table { font-size: 1.15rem; }
.slidev-layout th, .slidev-layout td { padding: 0.3rem 0.6rem; }
</style>

<!--
- The error model maps to the Activity error model. Non-retryable + retryable.
- **Build 1 (whole code) -** Both error types side by side.
- **Build 2 (lines 1-3, OperationError) -** `raise nexusrpc.OperationError("transaction blocked by sanctions list")`
  - **Permanent** failure. No retry. Fails the Operation immediately.
  - Use for business-reason failures. "This payment is blocked by sanctions and will never succeed."
  - Analogue of Activity's `ApplicationError(non_retryable=True)`.
- **Build 3 (lines 5-7, HandlerError) -** `raise nexusrpc.HandlerError("downstream KYC API timed out")`
  - **Transient** failure. Retries with exponential backoff.
  - Use for infrastructure problems. "The downstream API is timing out, but it usually works."
  - Analogue of Activity's regular exceptions, which retry by default.
- **Build 4 (whole code) -**
- **Build 5 -** **OperationError**: caller sees `NexusOperationFailed` immediately. Workflow ends in `Failed`.
  - Single event in the caller's history: `NexusOperationFailed`. No retry attempts.
  - The caller workflow `Failed` state shows up in the Web UI.
- **Build 6 -** HandlerError: caller sees `Pending Nexus Operations` with growing attempt count, `BackingOff` state.
  - The Operation goes into `BackingOff` between retries.
  - `temporal workflow describe -w <caller-id>` shows attempt count climbing: 1, 2, 3, ...
  - Same exponential backoff pattern as Activity retries.
- **Build 7 -** Activity-error analogy. `OperationError` is `ApplicationError(non_retryable=True)`. `HandlerError` is the regular Activity exception that retries by default.
  - The room already knows the Activity error model. Bridge the analogy explicitly so they don't have to learn a second one.
- **Build 8 -** `HandlerError` carries a type. Retryability follows the type.
  - Walk the table: `BAD_REQUEST`, `UNAUTHENTICATED`, `UNAUTHORIZED`, `NOT_FOUND`, `NOT_IMPLEMENTED` are non-retryable; `RESOURCE_EXHAUSTED`, `INTERNAL`, `UNAVAILABLE`, `UPSTREAM_TIMEOUT` retry.
- **Build 9 -** Picking the right type is API design. Raise `INTERNAL` for what is actually `BAD_REQUEST` and callers retry forever on something that will never succeed.
  - The most expensive error-handling bug is "we miscategorized a permanent failure as transient". Pick the type with intent.

## Teaching notes

- If the handler is a workflow, failures can also come from the handler workflow itself failing (workflow-level), separate from `HandlerError` raised inside the Nexus handler. Both surface in the caller's history.
-->

---
layout: default
---

# Spotting a Circuit-Breaker Trip

When the breaker opens, here's what it looks like in production.

<br>

<v-clicks>

- **The diagnostic surface.** `temporal workflow describe -w <caller-id>` shows `Pending Nexus Operations` with `State: Blocked` and `BlockedReason: The circuit breaker is open.`
- **Recovery is passive.** You don't reset the breaker. The platform half-opens after 60 seconds and probes; fix the underlying handler and the probe succeeds.

</v-clicks>

<br>

<v-click>

**Most circuit-breaker trips in the wild are not buggy handlers. They are handler Workers that are not running.** The Worker pool scaled to zero, the deploy failed, the pod crashed. Five timed-out requests in a row, and the breaker opens.

</v-click>

<!--
- The mechanism (5 errors on a pair, 60s open, half-open probe) was the dedicated Ch3 slide. Here we look at what a trip surfaces as in operations.
- **Build 1 -** The diagnostic surface.
  - `temporal workflow describe -w <caller-id>` is where this lands. `Pending Nexus Operations` shows the row, `State: Blocked` is the giveaway, `BlockedReason: The circuit breaker is open.` is the explicit string to grep for.
  - This is one of those features you discover during an incident. Recognizing the message saves debugging time.
- **Build 2 -** Recovery is passive.
  - You don't reset the breaker. The platform half-opens after 60 seconds and probes.
  - Probe success: closed, normal traffic resumes. Probe failure: another 60s open.
  - Fix the underlying problem and the breaker takes care of itself.
- **Build 3 -** Most trips in the wild are handler Workers not running.
  - Worker pool scaled to zero, deploy failed, pod crashed. Five timed-out requests in a row and the breaker opens.
  - This reflex is the same one we landed in Ch3. Reiterating here because it's the production-reflex line worth landing twice.

## Teaching notes

- The Ch3 slide owns the model (state machine, scope, trigger). This slide owns the diagnostic surface and the recovery story.
- Source for `BlockedReason` string: `docs.temporal.io/nexus/operations#circuit-breaking`.
- Reiteration of the "Workers not running" reflex from Ch3 is intentional per `feedback-reiterate-not-duplicate`.
-->

---
layout: exercise
minutes: 12
heading: Exercise 7
---

**Inject failures. Watch the lifecycle.**

You will inject non-retryable, retryable, cancellation, and circuit-breaker
scenarios into the Compliance handler, then run a lifecycle starter and
observe each one in the Web UI and `temporal workflow describe`.

Full instructions are in the Instruqt tab.

<!--
- "Inject failures. Watch the lifecycle."

## Teaching notes

- One TODO. Attendees are mostly here to see what each lifecycle scenario looks like in the UI and CLI.
- TODO 13: In the handler, branch on `transaction_id` to raise `OperationError`, `HandlerError`, or trigger cancellation. The exercise scaffold has the branching skeleton. Their job is to fill in the raises. For example: `if input.transaction_id.startswith("TXN-FAIL-OP"): raise nexusrpc.OperationError(...)`.
- Run `python -m payments.lifecycle_starter` to drive each scenario. The lifecycle starter runs CANCEL, FAIL-OP, FAIL-HANDLER, and CIRCUIT scenarios back-to-back. Each scenario starts a workflow with a `transaction_id` that triggers the corresponding handler branch.
- Observe in the Web UI, then in `temporal workflow describe`:
  - Cancel: caller workflow `payment-ch07-TXN-CANCEL-1` and handler workflow `compliance-ch07-TXN-CANCEL-1` both end in `Canceled` state.
  - OperationError: caller's history shows `NexusOperationFailed` event immediately, workflow ends `Failed`.
  - HandlerError: caller's `Pending Nexus Operations` shows attempt count growing, `State: BackingOff`.
  - Circuit breaker: after ~5 of these, new Operations on that endpoint show `State: Blocked` and `BlockedReason: The circuit breaker is open.`
- Most will get through the cancel + OperationError; the rest are gravy.
-->

---
layout: section
---

# Quiz Time

ahaslides.com/NEXUSWS

<!--
- **AhaSlides live 28 to 31** (final graded block, 4 questions). **Live 32 is the Ch 7 leaderboard, the last regular standings before the Polyglot demo.**
- "Last graded block of the workshop. Four questions. Lock in those production reflexes."
- AhaSlides live 28, match pairs (graded): "Pick your Cancel: match each cancellation type to its scenario."
  - ABANDON to "Caller is shutting down; don't wait at all"
  - TRY_CANCEL to "Wait until the cancel is delivered to the handler"
  - WAIT_REQUESTED to "Wait until the handler acknowledges the cancel"
  - WAIT_COMPLETED to "Wait for the handler to exit cleanly"
- AhaSlides live 29, pick answer (graded): "OperationError vs HandlerError: which one triggers automatic retry?" Correct: **HandlerError**. (OperationError is permanent / business reason; HandlerError is transient / infra. Same model as Activity errors.)
- AhaSlides live 30, pick answer (graded): "You see 'State: Blocked / BlockedReason: The circuit breaker is open' in `temporal workflow describe`. What's happening?" Correct: **5+ consecutive errors hit on this caller-namespace + endpoint pair; the breaker is shedding load**.
- AhaSlides live 31, pick answer (graded): "After how many consecutive errors does the circuit breaker open?" Correct: **5**.
- AhaSlides live 32, leaderboard: standings after Ch 7. The last regular standings; final celebration leaderboard at live 35.
- "Last graded block done. Final scoring is locked in. One quick recap, then the fun bit, let's break the language assumption with the polyglot demo. Watch this."
-->

---
layout: default
---

# Review

<v-clicks>

- Cancellation crosses the Nexus boundary automatically. The choice you make is **how long to wait**.
- The four cancellation types are `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, and `WAIT_COMPLETED`. The default is `WAIT_COMPLETED`.
- Synchronous Nexus Operations cannot be cancelled. Only async, workflow-backed handlers support cancellation.
- `nexusrpc.OperationError` is **permanent** and never retries. `nexusrpc.HandlerError` is **transient** and retries with backoff.
- The circuit breaker opens after **5 consecutive retryable errors** on the same caller-Namespace and Endpoint pair, stays open for 60 seconds, then half-opens.

</v-clicks>

<!--
- **Build 1 -** Cancellation crosses the Nexus boundary automatically. The choice you make is how long to wait.
- **Build 2 -** The four cancellation types are `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, and `WAIT_COMPLETED`. The default is `WAIT_COMPLETED`.
- **Build 3 -** Synchronous Nexus Operations cannot be cancelled. Only async, workflow-backed handlers support cancellation.
- **Build 4 -** `nexusrpc.OperationError` is permanent and never retries. `nexusrpc.HandlerError` is transient and retries with backoff.
- **Build 5 -** The circuit breaker opens after 5 consecutive retryable errors on the same caller-Namespace and Endpoint pair, stays open for 60 seconds, then half-opens.
-->
