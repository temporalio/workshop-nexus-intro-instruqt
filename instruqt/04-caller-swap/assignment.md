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
    on another team's Worker. Payments imports only the shared
    contract and the Compliance request/result types; no handler
    or activity code.

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
- id: kc5vcvy2qmty
  title: Solution
  type: code
  hostname: workshop
  path: /root/workshop/exercises/04_caller_swap/solution
difficulty: intermediate
timelimit: 1500
enhanced_loading: false
---

This is the moment the application stops being a monolith. The
Payments Workflow stops calling a local Activity for compliance and
starts calling the Compliance team's Nexus Operation instead. Once
that swap lands, no Compliance code runs in the Payments Worker.

## What You're Solving

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

- Apply **TODOs 4a–4b** to swap the activity call for a Nexus call in
  `payments/workflows.py` and remove the now-unused activity import.
- Apply **TODOs 5a–5b** to drop `check_compliance` from the Payments
  Worker's Activities list and remove the now-unused import.
- Start the Compliance Worker (no changes from Chapter 3).
- Start the Payments Worker.
- Run the starter and watch the same three transactions flow, this
  time across the Nexus boundary.
- Inspect the Event History to confirm the two-event sync pattern
  (`NexusOperationScheduled`, `NexusOperationCompleted`).

> [!NOTE]
> Stuck on a TODO? The **Solution** tab (rightmost) shows the finished
> file. Try the exercise first, then peek if you need to.

## Step 1: Apply TODOs 4a–4b in `payments/workflows.py`

Open `payments/workflows.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). Two TODO 4
markers: one above the `check_compliance` import (TODO 4a), and one
above the existing activity call (TODO 4b).

### TODO 4b: Replace the activity call with a Nexus call

The current code calls compliance as an Activity. Replace the entire
block with a Nexus call:

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

- **No caller-side retry policy; Nexus owns retries of the
  StartOperation, bounded by `schedule_to_close_timeout`.** If the
  handler returns a retryable error, Nexus backs off and retries the
  start; if it returns a non-retryable error, Nexus fails the
  Operation immediately. The retry policy itself is built-in and not
  user-tunable; only the timeout envelope is. When a handler is
  workflow-backed, the activities and child workflows *inside* that
  workflow carry their own `RetryPolicy(...)` configurations, but
  those are owned by the Compliance team's code, not by this caller.
- **Only one timeout for now.** `schedule_to_close_timeout` is the
  outer envelope across all retried StartOperation attempts; it does
  not bound a single attempt. Each individual sync handler invocation
  is bounded by the 10-second sync handler deadline (measured from
  the caller's History Service through matching, so the handler's
  actual budget is shorter), and the machinery retries timed-out
  attempts until `schedule_to_close` exhausts. There are two more
  timeouts (`schedule_to_start`, `start_to_close`) that matter once
  the handler runs as a workflow.

### TODO 4a: Remove the unused activity import

After TODO 4b, the file no longer references `check_compliance`
directly. Delete the line:

```python
from compliance.activities import check_compliance
```

Your editor or `ruff` will flag it as unused if you forget.

## Step 2: Apply TODOs 5a–5b in `payments/worker.py`

Open `payments/worker.py`. Find the two TODO 5 markers: one above the
`from compliance.activities import check_compliance` line, and one
above the `activities=[...]` line.

### TODO 5a: Remove the import

At the top of the file, delete this line:

```python
from compliance.activities import check_compliance
```

### TODO 5b: Remove from the Activities list

Inside the `Worker(...)` call, drop `check_compliance` from the list:

```python
activities=[validate_payment, execute_payment],
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

The startup banner now includes a `Nexus:` line:

```bash,nocopy
  Nexus: ComplianceNexusService -> compliance-endpoint
```

That line just documents which Service contract the workflows on this
Worker will call against which Endpoint name. (The Nexus client itself
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

> [!NOTE]
> TXN-B's MEDIUM auto-approval is still a property of the rule-based
> sync handler we are calling. Later in this workshop the MEDIUM path
> becomes a real human-in-the-loop review by replacing the sync
> handler with a workflow-backed one that waits on a Workflow Update.

## Step 6: Inspect the Event History

Click the
[button label="Temporal UI" background="#444CE7"](tab-4) tab. Switch
to `payments-namespace` using the namespace selector. Open
`payment-ch04-TXN-A` and look at the Event History.

Find the events that replaced `ActivityTaskScheduled`:

- `NexusOperationScheduled` (caller schedules the call; Nexus
  Machinery now owns delivery)
- `NexusOperationCompleted` (handler returns)

Two events. No `Started` event in between, because `check_compliance`
is currently a synchronous handler.

Now switch the namespace selector to `compliance-namespace`. Open the
Workflows view. **You should see no workflows.** The compliance
handler ran inside the Compliance Worker's process; it did not start
a workflow on the Compliance side. Sync handlers leave no workflow
trail; only the caller's history records the call.

That asymmetry is the point of a sync handler. You get the contract,
the Endpoint, and the namespace boundary, **without** paying for a
second workflow. For short interactions, that is exactly what you
want.

## Key Takeaways

This was the structural pivot of the workshop. Before this chapter,
Compliance and Payments were one process. After this chapter, they
are two processes in two namespaces, talking through a typed contract
and a Nexus Endpoint.

You also met the **two-event sync pattern**:
`NexusOperationScheduled` followed by `NexusOperationCompleted`, with
no Started event in between. Anytime you see those two events in a
caller's history, you know you are looking at a handler that
responded synchronously.

The structural pivot is complete: a typed Service contract, a Nexus
Endpoint, two namespaces, two Workers, and a caller that no longer
imports any handler-side code. The caller's Event History records
the cross-namespace call as two durable events owned by the Nexus
machinery.
