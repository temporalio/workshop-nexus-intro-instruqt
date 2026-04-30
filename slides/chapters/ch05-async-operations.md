---
layout: toc
current: ch5
---

---
layout: section
---

# 05 / Async Operations

---
layout: default
---

# Sync vs Async, In One Slide

<br>

|                  | Sync handler              | Async handler                              |
| :--------------- | :------------------------ | :----------------------------------------- |
| Decorator        | `@sync_operation`         | `@workflow_run_operation`                  |
| What it returns  | result directly           | a `WorkflowHandle` to a workflow that produces the result |
| Where work runs  | inline in the handler Worker | in a workflow on the handler namespace |
| Caller events    | 2 (Scheduled, Completed)  | 3 (Scheduled, Started, Completed)          |
| Time budget      | 10 seconds                | up to **60 days** on Temporal Cloud        |
| Cancellable?     | **No** (no operation token) | **Yes**                                  |

<br>

<v-click>

Sync handlers cannot be cancelled because they hold no operation token. Async handlers can.

</v-click>

<!--
- One-slide comparison. The room can use this as a reference for the rest of the chapter and the AhaSlides quiz block.
- Walk the table row by row.
  - Decorator: different name, same Service contract.
  - What it returns: this is the architectural change. Sync returns the result; async returns a handle to a workflow that produces the result.
  - Where work runs: sync = inline in the Worker process; async = a workflow on the handler namespace.
  - Caller events: sync = 2; async = 3. The added event is `Started`, recorded when the handler returns the operation token.
  - Time budget: sync = 10s per-request handler deadline (retried up to schedule-to-close); async = up to 60 days on Temporal Cloud, configurable on self-hosted.
  - Cancellable: sync no, async yes. This is the asymmetry most rooms don't expect.
- **Build 1** Sync handlers cannot be cancelled because they hold no operation token.
  - "Cancellation rides on the operation token. Sync has no token, so sync cannot be cancelled."
  - Plant this; it is the reason cancellation only applies to async handlers.
-->

---
layout: default
---

# When 10 Seconds Isn't Enough

<br>

Compliance checks can take **minutes**. Human reviews can take **hours**. Refund SLAs can take **days**.

<br>

<v-clicks>

- `@nexusrpc.handler.sync_operation` runs inline on the handler's Worker, bound by the 10-second per-request deadline.
- `@nexus.workflow_run_operation` returns a **WorkflowHandle** instead.

</v-clicks>

<br>

<v-click>

The handler workflow runs durably on the Compliance Worker. The caller awaits its eventual result.

</v-click>

<br>

<v-click>

The big architectural change: **durability moves from caller-only to caller AND handler.** When the handler is a workflow, it survives Worker restarts on the handler side. The caller does not have to know this.

</v-click>

<!--
- Welcome back from break. New chapter. New decorator.
- Compliance checks can take **minutes**. Human reviews can take **hours**. Refund SLAs can take **days**.
  - Concrete examples drive the need. Pause for each one.
  - "How many of you have a workflow that needs human approval?" Hands up.
- **Build 1** `@nexusrpc.handler.sync_operation` runs inline on the handler's Worker, bound by the 10-second per-request deadline.
  - Quick recap of Chapter 3. Sync = function call on the handler's Worker, ≤10 seconds per attempt. The caller's Workflow Task already completed when it scheduled the call; the caller is waiting durably (no Task open) for the operation to complete.
- **Build 2** `@nexus.workflow_run_operation` returns a **WorkflowHandle** instead.
  - Different decorator. Different return type. Same Service contract.
  - The handler doesn't return the result; it returns a **handle to a workflow that will produce the result**.
- **Build 3** The handler workflow runs durably on the Compliance Worker. The caller awaits its eventual result.
  - "Eventual" is the key word. The caller awaits, the platform polls, the result comes back when the workflow finishes.
  - Up to 60 days on Temporal Cloud (self-hosted is configurable above 60 days via the `component.nexusoperations.limit.scheduleToCloseTimeout` dynamic config). Plenty of room for human-in-the-loop, batch jobs, slow APIs.
- The decision rule: ≤10s deterministic, sync. Anything else, async.
- The handler workflow is observable in the Web UI, retriable, and persistent. All the things you already love about Workflows.
-->

---
layout: default
---

# `@nexus.workflow_run_operation`

<br>

```python {all|1|3-4|5-9|all}
@nexus.workflow_run_operation
async def check_compliance(
    self,
    ctx: nexus.WorkflowRunOperationContext,
    input: ComplianceRequest,
) -> nexus.WorkflowHandle[ComplianceResult]:
    return await ctx.start_workflow(
        ComplianceWorkflow.run,
        input,
        id=f"compliance-ch05-{input.transaction_id}",
        id_conflict_policy=WorkflowIDConflictPolicy.USE_EXISTING,
    )
```

<br>

<v-clicks>

- The handler **starts a workflow** and returns its handle.
- The Nexus runtime delivers requests **at-least-once**. Without `USE_EXISTING`, a retried start tries to create a duplicate workflow and fails.
- With `USE_EXISTING`, the retry **attaches to the existing workflow** and returns its handle. Idempotent.
- Same flag also enables **fan-in**: multiple Nexus callers can subscribe to one running handler workflow and all receive its result.
- Single most common production gotcha for async Nexus operations.

</v-clicks>

<!--
- The async handler is a thin shim over `Workflow.start`. Three things in three lines.
- **Build 1 (whole code)** Show the full handler.
- **Build 2 (line 1, decorator)** `@nexus.workflow_run_operation`
  - Different decorator from Chapter 3's `@sync_operation`. Same class, same Service contract, different per-method behavior.
- **Build 3 (lines 3-4, signature)** `async def check_compliance(self, ctx: nexus.WorkflowRunOperationContext, input: ComplianceRequest)`
  - Different `ctx` type: `WorkflowRunOperationContext` instead of `StartOperationContext`.
  - Same input type. The contract didn't change.
  - Return type is `nexus.WorkflowHandle[ComplianceResult]` (not `ComplianceResult` directly).
- **Build 4 (lines 5-9, body)** `return await ctx.start_workflow(ComplianceWorkflow.run, input, id=..., id_conflict_policy=...)`
  - The handler **starts a workflow** and returns its handle.
  - `ComplianceWorkflow.run` is the entry point of the handler workflow. We define this in TODO 6.
  - `id=f"compliance-ch05-{input.transaction_id}"`: deterministic workflow id. Use the transaction id so retries hit the same workflow.
  - `id_conflict_policy=USE_EXISTING`: the idempotency knob.
- **Build 5 (whole code)** Pull back out for closing bullets.
- **Build 6** The handler **starts a workflow** and returns its handle.
  - Three lines of glue. The handler doesn't run the work; it kicks off a workflow that runs the work.
- **Build 7** `USE_EXISTING` makes the start idempotent. A retried Nexus call attaches to the same workflow instead of failing.
  - Without it: two retries race, one wins, one fails. Bad UX, possible duplicate work.
  - With it: second caller attaches to the running workflow, gets the same eventual result. Idempotent.
- The async handler is the standard pattern for any Nexus call that runs longer than ~5 seconds.
-->

---
layout: default
---

# What Is the Operation Token?

<br>

When an async handler returns a `WorkflowHandle`, the Nexus runtime stores an **Operation Token** that ties the caller's pending Operation to the handler workflow.

<v-clicks>

- The platform's internal identifier for "the long-running thing the caller is waiting for."
- Surfaced as `Pending Nexus Operations` rows on `temporal workflow describe` and in the Web UI.
- The platform uses it for **cancellation propagation**, **completion delivery**, and **status queries**.
- You almost never construct or parse it directly.

</v-clicks>

<br>

<v-click>

Mental model: an **address-book entry**, scoped to this Nexus call.

</v-click>

<!--
- Definitional slide. The token is the mechanism that makes async work; the room will see it referenced in docs and CLI output.
- When an async handler returns a WorkflowHandle, the Nexus runtime stores an Operation Token.
  - Token = opaque string. Platform-issued.
  - Ties caller-side pending Operation to handler-side running workflow.
- **Build 1** The platform's internal identifier for "the long-running thing the caller is waiting for."
  - You don't see it in caller code. You see it in observability.
- **Build 2** Surfaced as Pending Nexus Operations rows on temporal workflow describe and in the Web UI.
  - Run `temporal workflow describe -w <id>` against a caller workflow and you'll see the row.
  - Fields: Endpoint, Service, Operation, OperationToken, State (Scheduled / BackingOff / Started / Blocked), Attempt, LastAttemptFailure, NextAttemptScheduleTime.
- **Build 3** The platform uses it for cancellation propagation, completion delivery, and status queries.
  - When the handler workflow finishes, the platform uses the token to forward the result back to the caller.
  - When the caller cancels, the platform uses the token to find and cancel the handler workflow.
  - Sync handlers have no token. That's why they can't be cancelled.
- **Build 4** You almost never construct or parse it directly.
  - This is platform plumbing. Mention it so the room recognizes it in docs; don't dwell.
- **Build 5** Mental model: an address-book entry, scoped to this Nexus call.
  - Carry-forward metaphor. Plant it.
- This slide is 60 seconds. Don't over-explain. The visible payoff is the Web UI tour in the exercise.
-->

---
layout: default
---

# Three Events, Not Two

<br>

The async lifecycle adds one event in the middle.

<br>

| Sync                            | Async                            |
| :------------------------------ | :------------------------------- |
| `NexusOperationScheduled`       | `NexusOperationScheduled`        |
|                                 | `NexusOperationStarted`          |
| `NexusOperationCompleted`       | `NexusOperationCompleted`        |

<br>

<v-clicks>

- `Started` carries the **operation token**, your handle to the running handler workflow.
- Between `Started` and `Completed`, you'll see the Operation listed in **Pending Nexus Operations** on `temporal workflow describe`.

</v-clicks>

<br>

<v-click>

**Diagnostic reflex.** Scheduled but never Started, the handler-side Worker is not picking it up: check `schedule_to_start_timeout`. Started but never Completed, the handler workflow is stuck or running long: check `start_to_close_timeout` and the workflow's own state.

</v-click>

<!--
- The async lifecycle adds one event in the middle. That's the only difference from sync.
- Walk the table left to right.
  - Sync: Scheduled, Completed.
  - Async: Scheduled, **Started**, Completed.
- The `Started` event is the load-bearing one. It's the signal that the handler is a workflow, not a function.
- **Build 1** `Started` carries the **operation token**, your handle to the running handler workflow.
  - The operation token is how the platform identifies the long-running handler workflow.
  - You don't usually inspect it directly. The platform uses it for cancellation, completion, and updates back to the caller.
  - Think of it as the workflow's address book entry, scoped to this Nexus call.
- **Build 2** Between `Started` and `Completed`, you'll see the Operation listed in **Pending Nexus Operations** on `temporal workflow describe`.
  - Run `temporal workflow describe -w <caller-workflow-id>` to see it.
  - Pending Nexus Operations shows: operation name, state, attempt count, scheduled-to-close deadline.
  - Same diagnostic surface as Pending Activities for activities.
- If you only see Scheduled and Completed in the caller's history, the handler ran inline (sync). If you see Started in the middle, it's a workflow.
-->

---
layout: default
---

# Three Timeouts You'll Actually Set

<br>

```python {all|3|4|5|all}
await nexus_client.execute_operation(
    ComplianceNexusService.check_compliance, request,
    schedule_to_close_timeout=timedelta(minutes=10),
    schedule_to_start_timeout=timedelta(seconds=30),
    start_to_close_timeout=timedelta(minutes=8),
)
```

<br>

<v-clicks>

- **The three nest.** `schedule_to_close` is the outer ceiling; the other two live inside it.
- **schedule-to-close**: total runtime budget. Up to 60 days on Temporal Cloud.
- **schedule-to-start**: how long to wait for a Compliance Worker to pick it up.
- **start-to-close**: per-attempt runtime, once a Worker has it.
- Self-hosted ceiling is configurable via `component.nexusoperations.limit.scheduleToCloseTimeout`. Temporal Cloud is locked at 60 days.

</v-clicks>

<!--
- The three timeouts mirror the Activity timeouts. Same names, same meaning.
- **Build 1 (whole code)** Show the full call.
- **Build 2 (line 3, schedule-to-close)** `schedule_to_close_timeout=timedelta(minutes=10)`
  - Total runtime budget. From the moment the Nexus call is scheduled to the moment it completes (or fails).
  - On Temporal Cloud, the maximum is **60 days**. AhaSlides slide 12 quizzes this.
  - This is the umbrella timeout. The other two live inside it.
- **Build 3 (line 4, schedule-to-start)** `schedule_to_start_timeout=timedelta(seconds=30)`
  - How long to wait for a Compliance Worker to pick up the call.
  - If this trips, the message is "your handler-side workers aren't healthy."
  - Use this to detect Compliance team outages without waiting for the full schedule-to-close.
- **Build 4 (line 5, start-to-close)** `start_to_close_timeout=timedelta(minutes=8)`
  - Per-attempt runtime, once a Compliance Worker has picked up the call.
  - For workflow-backed handlers, this is the max time **one attempt** of the handler workflow can take.
  - If this trips, the platform retries (subject to retry policy) up to schedule-to-close.
- **Build 5 (whole code)** Pull back out for closing bullets.
- **Build 6** **schedule-to-close**: total runtime budget. Up to 60 days on Temporal Cloud.
  - The 60-day fact again. Plant it twice.
- **Build 7** **schedule-to-start**: how long to wait for a Compliance Worker to pick it up.
- **Build 8** **start-to-close**: per-attempt runtime, once a Worker has it.
- These three are one of the most common Nexus decisions in production. Setting them too tight = false alarms. Too loose = slow failure detection.
-->

---
layout: section
---

# Quiz Time

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slides 22-25** (four slides, three graded + one self-assessment, ~2 minutes).
- This block runs **right before** Exercise 5. We test the async concepts before they go hands-on.
- **Lead-in**: "Welcome back from the break. Let's see how much of the async picture stuck before we go convert that handler. Four questions."
- **AhaSlides slide 22 (correct order, graded)**: "Async Operation lifecycle: drag the events into order."
  - Drag-to-order. Scheduled, Started, Completed.
  - Anchor: "If you see Started in the middle of those three, the handler is a workflow."
- **AhaSlides slide 23 (pick answer, graded)**: "Which timeout governs the handler workflow's total runtime, end-to-end?"
  - Correct: **Schedule-to-Close**.
  - The umbrella timeout. Up to 60 days on Temporal Cloud (callback to AhaSlides slide 12 from Ch1).
- **AhaSlides slide 24 (pick answer, graded)**: "Why does WorkflowIDConflictPolicy.USE_EXISTING matter on retry?"
  - Correct: makes the handler workflow start **idempotent**, a retry attaches to the existing workflow instead of failing.
  - Without it: two clients trying to start the same workflow id, one wins, one fails. With it: second attaches.
- **AhaSlides slide 25 (scale 1-5, NOT graded)**: "Could you pick the right timeout in production tomorrow?"
  - This is **the most useful signal of the chapter**. Read the average aloud.
  - If the average is below 3, spend an extra 60 seconds on the timeout decision tree before sending them to Instruqt.
  - If 4+, ship them straight to the exercise.
- **Lead-out**: "OK, time to write it. Switch to Instruqt, four TODOs, 13 minutes, the handler becomes a real workflow."
- After this transition, advance to Exercise 5 card.
-->

---
layout: exercise
minutes: 13
heading: Exercise 5
---

**Convert to a workflow-backed async Operation.**

You will turn `check_compliance` into a workflow-backed async Operation,
register `ComplianceWorkflow` on the Compliance Worker, and observe the
three-event async lifecycle in caller history.

Full instructions are in the Instruqt tab.

<!--
- 13 minute exercise. Biggest content jump of the workshop, despite the shorter time.
- "Convert the handler to async. Build the handler workflow."
  - Four TODOs. The most code per minute they'll write today.
- TODO 6: Implement `ComplianceWorkflow.run` to call `check_compliance` activity
  - The handler workflow body. One activity call, return the result.
  - Skeleton already exists with `NotImplementedError`.
- TODO 7: Convert handler to `@nexus.workflow_run_operation` returning `WorkflowHandle`
  - Replace `@sync_operation` decorator. Change return type. Use `ctx.start_workflow(...)`.
  - Don't forget `id_conflict_policy=USE_EXISTING`.
- TODO 8: Register `ComplianceWorkflow` and the activity on the Compliance Worker
  - Add `workflows=[ComplianceWorkflow]` and `activities=[check_compliance]` to the Worker.
  - The Nexus handler is already registered from Chapter 3.
- TODO 9: Set all three timeouts on the caller-side `execute_operation`
  - `schedule_to_close_timeout`, `schedule_to_start_timeout`, `start_to_close_timeout`.
- After this exercise, the handler IS a workflow. They can find `compliance-ch05-TXN-A` in compliance-namespace.
  - "Switch to the Web UI. Filter for compliance-namespace. You should see compliance-ch05-TXN-A, compliance-ch05-TXN-B, compliance-ch05-TXN-C workflows."
  - "Look at the caller's history. You'll now see three Nexus events: Scheduled, Started, Completed."
- After they finish, advance to the Review slide, then on to Chapter 6. The Ch5 AhaSlides quiz already ran before this exercise.
-->

---
layout: default
---

# Review

<v-clicks>

- An asynchronous Nexus handler is decorated with `@nexus.workflow_run_operation` and returns a `WorkflowHandle`
- The async lifecycle adds a **`NexusOperationStarted`** event between `Scheduled` and `Completed`
- The operation token ties the caller's pending Operation to the handler workflow on the handler side
- `Schedule-to-Close`, `Schedule-to-Start`, and `Start-to-Close` timeouts nest inside one another
- `WorkflowIDConflictPolicy.USE_EXISTING` makes a workflow-backed handler **idempotent on retry**

</v-clicks>

<!--
- Builds back the chapter. Forty-five seconds.
- **Build 1** An asynchronous Nexus handler is decorated with `@nexus.workflow_run_operation` and returns a `WorkflowHandle`
- **Build 2** The async lifecycle adds a `NexusOperationStarted` event between `Scheduled` and `Completed`
- **Build 3** The operation token ties the caller's pending Operation to the handler workflow on the handler side
- **Build 4** `Schedule-to-Close`, `Schedule-to-Start`, and `Start-to-Close` timeouts nest inside one another
- **Build 5** `WorkflowIDConflictPolicy.USE_EXISTING` makes a workflow-backed handler idempotent on retry
- After the last build, advance to Chapter 6.
-->
