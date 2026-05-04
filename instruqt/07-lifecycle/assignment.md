---
slug: lifecycle
id: eghp7t8lhrwr
type: challenge
title: Cancellation, Errors, and the Circuit Breaker
teaser: Inject failure modes into the Compliance handler, run a lifecycle starter
  that exercises each one, and observe non-retryable errors, retryable backoff, cancellation
  propagation, and circuit-breaker open state in the UI and CLI.
notes:
- type: text
  contents: |-
    # The lifecycle a Nexus Operation can take

    A successful Operation flows Scheduled to Started to Completed.
    But there are four ways an Operation can leave the happy path:

    - **Non-retryable failure** (`OperationError`): caller records
      `NexusOperationFailed`, no retries.
    - **Retryable failure** (`HandlerError`): caller backs off and
      retries, visible as `BackingOff` state in Pending Operations.
    - **Cancellation**: cancellation of the caller workflow
      propagates through the Nexus boundary to the handler workflow.
    - **Circuit breaker**: after 5 consecutive retryable failures
      on the same (caller-Namespace, Endpoint) pair, the breaker
      opens and blocks new Operations for 60 seconds.

    Each of these is observable in the Web UI or via
    `temporal workflow describe`. The lifecycle starter exercises
    all four in sequence.
tabs:
- id: 1t5itdkletav
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/07_lifecycle/exercise
- id: jju6cnunjt9k
  title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: srnfctofjfqh
  title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: 3h9wmofathz4
  title: Lifecycle Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: m7aayegbg7s7
  title: Inspector
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: zqmyzspdreqz
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
- id: rsans7ikp6kx
  title: Solution
  type: code
  hostname: workshop
  path: /root/workshop/exercises/07_lifecycle/solution
difficulty: advanced
timelimit: 1500
enhanced_loading: false
---

Up to now you have only seen the happy path. This chapter stress-tests
the system: what happens when the handler raises a non-retryable
error, when it raises a retryable error, when the caller cancels in
flight, and when the same handler keeps failing until the circuit
breaker trips. The behavior of each is the visible payoff for using
Nexus instead of HTTP-wrapped activities; the platform handles all of
this for you.

## What You're Solving

Nexus errors split into two kinds:

- **Non-retryable** (`nexusrpc.OperationError` with state `FAILED`,
  or `HandlerError` with non-retryable type like `BAD_REQUEST`,
  `NOT_FOUND`, `NOT_IMPLEMENTED`, etc.): the operation cannot succeed
  regardless of how many times you try. Caller workflow records
  `NexusOperationFailed` and stops.
- **Retryable** (`nexusrpc.HandlerError` with retryable type like
  `INTERNAL`, `RESOURCE_EXHAUSTED`, `UNAVAILABLE`): treated as a
  transient failure. The caller backs off and retries automatically.

Cancellation is its own dimension. A workflow-backed Nexus operation
runs as a workflow on the handler side, and cancellation propagates
from the caller's workflow through the Nexus boundary to the handler
workflow. You do not write any cancel-forwarding code; the platform
does it.

The circuit breaker is a guardrail. If a single handler endpoint keeps
failing retryably, retries pile up across every caller in the same
caller-Namespace pointing at that Endpoint. To prevent that from
saturating the platform, Temporal opens a per-(caller-Namespace,
Endpoint) breaker after **5 consecutive retryable failures**, blocks
new operations for **60 seconds**, then half-opens with a single probe
request. Pass the probe and the breaker closes; fail it and the
breaker reopens for another 60.

## What you will do

- Apply **TODOs 13a–13b** to add the top-level `nexusrpc` import and
  failure-injection branches to the `check_compliance` handler.
  Specific transaction-id prefixes (`TXN-FAIL-NONRETRY-*`,
  `TXN-FAIL-RETRY-*`, `TXN-CIRCUIT-*`) raise matching errors before
  the workflow starts. Normal transactions (TXN-A, TXN-B, TXN-C) and
  the cancellation case (`TXN-CANCEL-*`) flow through unchanged.
- Run the pre-supplied lifecycle starter that exercises four
  scenarios end-to-end.
- Use the Temporal UI and the `temporal workflow describe` CLI to
  observe each scenario.

> [!NOTE]
> Stuck on the failure-injection branches? The **Solution** tab
> (rightmost) shows the finished file. Try the exercise first, then
> peek if you need to.

## Step 1: Apply TODOs 13a–13b in `compliance/service_handler.py`

Open `compliance/service_handler.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). Two TODO 13
markers: one near the top of the file (TODO 13a), and one inside the
`check_compliance` body before `ctx.start_workflow` (TODO 13b).

### TODO 13a: Add the top-level `nexusrpc` import

Above the existing `import nexusrpc.handler` line, add:

```python
import nexusrpc
```

`import nexusrpc.handler` binds the name implicitly, but listing the
top-level package explicitly makes the imports self-documenting and
gives the next step access to `nexusrpc.OperationError` and
`nexusrpc.HandlerError`.

### TODO 13b: Add the failure-injection branches

Inside `check_compliance`, replace the TODO 13b marker with three
prefix-matched branches before `ctx.start_workflow`:

```python
@nexus.workflow_run_operation
async def check_compliance(
    self, ctx: nexus.WorkflowRunOperationContext, input: ComplianceRequest
) -> nexus.WorkflowHandle[ComplianceResult]:
    txn_id = input.transaction_id

    if txn_id.startswith("TXN-FAIL-NONRETRY"):
        raise nexusrpc.OperationError(
            "Permanent compliance failure (non-retryable)",
            state=nexusrpc.OperationErrorState.FAILED,
        )
    if txn_id.startswith("TXN-FAIL-RETRY") or txn_id.startswith("TXN-CIRCUIT"):
        raise nexusrpc.HandlerError(
            "Transient compliance failure (retryable)",
            type=nexusrpc.HandlerErrorType.INTERNAL,
        )

    return await ctx.start_workflow(
        ComplianceWorkflow.run,
        input,
        id=f"compliance-ch07-{input.transaction_id}",
        id_conflict_policy=WorkflowIDConflictPolicy.USE_EXISTING,
    )
```

The branches are mutually exclusive with the normal `start_workflow`
path. A normal transaction never matches a prefix and runs as before.

## Step 2: Start the Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal:

```bash,run
uv run python -m compliance.worker
```

## Step 3: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-2) terminal:

```bash,run
uv run python -m payments.worker
```

## Step 4: Run the lifecycle starter

Click the
[button label="Lifecycle Starter" background="#444CE7"](tab-3)
terminal. Run the pre-supplied starter:

```bash,run
uv run python -m payments.lifecycle_starter
```

This script runs four scenarios in sequence and **pauses between each
one** (after A, after B, after C), waiting for you to press Enter
before moving on. That gives you time to inspect the workflow from
the previous scenario in the Inspector tab (Step 5) before the next
scenario kicks off. Total runtime is gated on you, not on a fixed
clock.

The flow you will see in this terminal:

1. Scenario A runs and prints its results.
2. Starter prints `Scenario A done. ... press Enter to continue` and blocks.
3. You switch to the Inspector tab, run the Step 5 commands for A, then come back here and press Enter.
4. Scenario B runs, then pauses again. Repeat for C.
5. Scenario D runs last and does not pause; the starter ends after D.

The four scenarios:

- **Scenario A: non-retryable failure.** TXN-FAIL-NONRETRY-1 hits the
  `OperationError` branch. The caller workflow records
  `NexusOperationFailed`, raises `NexusOperationError` inside the
  workflow, and ends in `Failed` because the code lets the exception
  propagate. No retries.
- **Scenario B: retryable failure with backoff.** TXN-FAIL-RETRY-1
  hits the `HandlerError` branch. The caller's Pending Nexus
  Operations show `BackingOff` state with the attempt count rising.
  The starter waits ~20 seconds, then `terminate()`s the workflow so
  the demo can move on. We use `terminate()` rather than `cancel()`
  here because cancellation propagation goes through the same
  outbound queue and would not interrupt a `BackingOff` operation
  until its next retry attempt.
- **Scenario C: cancellation propagation.** TXN-CANCEL-1 is a $12,000
  transfer that classifies as MEDIUM risk because the amount exceeds
  the $10,000 threshold (the lifecycle starter sends domestic US-to-US
  for this scenario). It runs the auto-check, classifies as MEDIUM,
  and enters the 10-second `workflow.sleep` from Chapter 6's durability
  demo. After 3 seconds, the starter cancels the **payment** workflow.
  Cancellation flows through the Nexus boundary into
  `compliance-ch07-TXN-CANCEL-1`, and both workflows end in `Canceled`.
- **Scenario D: circuit breaker.** Six TXN-CIRCUIT-* transactions in
  rapid succession all hit the `HandlerError` branch. After ~5
  consecutive failures, the breaker on
  `(payments-namespace, compliance-endpoint)` opens. The remaining
  TXN-CIRCUIT-* workflows show `State: Blocked` with
  `BlockedReason: The circuit breaker is open.` The starter
  terminates the lot when scenario D ends.

## Step 5: Inspect each scenario

Click the [button label="Inspector" background="#444CE7"](tab-4)
terminal. Use it to run `temporal workflow describe` and `temporal
workflow show` against the workflows the starter is touching. Run
these commands **during the pause after each scenario** (the starter
is blocked on `press Enter to continue`). Once you have inspected,
switch back to the Lifecycle Starter tab and press Enter to advance
to the next scenario.

### Scenario A inspection

While the starter is paused after scenario A:

```bash,run
temporal workflow show -w payment-ch07-TXN-FAIL-NONRETRY-1 -n payments-namespace
```

In the Event History, look for `NexusOperationScheduled` followed
directly by `NexusOperationFailed`. No retries, no `Started` event.
The workflow status is `Failed`.

### Scenario B inspection

While the starter is paused after scenario B (the starter has already
called `terminate()` by the time you see the pause prompt), run:

```bash,run
temporal workflow describe -w payment-ch07-TXN-FAIL-RETRY-1 -n payments-namespace
```

At the pause point the workflow is `Terminated` and Pending Nexus
Operations is empty. The Event History tells the same story without
timing pressure. Open it in the Inspector tab:

```bash,run
temporal workflow show -w payment-ch07-TXN-FAIL-RETRY-1 -n payments-namespace
```

Look for repeated `NexusOperationStarted` attempts followed by
`NexusOperationFailed` events with retryable `HandlerError` payloads,
then a final `WorkflowExecutionTerminated`. The retries-and-backoff
behavior is recorded in history and can be read at your own pace,
which is more reliable than catching `State: BackingOff` live during
the 20-second retry window.

If you would rather watch it live, run `temporal workflow describe`
in the Inspector tab the moment scenario B starts printing in the
Lifecycle Starter terminal; the `BackingOff` state and climbing
`Attempt` counter are visible until `terminate()` fires.

### Scenario C inspection

While the starter is paused after scenario C:

```bash,run
temporal workflow describe -w payment-ch07-TXN-CANCEL-1 -n payments-namespace
```

```bash,run
temporal workflow describe -w compliance-ch07-TXN-CANCEL-1 -n compliance-namespace
```

The payment workflow ends `Canceled`. The Nexus operation in its
history shows `NexusOperationCanceled`. **The handler workflow on the
Compliance side is also `Canceled`**, even though no one ever sent a
cancel directly to it. Cancellation flowed through the Nexus
boundary on its own.

The available cancellation types on `nexus_client.execute_operation`
are `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, and `WAIT_COMPLETED`.
The default is `WAIT_COMPLETED`: the caller waits for the handler
operation to reach a terminal state (`Completed`, `Failed`, or
`Canceled`, depending on whether the handler honored the cancel)
before its own cancel completes. Pick the loosest cancellation
guarantee that still meets correctness; `ABANDON` is the loosest,
`WAIT_COMPLETED` the strongest.

> [!NOTE]
> Sync Nexus operations cannot be canceled because they hold no
> operation token. Cancellation only applies to async,
> workflow-backed handlers like `ComplianceWorkflow`. The earlier
> switch to `@nexus.workflow_run_operation` is what makes scenario C
> possible at all.

> [!NOTE]
> A small wire-format aside: the proto enum is
> `WAIT_CANCELLATION_REQUESTED`; Python's SDK shortens it to
> `WAIT_REQUESTED`. If you read raw event payloads or replay output
> you will see the longer form.

### Scenario D inspection

Scenario D does not have a pause after it; the starter terminates the
six TXN-CIRCUIT workflows and exits. Inspect during the 12-second
window scenario D waits for retries and the breaker to trip (after
the first ~5 transactions have failed):

```bash,run
temporal workflow describe -w payment-ch07-TXN-CIRCUIT-6 -n payments-namespace
```

You should see:

```bash,nocopy
State           Blocked
BlockedReason   The circuit breaker is open.
```

The breaker stays open for 60 seconds, then enters half-open and
probes with a single request. If that request succeeds (it would not
in this demo, since every TXN-CIRCUIT- transaction still fails),
the breaker closes again.

Switch to the
[button label="Temporal UI" background="#444CE7"](tab-5) tab and
browse `payments-namespace`. The blocked workflows render with the
same banner.

## Key Takeaways

You exercised every off-happy-path mode of a Nexus Operation. Errors
split into retryable and non-retryable. Cancellation propagates
through the boundary so handlers can clean up. The circuit breaker
protects the platform when one handler endpoint misbehaves. None of
this required wiring on your part beyond the failure injections in
TODO 13; the Nexus runtime handles all of it.

With this chapter you have the full Nexus operation lifecycle in
hand: success, non-retryable failure, retryable backoff, cancellation
propagation, and the per-(caller-Namespace, Endpoint) circuit
breaker. The Service contract you defined and refined across earlier
chapters carries all of that behavior automatically; the failure
modes are platform features, not code you wrote.

> [!IMPORTANT]
> Production take-aways:
>
> - Use `OperationError(state=FAILED)` for "this can't succeed."
> - Use `HandlerError(type=INTERNAL)` for transient failures.
>   Picking the right `HandlerErrorType` is part of API design.
> - The circuit breaker is per (caller-Namespace, Endpoint) pair. A
>   single misbehaving endpoint cannot bring down all callers in the
>   same namespace.
> - Cancellation type defaults to `WAIT_COMPLETED`. Use lighter
>   modes when you cannot afford to wait for handler cleanup.
