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
- id: rsans7ikp6kx
  title: Solution
  type: code
  hostname: workshop
  path: /root/workshop/exercises/07_lifecycle/solution
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
difficulty: advanced
timelimit: 1500
enhanced_loading: false
---

# Chapter 7: Cancellation, Errors, and the Circuit Breaker

Up to now you have only seen the happy path. This chapter stress-tests
the system: what happens when the handler raises a non-retryable
error, when it raises a retryable error, when the caller cancels in
flight, and when the same handler keeps failing until the circuit
breaker trips. The behavior of each is the visible payoff for using
Nexus instead of HTTP-wrapped activities; the platform handles all of
this for you.

## Why this chapter exists

Nexus errors split into two kinds:

- **Non-retryable** (`nexusrpc.OperationError` with state `FAILED`,
  or `HandlerError` with non-retryable type like `BAD_REQUEST`,
  `NOT_FOUND`, etc.): the operation cannot succeed regardless of how
  many times you try. Caller workflow records `NexusOperationFailed`
  and stops.
- **Retryable** (`nexusrpc.HandlerError` with retryable type like
  `INTERNAL`, `RESOURCE_EXHAUSTED`, `UNAVAILABLE`): treated as a
  transient failure. The caller backs off and retries automatically.

Cancellation is its own dimension. A Nexus operation runs as a
workflow on the handler side, and cancellation propagates from the
caller's workflow through the Nexus boundary to the handler workflow.
You do not write any cancel-forwarding code; the platform does it.

The circuit breaker is a guardrail. If a single handler endpoint keeps
failing retryably, retries pile up across every caller in the same
namespace. To prevent that from saturating the platform, Temporal
opens a per-(caller-Namespace, Endpoint) breaker after **5 consecutive
retryable failures**, blocks new operations for **60 seconds**, then
half-opens with a single probe request. Pass the probe and the
breaker closes; fail it and the breaker reopens for another 60.

## What you will do

- Apply **TODO 13** to add failure-injection branches to the
  `check_compliance` handler. Specific transaction-id prefixes
  (`TXN-FAIL-NONRETRY-*`, `TXN-FAIL-RETRY-*`, `TXN-CIRCUIT-*`) raise
  matching errors before the workflow starts. Normal transactions
  (TXN-A, TXN-B, TXN-C) and the cancellation case (`TXN-CANCEL-*`)
  flow through unchanged.
- Run the pre-supplied lifecycle starter that exercises four
  scenarios end-to-end.
- Use the Temporal UI and the `temporal workflow describe` CLI to
  observe each scenario.

> [!TIP]
> Stuck on the failure-injection branches? The **Solution** tab shows
> the finished file. Try the exercise first, then peek if you need to.

## Step 1: Apply TODO 13 in `compliance/service_handler.py`

Open `compliance/service_handler.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). Find the
TODO 13 comment inside `check_compliance`, before the
`ctx.start_workflow` call. Add the failure branches:

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
        id=f"compliance-{input.transaction_id}",
        id_conflict_policy=WorkflowIDConflictPolicy.USE_EXISTING,
    )
```

Also add `import nexusrpc` at the top of the file. (`import
nexusrpc.handler` already binds the name implicitly, but listing the
top-level package explicitly makes the imports self-documenting.)

The branches are mutually exclusive with the normal `start_workflow`
path. A normal transaction never matches a prefix and runs as before.

## Step 2: Start the Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-2)
terminal:

```bash,run
uv run python -m compliance.worker
```

## Step 3: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-3) terminal:

```bash,run
uv run python -m payments.worker
```

## Step 4: Run the lifecycle starter

Click the
[button label="Lifecycle Starter" background="#444CE7"](tab-4)
terminal. Run the pre-supplied starter:

```bash,run
uv run python -m payments.lifecycle_starter
```

This script runs four scenarios in sequence (roughly a minute and a
half end to end, depending on how fast retries land). Each scenario
hits a different lifecycle path. **Keep an eye on the terminal
output as each scenario runs**, then use the Inspector tab in Step 5
to drill in.

The four scenarios:

- **Scenario A: non-retryable failure.** TXN-FAIL-NONRETRY-1 hits the
  `OperationError` branch. The caller workflow records
  `NexusOperationFailed` immediately and ends in `Failed` state with
  no retries.
- **Scenario B: retryable failure with backoff.** TXN-FAIL-RETRY-1
  hits the `HandlerError` branch. The caller's Pending Nexus
  Operations show `BackingOff` state with the attempt count rising.
  The starter waits ~20 seconds, then `terminate()`s the workflow so
  the demo can move on. (We use `terminate()` rather than `cancel()`
  here because a `BackingOff` Nexus operation would not surface a
  cancel until its next attempt; terminate is unconditional.)
- **Scenario C: cancellation propagation.** TXN-CANCEL-1 is a $12,000
  international transfer (MEDIUM risk). It runs the auto-check, then
  pauses in the `wait_condition` from Chapter 6. After 3 seconds, the
  starter cancels the **payment** workflow. Cancellation flows
  through the Nexus boundary into `compliance-TXN-CANCEL-1`, and both
  workflows end in `Canceled`.
- **Scenario D: circuit breaker.** Six TXN-CIRCUIT-* transactions in
  rapid succession all hit the `HandlerError` branch. After ~5
  consecutive failures, the breaker on
  `(payments-namespace, compliance-endpoint)` opens. The remaining
  TXN-CIRCUIT-* workflows show `State: Blocked` with
  `BlockedReason: The circuit breaker is open.` The starter
  terminates the lot when scenario D ends.

## Step 5: Inspect each scenario

Click the [button label="Inspector" background="#444CE7"](tab-5)
terminal. Use it to run `temporal workflow describe` and `temporal
workflow show` against the workflows the starter is touching.

### Scenario A inspection

After the starter has finished scenario A:

```bash,run
temporal workflow show -w payment-TXN-FAIL-NONRETRY-1 -n payments-namespace
```

In the Event History, look for `NexusOperationScheduled` followed
directly by `NexusOperationFailed`. No retries, no `Started` event.
The workflow status is `Failed`.

### Scenario B inspection

While the starter is in scenario B (roughly twenty seconds, give or
take), run repeatedly:

```bash,run
temporal workflow describe -w payment-TXN-FAIL-RETRY-1 -n payments-namespace
```

You should see a `Pending Nexus Operations` block with
`State: BackingOff` and `Attempt` rising. **Run the command quickly;
once the starter terminates the workflow at the end of the scenario,
the BackingOff state is gone from the snapshot.** This is one of the
spots where `lessons-learned.md` calls out the importance of
in-flight observation.

### Scenario C inspection

After the starter ends scenario C:

```bash,run
temporal workflow describe -w payment-TXN-CANCEL-1 -n payments-namespace
```

```bash,run
temporal workflow describe -w compliance-TXN-CANCEL-1 -n compliance-namespace
```

The payment workflow ends `Canceled`. The Nexus operation in its
history shows `NexusOperationCanceled`. **The handler workflow on the
Compliance side is also `Canceled`**, even though no one ever sent a
cancel directly to it. Cancellation flowed through the Nexus
boundary on its own.

The available cancellation types on `nexus_client.execute_operation`
are `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, and `WAIT_COMPLETED`.
The default is `WAIT_COMPLETED`: the caller waits for the handler to
finish cleanup before its own cancel completes. Pick the weakest one
that meets your correctness needs.

> [!NOTE]
> Sync Nexus operations cannot be canceled because they hold no
> operation token. Cancellation only applies to async,
> workflow-backed handlers like `ComplianceWorkflow`. The Chapter 5
> switch to `@nexus.workflow_run_operation` is what makes scenario C
> possible at all.

> [!NOTE]
> A small wire-format aside: at the proto layer the SDK enum
> `WAIT_REQUESTED` is named `WAIT_CANCELLATION_REQUESTED`. If you read
> raw event payloads or replay output you will see the longer form.

### Scenario D inspection

While the starter is in scenario D (after the first ~5 transactions
have failed):

```bash,run
temporal workflow describe -w payment-TXN-CIRCUIT-6 -n payments-namespace
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
[button label="Temporal UI" background="#444CE7"](tab-6) tab and
browse `payments-namespace`. The blocked workflows render with the
same banner.

## Step 6: Stop both Workers

```bash,run
pkill -f "compliance.worker" || true
pkill -f "payments.worker"   || true
```

## Wrapping up

You exercised every off-happy-path mode of a Nexus Operation. Errors
split into retryable and non-retryable. Cancellation propagates
through the boundary so handlers can clean up. The circuit breaker
protects the platform when one handler endpoint misbehaves. None of
this required wiring on your part beyond the failure injections in
TODO 13; the Nexus runtime handles all of it.

Chapter 8 is the polyglot demo: the same Service contract, fulfilled
by a Java handler instead of the Python one, with **no Python code
change** on the caller side. Same Endpoint, same task queue,
different language.

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

> [!NOTE]
> Knowledge check:
>
> - Which `HandlerErrorType` values are retryable, and which mark the
>   operation as permanently failed?
> - Why does cancellation propagate from a caller workflow to a
>   handler workflow without any cancel-forwarding code on your side?
> - The circuit breaker opens after how many consecutive retryable
>   failures, and on which scope (per-Operation, per-Endpoint,
>   per-(Namespace, Endpoint) pair)?
