---
layout: toc
current: ch5
---

---
layout: default
---

# Sync vs Async, In One Slide

|                  | Sync handler              | Async handler                              |
| :--------------- | :------------------------ | :----------------------------------------- |
| Decorator        | `@sync_operation`         | `@workflow_run_operation`                  |
| What it returns  | result directly           | a `WorkflowHandle` to a workflow             |
| Where work runs  | inline in the handler Worker | in a workflow on the handler namespace |
| Caller events    | 2 (Scheduled, Completed)  | 3 (Scheduled, Started, Completed)          |
| Time budget      | 10 seconds                | up to **60 days** on Temporal Cloud        |
| Cancellable?     | **No**                    | **Yes**                                    |

<v-click>

Sync handlers can't be cancelled because they hold no operation token. Async handlers can.

</v-click>

<style>
.slidev-layout table { font-size: 1.15rem; }
.slidev-layout th, .slidev-layout td { padding: 0.3rem 0.6rem; }
</style>

<!--
- One-slide comparison. The room can use this as a reference throughout the chapter.
- Decorator: different name, same Service contract.
- What it returns: sync returns the result; async returns a handle to a workflow that produces the result.
- Where work runs: sync = inline in the Worker process; async = a workflow on the handler namespace.
- Caller events: sync = 2; async = 3. The added event is `Started`, recorded when the handler returns the operation token.
- Time budget: sync = 10s per-request handler deadline (retried up to schedule-to-close); async = up to 60 days on Temporal Cloud, configurable on self-hosted.
- Cancellable: sync no, async yes.
- **Build 1** Sync handlers cannot be cancelled because they hold no operation token.
  - Cancellation rides on the operation token. Sync has no token, so sync cannot be cancelled.
-->

---
layout: default
---

# When 10 Seconds Isn't Enough

Compliance checks take **minutes**. Human reviews take **hours**. Refund SLAs take **days**.

<v-clicks>

- `@sync_operation` runs inline, bound by the 10-second deadline.
- `@workflow_run_operation` returns a **WorkflowHandle** instead.

</v-clicks>

<v-click>

The handler workflow runs durably on the Compliance Worker. The caller awaits its eventual result.

</v-click>

<br>

<v-click>

The big shift: **durability moves from caller-only to caller AND handler.** The caller doesn't have to know.

</v-click>

<!--
- Compliance checks can take **minutes**. Human reviews can take **hours**. Refund SLAs can take **days**.
  - "How many of you have a workflow that needs human approval?"
- **Build 1** `@nexusrpc.handler.sync_operation` runs inline on the handler's Worker, bound by the 10-second per-request deadline.
  - Sync = function call on the handler's Worker, ≤10 seconds per attempt. The caller's Workflow Task already completed when it scheduled the call; the caller is waiting durably (no Task open) for the operation to complete.
- **Build 2** `@nexus.workflow_run_operation` returns a **WorkflowHandle** instead.
  - Different decorator. Different return type. Same Service contract.
  - The handler doesn't return the result; it returns a **handle to a workflow that will produce the result**.
- **Build 3** The handler workflow runs durably on the Compliance Worker. The caller awaits its eventual result.
  - "Eventual" is the key word. The caller awaits, the platform polls, the result comes back when the workflow finishes.
  - Up to 60 days on Temporal Cloud (self-hosted is configurable above 60 days via the `component.nexusoperations.limit.scheduleToCloseTimeout` dynamic config). Plenty of room for human-in-the-loop, batch jobs, slow APIs.
- **Build 4** The big architectural change: durability moves from caller-only to caller AND handler. When the handler is a workflow, it survives Worker restarts on the implementer side. The caller does not have to know this.
  - The decision rule: ≤10s deterministic, sync. Anything else, async.
  - The handler workflow is observable in the Web UI, retriable, and persistent. All the things you already love about Workflows.
-->

---
layout: default
---

# Defining an Async Handler

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

<style>
.slidev-layout pre.shiki,
.slidev-layout pre code { font-size: 1.0rem; line-height: 1.3; }
</style>

<!--
- The async handler is a thin shim over `Workflow.start`. Three things in three lines.
- **Build 1 (whole code)** The full handler.
- **Build 2 (line 1, decorator)** `@nexus.workflow_run_operation`
  - Different decorator from Chapter 3's `@sync_operation`. Same class, same Service contract, different per-method behavior.
- **Build 3 (lines 3-4, signature)** `async def check_compliance(self, ctx: nexus.WorkflowRunOperationContext, input: ComplianceRequest)`
  - Different `ctx` type: `WorkflowRunOperationContext` instead of `StartOperationContext`.
  - Same input type. The contract didn't change.
  - Return type is `nexus.WorkflowHandle[ComplianceResult]` (not `ComplianceResult` directly).
- **Build 4 (lines 5-9, body)** `return await ctx.start_workflow(ComplianceWorkflow.run, input, id=..., id_conflict_policy=...)`
  - The handler **starts a workflow** and returns its handle.
  - `id=f"compliance-ch05-{input.transaction_id}"`: deterministic workflow id. Use the transaction id so retries hit the same workflow.
  - `id_conflict_policy=USE_EXISTING`: the idempotency knob.
- **Build 5 (whole code)** Recap.
- The Defining an Async Handler Explained slide carries the synthesis bullets.

## Teaching notes

- `ComplianceWorkflow.run` is the entry point of the handler workflow, defined in TODO 6 of the exercise.
-->

---
layout: default
---

# Defining an Async Handler Explained

<v-clicks>

- The handler **starts a workflow** and returns its handle.
- The Nexus runtime delivers requests **at-least-once**. Without `USE_EXISTING`, a retried start fails on duplicate workflow.
- With `USE_EXISTING`, the retry **attaches to the existing workflow**. Idempotent.
- Same flag enables **fan-in**: multiple callers subscribe to one workflow.
- The single most common production gotcha for async Nexus operations.

</v-clicks>

<!--
- **Build 1** The handler starts a workflow and returns its handle.
  - Three lines of glue. The handler doesn't run the work; it kicks off a workflow that runs the work.
- **Build 2** The Nexus runtime delivers requests at-least-once. Without `USE_EXISTING`, a retried start tries to create a duplicate workflow and fails.
  - At-least-once is the wire-level contract. Retries WILL happen.
- **Build 3** With `USE_EXISTING`, the retry attaches to the existing workflow and returns its handle. Idempotent.
  - Without it: two retries race, one wins, one fails. Bad UX, possible duplicate work.
  - With it: second caller attaches to the running workflow, gets the same eventual result.
- **Build 4** Same flag enables fan-in: multiple Nexus callers subscribe to one running handler workflow.
  - One workflow, many waiters. Deduplicates work across callers.
- **Build 5** Single most common production gotcha for async Nexus operations.
  - Number-one mistake: forgetting `id_conflict_policy=USE_EXISTING`.
-->

---
layout: default
---

# What Is the Operation Token?

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
- When an async handler returns a WorkflowHandle, the Nexus runtime stores an Operation Token.
  - Token = opaque string. Platform-issued.
  - Ties caller-side pending Operation to implementer-side running workflow.
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
  - This is platform plumbing. You'll see it referenced in the docs and CLI output.
- **Build 5** Mental model: an address-book entry, scoped to this Nexus call.

## Teaching notes

- The visible payoff for the operation-token framing is the Web UI tour in the exercise that follows; if the room is shaky after this slide, lean on the upcoming `temporal workflow describe` walk-through to make it concrete.
-->

---
layout: default
---

# Three Events, Not Two

The async lifecycle adds one event in the middle.

| Sync                            | Async                            |
| :------------------------------ | :------------------------------- |
| `NexusOperationScheduled`       | `NexusOperationScheduled`        |
|                                 | `NexusOperationStarted`          |
| `NexusOperationCompleted`       | `NexusOperationCompleted`        |

<v-clicks>

- `Started` carries the **operation token** — your handle to the handler workflow.
- Between `Started` and `Completed`, the Operation appears in **Pending Nexus Operations**.

</v-clicks>

<v-click>

**Diagnostic reflex.** Scheduled, no Started → check `schedule_to_start_timeout`. Started, no Completed → check `start_to_close_timeout` and the handler workflow's state.

</v-click>

<style>
.slidev-layout table { font-size: 1.15rem; }
.slidev-layout th, .slidev-layout td { padding: 0.25rem 0.6rem; }
</style>

<!--
- The async lifecycle adds one event in the middle. That's the only difference from sync.
- Sync: Scheduled, Completed.
- Async: Scheduled, **Started**, Completed.
- The `Started` event is the signal that the handler is a workflow, not a function.
- **Build 1** `Started` carries the **operation token**, your handle to the running handler workflow.
  - The operation token is how the platform identifies the long-running handler workflow.
  - You don't usually inspect it directly. The platform uses it for cancellation, completion, and updates back to the caller.
  - Think of it as the workflow's address book entry, scoped to this Nexus call.
- **Build 2** Between `Started` and `Completed`, you'll see the Operation listed in **Pending Nexus Operations** on `temporal workflow describe`.
  - Run `temporal workflow describe -w <caller-workflow-id>` to see it.
  - Pending Nexus Operations shows: operation name, state, attempt count, scheduled-to-close deadline.
  - Same diagnostic surface as Pending Activities for activities.
- **Build 3** Diagnostic reflex. Scheduled but never Started, the implementer-side Worker is not picking it up: check `schedule_to_start_timeout`. Started but never Completed, the handler workflow is stuck or running long: check `start_to_close_timeout` and the workflow's own state.
  - If you only see Scheduled and Completed in the caller's history, the handler ran inline (sync). If you see Started in the middle, it's a workflow.
-->

---
layout: default
---

# Three Timeouts You'll Actually Set

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
- **Build 1 (whole code)** The full call.
- **Build 2 (line 3, schedule-to-close)** `schedule_to_close_timeout=timedelta(minutes=10)`
  - Total runtime budget. From the moment the Nexus call is scheduled to the moment it completes (or fails).
  - On Temporal Cloud, the maximum is **60 days**.
  - This is the umbrella timeout. The other two live inside it.
- **Build 3 (line 4, schedule-to-start)** `schedule_to_start_timeout=timedelta(seconds=30)`
  - How long to wait for a Compliance Worker to pick up the call.
  - If this trips, the message is "your implementer-side workers aren't healthy."
  - Use this to detect Compliance team outages without waiting for the full schedule-to-close.
- **Build 4 (line 5, start-to-close)** `start_to_close_timeout=timedelta(minutes=8)`
  - Per-attempt runtime, once a Compliance Worker has picked up the call.
  - For workflow-backed handlers, this is the max time **one attempt** of the handler workflow can take.
  - If this trips, the platform retries (subject to retry policy) up to schedule-to-close.
- **Build 5 (whole code)** Recap.
- **Build 6** The three nest. `schedule_to_close` is the outer ceiling; the other two live inside it.
  - Visualize as concentric circles: schedule-to-close holds everything; schedule-to-start and start-to-close live inside.
- **Build 7** schedule-to-close: total runtime budget. Up to 60 days on Temporal Cloud.
- **Build 8** schedule-to-start: how long to wait for a Compliance Worker to pick it up.
- **Build 9** start-to-close: per-attempt runtime, once a Worker has it.
- **Build 10** Self-hosted ceiling is configurable via `component.nexusoperations.limit.scheduleToCloseTimeout`. Temporal Cloud is locked at 60 days.
  - Knob you can turn on self-hosted but never on Temporal Cloud.

## Teaching notes

- These three are one of the most common Nexus decisions in production. Setting them too tight = false alarms. Too loose = slow failure detection.
- **Production limit worth knowing (verbal-only).** Temporal Cloud caps in-flight Nexus Operations per caller workflow at **30** today (`docs.temporal.io/cloud/limits#per-workflow-nexus-operation-limits`). The workshop never hits this; production fanouts can. Roadmap raises this with the CHASM port / Standalone Nexus Operations work; the exact future cap is not yet documented. Don't conflate this with the Per-Workflow Callback limit (2000), which governs how many Nexus callers can attach to one handler workflow.
-->

---
layout: section
---

# Quiz Time

ahaslides.com/NEXUSWS

<!--
- "Welcome back from the break. Let's see how much of the async picture stuck before we go convert that handler. Four questions."
- "If you see Started in the middle of those three, the handler is a workflow."
- "OK, time to write it. Switch to Instruqt, four TODOs, 13 minutes, the handler becomes a real workflow."

## Teaching notes

- AhaSlides correct order trigger: "Async Operation lifecycle: drag the events into order." Expected order: Scheduled, Started, Completed.
- AhaSlides pick answer trigger: "Which timeout governs the handler workflow's total runtime, end-to-end?" Correct: Schedule-to-Close (up to 60 days on Temporal Cloud).
- AhaSlides pick answer trigger: "Why does WorkflowIDConflictPolicy.USE_EXISTING matter on retry?" Correct: makes the handler workflow start idempotent; a retry attaches to the existing workflow instead of failing. Without it: two clients trying to start the same workflow id, one wins, one fails. With it: second attaches.
- AhaSlides scale 1-5 trigger: "Could you pick the right timeout in production tomorrow?"
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
- "Convert the handler to async. Build the handler workflow."
- "Switch to the Web UI. Filter for compliance-namespace. You should see compliance-ch05-TXN-A, compliance-ch05-TXN-B, compliance-ch05-TXN-C workflows."
- "Look at the caller's history. You'll now see three Nexus events: Scheduled, Started, Completed."

## Teaching notes

- Four TODOs. The most code per minute attendees will write today.
- TODO 6: Implement `ComplianceWorkflow.run` to call `check_compliance` activity. The handler workflow body. One activity call, return the result. Skeleton already exists with `NotImplementedError`.
- TODO 7: Convert handler to `@nexus.workflow_run_operation` returning `WorkflowHandle`. Replace `@sync_operation` decorator. Change return type. Use `ctx.start_workflow(...)`. Don't forget `id_conflict_policy=USE_EXISTING`.
- TODO 8: Register `ComplianceWorkflow` and the activity on the Compliance Worker. Add `workflows=[ComplianceWorkflow]`, `activities=[check_compliance]`, and `activity_executor=executor` to the existing `Worker(...)` call. The `with concurrent.futures.ThreadPoolExecutor(...) as executor:` wrap is pre-seeded in the exercise so they don't have to re-indent `await worker.run()`. The Nexus handler is already registered from Chapter 3.
- TODO 9: Set all three timeouts on the caller-side `execute_operation`: `schedule_to_close_timeout`, `schedule_to_start_timeout`, `start_to_close_timeout`.
- After this exercise, the handler IS a workflow. Attendees can find `compliance-ch05-TXN-A`, `compliance-ch05-TXN-B`, and `compliance-ch05-TXN-C` in compliance-namespace.
-->

---
layout: default
---

# Review

<v-clicks>

- An asynchronous Nexus handler is decorated with `@nexus.workflow_run_operation` and returns a `WorkflowHandle`
- The async lifecycle adds a **`NexusOperationStarted`** event between `Scheduled` and `Completed`
- The operation token ties the caller's pending Operation to the handler workflow on the implementer side
- `Schedule-to-Close`, `Schedule-to-Start`, and `Start-to-Close` timeouts nest inside one another
- `WorkflowIDConflictPolicy.USE_EXISTING` makes a workflow-backed handler **idempotent on retry**

</v-clicks>

<!--
- **Build 1** An asynchronous Nexus handler is decorated with `@nexus.workflow_run_operation` and returns a `WorkflowHandle`
- **Build 2** The async lifecycle adds a `NexusOperationStarted` event between `Scheduled` and `Completed`
- **Build 3** The operation token ties the caller's pending Operation to the handler workflow on the implementer side
- **Build 4** `Schedule-to-Close`, `Schedule-to-Start`, and `Start-to-Close` timeouts nest inside one another
- **Build 5** `WorkflowIDConflictPolicy.USE_EXISTING` makes a workflow-backed handler idempotent on retry
-->

---
layout: section
---

# Halftime!

Leaderboard, pulse check, then break

<!--
- "Big morning. You decoupled the monolith into two namespaces, swapped the caller through Nexus, and turned the handler into a workflow-backed async operation. The full async picture is now under your fingers. Let's lock in what you saw, then take a leaderboard moment, then we break."
- "Sync = 2 events. Async = 3. The Started event in the middle is the giveaway that the handler is a workflow."
- "These three are leading at halftime. Don't get comfortable, second half is where the points are."
- "Drop questions while you walk to coffee. I'll triage and answer right after the break."
- "OK, 15 minutes. We're back at 11:30 sharp. Coffee, restroom, drop questions in AhaSlides while you walk. See you back here."

## Teaching notes

- This is the second of two breaks in the workshop. Block 2 (Ch 3 + Ch 4 + Ch 5) ends here; the Halftime leaderboard moment celebrates the morning's punchline (decoupled monolith + full async lifecycle).
- AhaSlides Halftime block (slides 23-25) lands at this break: Halftime leaderboard + word-cloud pulse + Q&A parking lot.
- AhaSlides leaderboard: Halftime standings.
- AhaSlides word cloud trigger: "What's clicking? One word."
- AhaSlides parking lot trigger: "Drop your questions for after the break."
- If Ch 5's exercise ran long, eat into this break before letting it eat into Ch 6.
- **Ch 4 AhaSlides quiz triggers (no dedicated Quiz Time slide in Ch 4 — historically embedded here).**
  - Slide 17 pick answer: "How many Nexus events on a sync call?" Correct: **2** (Scheduled and Completed). Fire after the Ch 4 "Two Events, One Sync Call" beat, not at Halftime.
  - Slide 18 match pairs: "Match the Event History event to what it means." Fire after Ch 4's Exercise 4, not at Halftime.
  - Both questions feed into the Halftime leaderboard total at slide 23.
-->


