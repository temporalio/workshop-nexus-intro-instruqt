---
slug: updates
id: vbpxjomxpihv
type: challenge
title: Updates Through Nexus
teaser: Add a human review path to the Compliance Workflow, implement submit_review
  as a real Update sender, and route reviewer decisions through Nexus to a running
  handler workflow.
notes:
- type: text
  contents: |-
    # Workflow Updates, validators, and the wait_condition pattern

    A Workflow Update is a synchronous request-response into a
    running workflow. Unlike a Signal (fire and forget), an Update
    has a return value and can be validated before it is
    accepted. It is exactly the right primitive for "human submits
    a decision, workflow uses it to continue."

    In this chapter you teach `ComplianceWorkflow` to pause for
    MEDIUM-risk transactions, accept a `review` Update from a
    human, and continue with the reviewer's decision. The
    `submit_review` sync Nexus handler from earlier chapters
    becomes a real Update sender. A small caller workflow,
    `ReviewCallerWorkflow`, gives reviewers a workflow-shaped
    interface instead of raw client calls.

    This is the most concept-dense chapter in the workshop. Take
    your time.
tabs:
- id: umy3ezgdsk0o
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/06_updates/exercise
- id: up4gg2xd1exm
  title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/06_updates/exercise
- id: visxtkvyk2l5
  title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/06_updates/exercise
- id: gdmmqkq8dxxi
  title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/06_updates/exercise
- id: dqf3hvrzdnpw
  title: Reviewer
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/06_updates/exercise
- id: my8s7ozl8c5i
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
difficulty: advanced
timelimit: 1800
enhanced_loading: null
---

This chapter gives the Compliance team a real human-in-the-loop
review path. MEDIUM-risk transactions stop being auto-approved and
start blocking until a human submits a decision. The mechanism is a
**Workflow Update**, exposed across the Nexus boundary by reusing the
`submit_review` Operation that has been a stub since Chapter 3.

# Why this chapter exists

So far MEDIUM-risk transactions auto-approve with an "AML
monitoring" note. That is fine for a demo but not for production. The
right behavior is: the workflow pauses, a reviewer looks at the
transaction, the reviewer submits an approve/decline decision, the
workflow continues with that decision.

To get there, four pieces must come together:

1. **A pause inside `ComplianceWorkflow`.** A `wait_condition` that
   blocks until a `_review_result` is set.
2. **A `review` Update handler with a validator.** The validator
   rejects review attempts before the workflow is ready (no
   auto-result yet) or after a decision was already made.
3. **A real `submit_review` Nexus handler.** Replaces the
   `NotImplementedError` stub with a Temporal client call that looks
   up the running compliance workflow and sends it the Update.
4. **A `ReviewCallerWorkflow` on the Payments side.** Reviewers
   trigger a workflow, not a raw Update call. Symmetric with how
   transactions trigger `PaymentProcessingWorkflow`.

A pre-supplied `payments/review_starter.py` script kicks off a
`ReviewCallerWorkflow`. You do not write the starter yourself.

# What you will do

- Apply **TODO 10** to add the review path to `ComplianceWorkflow`:
  `_review_result` state, the MEDIUM-risk branch in `run`, the
  `@workflow.update review` handler, and the `@review.validator`.
- Apply **TODO 11** to replace the `NotImplementedError` stub in
  `submit_review` with a real Update sender.
- Apply **TODO 12** to add `ReviewCallerWorkflow` and register it on
  the Payments Worker.
- Run the starter, watch TXN-B block, run the review starter, watch
  TXN-B unblock and complete.

# Step 1: Apply TODO 10 in `compliance/workflows.py`

Open `compliance/workflows.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). Three edits.

## 1a. Add review state in `__init__`

```python
def __init__(self) -> None:
    self._request: ComplianceRequest | None = None
    self._auto_result: ComplianceResult | None = None
    self._review_result: ComplianceResult | None = None
```

## 1b. Branch `run` on risk level

Replace the existing `run` body so LOW and HIGH return immediately,
and MEDIUM sleeps then waits:

```python
@workflow.run
async def run(self, request: ComplianceRequest) -> ComplianceResult:
    self._request = request
    self._auto_result = await workflow.execute_activity(
        check_compliance,
        request,
        start_to_close_timeout=timedelta(seconds=30),
    )

    if self._auto_result.risk_level != "MEDIUM":
        return self._auto_result

    await workflow.sleep(timedelta(seconds=10))
    await workflow.wait_condition(lambda: self._review_result is not None)
    return self._review_result
```

The `sleep(10)` is for the durability demo: it gives you a chance to
kill and restart the Compliance Worker mid-pause and watch the
workflow resume.

## 1c. Add the Update handler and validator

Below `run`, add:

```python
@workflow.update
async def review(self, approved: bool, explanation: str) -> ComplianceResult:
    self._review_result = ComplianceResult(
        transaction_id=self._request.transaction_id,
        approved=approved,
        risk_level="MEDIUM",
        explanation=explanation,
    )
    return self._review_result

@review.validator
def validate_review(self, approved: bool, explanation: str) -> None:
    if self._auto_result is None or self._auto_result.risk_level != "MEDIUM":
        raise ValueError("Workflow is not awaiting review")
    if self._review_result is not None:
        raise ValueError("Review already submitted")
```

The validator is what makes this Update **safe**. Without it, a
duplicate review submission could overwrite the first decision, or a
review for a non-MEDIUM transaction could silently succeed. The
validator runs synchronously in the workflow context before the
Update is accepted. If it raises, the Update is rejected and the
workflow state is unchanged.

# Step 2: Apply TODO 11 in `compliance/service_handler.py`

Open `compliance/service_handler.py`. Find the
`NotImplementedError` body inside `submit_review`. Replace it with the
real implementation:

```python
client = nexus.client()
handle: WorkflowHandle = client.get_workflow_handle_for(
    ComplianceWorkflow.run,
    workflow_id=f"compliance-{input.transaction_id}",
)
return await handle.execute_update(
    ComplianceWorkflow.review,
    args=[input.approved, input.explanation],
)
```

Add the import at the top of the file:

```python
from temporalio.client import WorkflowHandle
```

What is going on:

- `nexus.client()` returns the Temporal Client the Compliance Worker
  was initialized with. The handler is allowed to use it because
  sync handlers are not subject to workflow determinism rules; they
  are ordinary async Python. That Client is bound to
  `compliance-namespace`, which is the right namespace for this
  Update: the caller workflow lives in `payments-namespace`, but the
  `ComplianceWorkflow` we are sending the Update to lives in
  `compliance-namespace` alongside the handler.
- `client.get_workflow_handle_for(ComplianceWorkflow.run, ...)`
  produces a typed handle to the running compliance workflow,
  identified by the same workflow ID the async handler used in
  Chapter 5 (`compliance-{transaction_id}`).
- `handle.execute_update(ComplianceWorkflow.review, ...)` is a
  synchronous request: it sends the Update, runs the validator, runs
  the handler, and returns the handler's return value.

The whole `submit_review` sync handler completes in well under 10
seconds. **The workflow runs as long as it needs to; the sync handler
is just a forwarder.**

# Step 3: Apply TODO 12 in `payments/workflows.py` and `payments/worker.py`

## 3a. Add `ReviewCallerWorkflow` to `payments/workflows.py`

Open `payments/workflows.py`. Add `ReviewRequest` to the
`imports_passed_through` block at the top of the file (so the
workflow file can reference the `ReviewRequest` type from
`shared.models`).

Then add a second workflow class at the bottom of the file:

```python
@workflow.defn
class ReviewCallerWorkflow:
    @workflow.run
    async def submit_review(self, request: ReviewRequest) -> ComplianceResult:
        nexus_client = workflow.create_nexus_client(
            service=ComplianceNexusService,
            endpoint=NEXUS_ENDPOINT,
        )
        return await nexus_client.execute_operation(
            ComplianceNexusService.submit_review,
            request,
            schedule_to_close_timeout=timedelta(seconds=10),
        )
```

This workflow is the mirror image of `PaymentProcessingWorkflow` for
the reviewer flow. Reviewers do not call the Update directly; they
trigger a `ReviewCallerWorkflow`, which goes through Nexus, which
calls `submit_review`, which sends the Update.

## 3b. Register `ReviewCallerWorkflow` in `payments/worker.py`

Open `payments/worker.py`. Update the import:

```python
from payments.workflows import PaymentProcessingWorkflow, ReviewCallerWorkflow
```

Update the `workflows` list in the `Worker(...)` call:

```python
workflows=[PaymentProcessingWorkflow, ReviewCallerWorkflow],
```

# Step 4: Start the Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal:

```bash,run
uv run python -m compliance.worker
```

# Step 5: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-2) terminal:

```bash,run
uv run python -m payments.worker
```

The startup banner should now list both `PaymentProcessingWorkflow`
and `ReviewCallerWorkflow`.

# Step 6: Run the starter

Click the [button label="Starter" background="#444CE7"](tab-3)
terminal:

```bash,run
uv run python -m payments.starter
```

What you should see:

- TXN-A completes immediately (LOW risk).
- The starter then moves on to TXN-B and **blocks**. The terminal
  sits on the `execute_workflow` call. On the Compliance side,
  `compliance-TXN-B` ran the auto-check (returned MEDIUM), slept for
  10 seconds, and is now waiting on `wait_condition`. Nothing will
  unblock it until the review arrives.

Leave the starter running.

# Step 7: Submit the review

Click the [button label="Reviewer" background="#444CE7"](tab-4)
terminal:

```bash,run
uv run python -m payments.review_starter
```

The review starter is pre-supplied. It builds a `ReviewRequest`
approving TXN-B with an explanation, runs `ReviewCallerWorkflow`
(which goes through `compliance-endpoint` -> `submit_review` ->
Update), and prints the result.

Watch the [button label="Starter" background="#444CE7"](tab-3) terminal:
**TXN-B should unblock** as soon as the review lands. The starter
moves on to TXN-C, which declines as HIGH risk, and exits.

# Step 8: Inspect the Update events

Click the
[button label="Temporal UI" background="#444CE7"](tab-5) tab. Use the
namespace selector at the top of the left navigation to switch to
`compliance-namespace` and open `compliance-TXN-B`. In the Event
History, find:

- `WorkflowExecutionUpdateAccepted` (the validator passed)
- `WorkflowExecutionUpdateCompleted` (the handler returned)

Now use the same selector to switch to `payments-namespace` and open
`payment-TXN-B`. The Nexus operation still shows three events on the
Payments-side history (`Scheduled`, `Started`, `Completed`), but the
gap between `Started` and `Completed` is much wider than the gap for
TXN-A. **That gap is the time the workflow spent waiting for human
review.**

There is also a separate workflow on the Payments side called
`review-TXN-B` (the `ReviewCallerWorkflow`'s execution). It has its
own three-event Nexus pattern for the `submit_review` Operation.

# Step 9 (optional): Durability test

Restart the starter from Step 6. While TXN-B is paused (between
"started" and "completed"), kill the Compliance Worker. Wait a few
seconds. Restart it. Then run the review starter (Step 7). The Update
still gets through because the handler workflow resumes from where it
stopped. Durability works because the workflow is real, not a sync
handler.

# Step 10: Stop both Workers

Press `Ctrl+C` in both Worker terminals, or:

```bash,run
pkill -f "compliance.worker" || true
pkill -f "payments.worker"   || true
```

# Wrapping up

You added a complete human-in-the-loop review path. MEDIUM-risk
transactions block until a reviewer submits a decision, the decision
flows through Nexus into the running compliance workflow, and the
workflow resumes with the reviewer's outcome. The whole thing was
done with one Update handler, one validator, one sync Nexus handler
that forwards to the Update, and one short caller workflow.

In Chapter 7 you switch from the happy path to the **lifecycle path**:
cancellation, retryable and non-retryable errors, and the per-pair
circuit breaker. Same handler, several new failure modes.

> Troubleshooting tips:
>
> - If TXN-B never blocks, your `run` method is probably returning
>   `self._auto_result` for MEDIUM as well as LOW/HIGH. Re-read the
>   risk-level branch in TODO 10.
> - If the review starter raises, double-check that
>   `ReviewCallerWorkflow` is registered on the Payments Worker
>   (TODO 12) and that `submit_review` is no longer raising
>   `NotImplementedError` (TODO 11).
> - If the validator never fires, verify it is a method named
>   `validate_review` decorated with `@review.validator` (the name
>   matches the Update method).
