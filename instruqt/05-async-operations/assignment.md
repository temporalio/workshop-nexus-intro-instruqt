---
slug: async-operations
id: nhoqxds3wrbv
type: challenge
title: Async Operations Backed by a Workflow
teaser: Convert the check_compliance handler to a workflow-backed async Operation,
  register the ComplianceWorkflow on the worker, and observe the three-event async
  lifecycle.
notes:
- type: text
  contents: |-
    # Sync handlers vs workflow-backed async handlers

    Sync handlers are limited to a 10-second per-request handler
    deadline and run inline on the Worker. Async handlers start a
    workflow on the handler's namespace and return that workflow's
    eventual result to the caller, with multi-day headroom
    (Temporal Cloud has a hard 60-day cap; self-hosted is configurable
    via `component.nexusoperations.limit.scheduleToCloseTimeout`
    and can exceed 60 days).

    Switching is a small code change but a large semantic change.
    A workflow runs on the handler side. Durability becomes a
    property of the handler, not the caller. The caller's history
    grows from two events to three.

    In this chapter you flip `check_compliance` to async and watch
    the lifecycle change.
tabs:
- id: cbdqievelgx9
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/05_async_operations/exercise
- id: xix4nycyr38v
  title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/05_async_operations/exercise
- id: polxarxaeipa
  title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/05_async_operations/exercise
- id: xtqg4csilq1s
  title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/05_async_operations/exercise
- id: vogmdmgaxlxj
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
- id: qsnxn5mpza5y
  title: Solution
  type: code
  hostname: workshop
  path: /root/workshop/exercises/05_async_operations/solution
difficulty: intermediate
timelimit: 1500
enhanced_loading: false
---

The `check_compliance` handler currently fits in 10 seconds because the
rule-based check is fast. It will not always be that simple. Real
compliance can take seconds to minutes (database lookups, third-party
KYC APIs, manual review). Anything that can outlive a sync handler
needs to be backed by a **workflow**. This chapter makes that change.

## What You're Solving

A workflow-backed async Operation has a different shape from a sync
Operation:

- The handler is decorated with `@nexus.workflow_run_operation`, not
  `@nexusrpc.handler.sync_operation`.
- The handler's job is to **start a workflow** and return its handle.
  The Nexus runtime records an **operation token** on the caller's
  `NexusOperationStarted` event; the token identifies the started
  handler workflow and is what the caller uses to cancel or re-attach
  to the operation later. A **Nexus completion callback** is attached
  to the StartOperation request by the caller's outbound invocation
  task; that callback delivers the eventual workflow result back to
  the caller. The handler returns immediately; the workflow runs as
  long as it needs to.
- The caller's history shows three events:
  `NexusOperationScheduled`, `NexusOperationStarted` (recorded when
  the handler returns the operation token to the caller), and
  `NexusOperationCompleted` (when the workflow returns).
- Idempotency is your job. Nexus retries land on the same workflow ID;
  `WorkflowIDConflictPolicy.USE_EXISTING` makes the second start
  return the existing handle instead of failing.
- Three timeouts apply: `schedule_to_close` (total budget),
  `schedule_to_start` (handler must pick it up by then), and
  `start_to_close` (handler workflow must finish within this).

You will also implement `ComplianceWorkflow.run` itself, which simply
runs the rule-based check as an Activity and returns the result. The
workflow is small for now.

## What you will do

- Apply **TODO 6** to implement `ComplianceWorkflow.run`.
- Apply **TODOs 7a–7b** to convert the `check_compliance` handler
  from `@nexusrpc.handler.sync_operation` to
  `@nexus.workflow_run_operation` and remove the now-unused activity
  import.
- Apply **TODO 8** to register `ComplianceWorkflow` and the
  `check_compliance` Activity on the Compliance Worker.
- Apply **TODO 9** to add `schedule_to_start_timeout` and
  `start_to_close_timeout` to the caller.
- Run the system end-to-end and observe the three-event async
  lifecycle in the Web UI.

> [!NOTE]
> Stuck on a TODO? The **Solution** tab (rightmost) shows the finished
> file. Try the exercise first, then peek if you need to.

## Step 1: Apply TODO 6 in `compliance/workflows.py`

Open `compliance/workflows.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). The file
contains `ComplianceWorkflow` with a `NotImplementedError` body in
`run`. Replace it with:

```python
@workflow.run
async def run(self, request: ComplianceRequest) -> ComplianceResult:
    self._request = request
    self._auto_result = await workflow.execute_activity(
        check_compliance,
        request,
        start_to_close_timeout=timedelta(seconds=30),
    )
    return self._auto_result
```

Two notes:

- The activity is the same `check_compliance` activity that lived in
  the Payments Worker through Chapter 3. We are about to register it
  on the Compliance Worker so the Compliance team owns the
  implementation.
- The result is stored on `self._auto_result` rather than a local
  variable so this method can later be extended with a MEDIUM-risk
  `wait_condition` without restructuring the whole `run` method.

## Step 2: Apply TODOs 7a–7b in `compliance/service_handler.py`

Open `compliance/service_handler.py`. Two TODO 7 markers: one above
the `check_compliance` method (TODO 7a), and one above the now-unused
import at the top (TODO 7b).

### TODO 7a: Convert `check_compliance` to a workflow-run operation

Replace the entire method (decorator, signature, and body) with the
async version:

```python
@nexus.workflow_run_operation
async def check_compliance(
    self, ctx: nexus.WorkflowRunOperationContext, input: ComplianceRequest
) -> nexus.WorkflowHandle[ComplianceResult]:
    return await ctx.start_workflow(
        ComplianceWorkflow.run,
        input,
        id=f"compliance-ch05-{input.transaction_id}",
        id_conflict_policy=WorkflowIDConflictPolicy.USE_EXISTING,
    )
```

Three pieces:

1. The decorator changes from
   `@nexusrpc.handler.sync_operation` to `@nexus.workflow_run_operation`.
2. The context type changes from
   `nexusrpc.handler.StartOperationContext` to
   `nexus.WorkflowRunOperationContext`. The return type is now
   `nexus.WorkflowHandle[ComplianceResult]` (the handle to the
   running workflow), not the result itself.
3. `id_conflict_policy=WorkflowIDConflictPolicy.USE_EXISTING` makes
   the handler idempotent on retry. If Nexus retries the start
   request for the same transaction, the existing workflow is reused
   instead of failing.

`submit_review` stays a `NotImplementedError` stub for now.

### TODO 7b: Delete the now-unused import

The activity now runs inside `ComplianceWorkflow`, not the Nexus
handler, so this alias is dead code:

```python
from compliance.activities import check_compliance as _check_compliance
```

Delete that line.

## Step 3: Apply TODO 8 in `compliance/worker.py`

Open `compliance/worker.py`. Find the TODO 8 comment in the
`Worker(...)` constructor. Add `workflows` and `activities` arguments
alongside the existing `nexus_service_handlers`:

```python
with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
    worker = Worker(
        client,
        task_queue=TASK_QUEUE,
        workflows=[ComplianceWorkflow],
        activities=[check_compliance],
        activity_executor=executor,
        nexus_service_handlers=[ComplianceNexusServiceHandler()],
    )
```

The activity is sync (it calls `print` for logging), so use the
ThreadPoolExecutor. The Compliance Worker is now a full Temporal
Worker: workflows, activities, **and** Nexus handlers.

## Step 4: Apply TODO 9 in `payments/workflows.py`

Open `payments/workflows.py`. Find the TODO 9 comment near the Nexus
operation call. Add the two missing timeouts:

```python
compliance: ComplianceResult = await nexus_client.execute_operation(
    ComplianceNexusService.check_compliance,
    comp_req,
    schedule_to_close_timeout=timedelta(minutes=10),
    schedule_to_start_timeout=timedelta(minutes=1),
    start_to_close_timeout=timedelta(minutes=8),
)
```

What each does:

- `schedule_to_close_timeout`: total budget. From the moment the
  caller schedules the Operation until completion. Already there from
  Chapter 4.
- `schedule_to_start_timeout`: how long Nexus will wait for a
  Compliance Worker to pick up the Operation. If the operation has
  not been picked up by a Compliance Worker within 1 minute, it fails
  with `TIMEOUT_TYPE_SCHEDULE_TO_START`.
- `start_to_close_timeout`: once the handler workflow has started,
  how long it may run. Bounds the handler's runtime, not the caller's
  total wait.

`start_to_close_timeout` only applies to async handlers. A sync
handler has no "started" state separate from its return, so this
timeout has nothing to bound. `schedule_to_close_timeout` and
`schedule_to_start_timeout` do apply to sync handlers, but each
individual sync attempt is also bounded by the 10-second Nexus
request deadline (measured from the caller's History Service through
matching, so the handler's actual budget is shorter than 10 seconds);
misses are retried by the Nexus Machinery up to
`schedule_to_close_timeout`.

## Step 5: Start the Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal:

```bash,run
uv run python -m compliance.worker
```

The startup banner now shows three things registered:

```bash,nocopy
  Compliance Worker started on: compliance-risk
  Namespace: compliance-namespace
  Registered: ComplianceWorkflow, check_compliance, ComplianceNexusServiceHandler
```

## Step 6: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-2) terminal:

```bash,run
uv run python -m payments.worker
```

No changes from Chapter 4 on the Payments side aside from the timeouts
in the workflow.

## Step 7: Run the starter

Click the [button label="Starter" background="#444CE7"](tab-3)
terminal:

```bash,run
uv run python -m payments.starter
```

You should see the same three results: TXN-A LOW, TXN-B MEDIUM with
monitoring, TXN-C declined HIGH.

## Step 8: Inspect the async lifecycle in the Web UI

Click the
[button label="Temporal UI" background="#444CE7"](tab-4) tab. Switch
to `payments-namespace`. Open `payment-ch05-TXN-A` and look at the Event
History.

The compliance Nexus operation now shows **three events** instead of
two:

- `NexusOperationScheduled`
- `NexusOperationStarted` (the async marker)
- `NexusOperationCompleted`

Now switch the namespace selector to `compliance-namespace`. Open the
Workflows view. **You should now see workflows**, one per
transaction:

- `compliance-ch05-TXN-A`
- `compliance-ch05-TXN-B`
- `compliance-ch05-TXN-C`

That is the durability the handler side just gained. Each transaction
now has a durable workflow on the Compliance side that can survive
worker restarts, can run with multi-day headroom (60 days on Temporal
Cloud; longer on self-hosted clusters that raise
`component.nexusoperations.limit.scheduleToCloseTimeout`), and can be
inspected, queried, or cancelled independently of the caller.

## Step 9 (optional): Durability test

If you have time, kill the Compliance Worker mid-flight:

1. Restart the starter.
2. Within a couple of seconds, hit `Ctrl+C` in the Compliance Worker
   terminal.
3. Wait a few seconds, then restart the Worker.

The handler workflows resume from where they stopped, the activities
complete, and the Nexus operation reports Completed. The caller never
notices the worker restart.

## Key Takeaways

You converted `check_compliance` from a sync handler to a
workflow-backed async handler. The caller's history grew the
`NexusOperationStarted` event. The Compliance namespace now runs a
workflow per transaction, with full durability. The
`USE_EXISTING` ID conflict policy made the handler idempotent on
retry.

This chapter established three things on the handler side:
workflow-backed durability (the Compliance namespace now hosts a
workflow per transaction), the three-event async lifecycle on the
caller (`NexusOperationScheduled`, `NexusOperationStarted`,
`NexusOperationCompleted`), and the three timeout knobs
(`schedule_to_close_timeout`, `schedule_to_start_timeout`, and the
async-only `start_to_close_timeout`) that bound the operation at each
stage.
