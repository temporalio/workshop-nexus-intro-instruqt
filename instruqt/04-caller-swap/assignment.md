---
slug: caller-swap
id: swejwcrale5g
type: challenge
title: Swap the Caller to Nexus
teaser: Replace the Payments Workflow's local activity call with a Nexus Operation
  call, drop the now-unused Compliance code from the Payments Worker, and witness
  the two-event sync pattern in Event History.
notes:
- type: text
  contents: |-
    # The caller side of Nexus

    The Payments Workflow currently invokes compliance with
    `workflow.execute_activity(check_compliance, ...)`. By the end
    of this chapter it will invoke compliance with
    `nexus_client.execute_operation(...)` instead.

    The semantic difference: the Activity ran in the Payments
    Worker's own task queue. The Nexus Operation runs across the
    `compliance-endpoint` boundary, in another team's namespace,
    on another team's Worker. Payments does not import any
    Compliance code.

    The visible difference: the caller's Event History will show
    `NexusOperationScheduled` and `NexusOperationCompleted`
    instead of `ActivityTaskScheduled` and `ActivityTaskCompleted`.
tabs:
- id: kxbhcumgi0v5
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/04_caller_swap/exercise
- id: aom8xa3q3ndx
  title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/04_caller_swap/exercise
- id: lybgc9id8yb2
  title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/04_caller_swap/exercise
- id: co2gylhucjoc
  title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/04_caller_swap/exercise
- id: pulgeonwhtoz
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
difficulty: intermediate
timelimit: 1500
enhanced_loading: null
---

# Chapter 4: Swap the Caller to Nexus

This is the moment the application stops being a monolith. The
Payments Workflow stops calling a local Activity for compliance and
starts calling the Compliance team's Nexus Operation instead. Once
that swap lands, no Compliance code runs in the Payments Worker.

## Why this chapter exists

Chapter 3 stood up the Compliance handler. Chapter 2 created the
Endpoint. Both halves of the routing infrastructure exist. What is
missing is the line in the Payments Workflow that says **"call
compliance through Nexus"** instead of **"call compliance as a local
Activity."**

In the Python SDK, that is two lines of code:

```python
nexus_client = workflow.create_nexus_client(
    service=ComplianceNexusService,
    endpoint=NEXUS_ENDPOINT,
)
result = await nexus_client.execute_operation(
    ComplianceNexusService.check_compliance,
    request,
    schedule_to_close_timeout=timedelta(minutes=10),
)
```

`workflow.create_nexus_client` builds a stub from the Service
contract. `execute_operation` invokes a specific Operation on the
stub. The Endpoint name is the only routing information the caller
needs: it does not know which namespace or task queue the handler
lives in. **That is the abstraction the Endpoint provides.**

Once the swap is in place, you also drop `check_compliance` from the
Payments Worker's Activities list. The Payments Worker no longer
needs that import; it lives entirely on the caller side of the Nexus
boundary.

## What you will do

- Apply **TODO 4** to swap the activity call for a Nexus call in
  `payments/workflows.py`.
- Apply **TODO 5** to drop `check_compliance` from the Payments
  Worker's Activities list and remove the import.
- Start the Compliance Worker (no changes from Chapter 3).
- Start the Payments Worker.
- Run the starter and watch the same three transactions flow, this
  time across the Nexus boundary.
- Inspect the Event History to confirm the two-event sync pattern
  (`NexusOperationScheduled`, `NexusOperationCompleted`).

## Step 1: Apply TODO 4 in `payments/workflows.py`

Open `payments/workflows.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). Find the
TODO 4 comment block. The current code calls compliance as an
Activity:

```python
# TODO 4: Replace this activity call with a Nexus call.
compliance: ComplianceResult = await workflow.execute_activity(
    check_compliance,
    comp_req,
    start_to_close_timeout=timedelta(seconds=30),
    retry_policy=RetryPolicy(
        initial_interval=timedelta(seconds=1),
        backoff_coefficient=2,
    ),
)
```

Replace that whole block with the Nexus call:

```python
nexus_client = workflow.create_nexus_client(
    service=ComplianceNexusService,
    endpoint=NEXUS_ENDPOINT,
)
compliance: ComplianceResult = await nexus_client.execute_operation(
    ComplianceNexusService.check_compliance,
    comp_req,
    schedule_to_close_timeout=timedelta(minutes=10),
)
```

The `NEXUS_ENDPOINT` constant is already defined at the top of the
file as `"compliance-endpoint"` (matching the Endpoint you created in
Chapter 2).

Two things to notice:

- **No retry policy.** The Nexus runtime handles retries for the
  Operation itself. If the handler returns a retryable error, Nexus
  backs off and retries; if it returns a non-retryable error, Nexus
  fails the Operation immediately. You will see those modes in
  Chapter 7.
- **Only one timeout for now.** `schedule_to_close_timeout` is the
  outer ceiling. There are two more timeouts (`schedule_to_start`,
  `start_to_close`) that matter once the handler runs as a workflow.
  Chapter 5 adds them.

Also remove the now-unused `check_compliance` import from the top of
the file. Your editor or `ruff` will flag it.

## Step 2: Apply TODO 5 in `payments/worker.py`

Open `payments/worker.py`. Find the TODO 5 comment in the Activities
list:

```python
worker = Worker(
    client,
    task_queue=TASK_QUEUE,
    workflows=[PaymentProcessingWorkflow],
    # TODO 5: Remove check_compliance from the activities list and the import above.
    activities=[validate_payment, execute_payment, check_compliance],
    activity_executor=executor,
)
```

Two cleanups:

1. Remove `check_compliance` from the `activities` list, leaving:

   ```python
   activities=[validate_payment, execute_payment],
   ```

2. Remove the corresponding import at the top of the file:

   ```python
   from compliance.activities import check_compliance
   ```

After this, **the Payments Worker no longer imports any Compliance
code.** Browse the file imports if you want to verify.

## Step 3: Start the Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal:

```bash,run
uv run python -m compliance.worker
```

Same Worker as Chapter 3. Leave it running.

## Step 4: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-2) terminal:

```bash,run
uv run python -m payments.worker
```

The startup banner should now advertise the `compliance-endpoint`
that workflows on this Worker will call into. (The Nexus client itself
is created inside the workflow at runtime, not registered on the
Worker.) The Activities list should be `validate_payment,
execute_payment` only.

## Step 5: Run the starter

Click the [button label="Starter" background="#444CE7"](tab-3)
terminal:

```bash,run
uv run python -m payments.starter
```

The same three results: TXN-A LOW, TXN-B MEDIUM with monitoring,
TXN-C declined HIGH. **Same outcomes, different mechanism.**

> TXN-B's MEDIUM auto-approval is still a property of the rule-based
> sync handler we are calling. Chapter 6 turns the MEDIUM path into a
> real human-in-the-loop review by replacing the sync handler with a
> workflow-backed one that waits on a Workflow Update.

## Step 6: Inspect the Event History

Click the
[button label="Temporal UI" background="#444CE7"](tab-4) tab. Switch
to `payments-namespace` using the namespace selector. Open
`payment-TXN-A` and look at the Event History.

Find the events that replaced `ActivityTaskScheduled`:

- `NexusOperationScheduled` (caller registers the call)
- `NexusOperationCompleted` (handler returns)

Two events. No `Started` event in between, because `check_compliance`
is currently a synchronous handler. (Chapter 5 introduces the async
handler and the third `NexusOperationStarted` event.)

Now switch the namespace selector to `compliance-namespace`. Open the
Workflows view. **You should see no workflows.** The compliance
handler ran inside the Compliance Worker's process; it did not start
a workflow on the Compliance side. Sync handlers leave no workflow
trail; only the caller's history records the call.

That asymmetry is the point of a sync handler. You get the contract,
the Endpoint, and the namespace boundary, **without** paying for a
second workflow. For short interactions, that is exactly what you
want.

## Step 7: Stop both Workers

Press `Ctrl+C` in both Worker terminals, or:

```bash,run
pkill -f "compliance.worker" || true
pkill -f "payments.worker"   || true
```

## Wrapping up

This was the structural pivot of the workshop. Before this chapter,
Compliance and Payments were one process. After this chapter, they
are two processes in two namespaces, talking through a typed contract
and a Nexus Endpoint.

You also met the **two-event sync pattern**:
`NexusOperationScheduled` followed by `NexusOperationCompleted`, with
no Started event in between. Anytime you see those two events in a
caller's history, you know you are looking at a sync Operation.

In Chapter 5 you convert `check_compliance` into a **workflow-backed
async Operation**. The handler will start a `ComplianceWorkflow` and
return its handle. The caller's history grows a third event,
`NexusOperationStarted`, and you get all the durability properties of
a real workflow on the Compliance side, without the caller needing
to know.
