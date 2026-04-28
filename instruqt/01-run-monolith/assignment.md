---
slug: run-monolith
id: i71xyii6vuau
type: challenge
title: Run the Monolith
teaser: Run a payment processing monolith and see how the Compliance team's logic
  is welded into the Payments team's worker.
notes:
- type: text
  contents: |-
    # Welcome to the Workshop!

    This is the Introduction to Temporal Nexus workshop. Over the next
    few hours you will take a small payment processing application that
    starts life as a monolith and decouple it across team and namespace
    boundaries using Temporal Nexus.

    A Temporal dev server is already running in your environment, with
    `payments-namespace` and `compliance-namespace` pre-created. Open
    the **Temporal UI** tab to confirm it is healthy.

    In this first chapter you will run the application as it exists
    today, **before** any Nexus is involved, so you can see exactly
    what we are about to change.
tabs:
- id: tjh8uhfad73e
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/01_run_monolith/solution
- id: zryxsxtar8aj
  title: Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/01_run_monolith/solution
- id: 4jyrbhbaqyxv
  title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/01_run_monolith/solution
- id: ro73nysqnwlu
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
difficulty: basic
timelimit: 600
enhanced_loading: null
---

# Chapter 1: Run the Monolith

Before you decouple anything, run the application as it ships today and
feel where the seams are. This chapter is observation only. There is no
code to edit.

## Why this chapter exists

Every distributed-systems story has a "before" picture, and this is ours.

The Payments team owns a workflow called `PaymentProcessingWorkflow`. It
takes a transaction, validates the payment, runs a compliance check, and
either captures the funds or declines the transaction. In the version
you are about to run, **all of that runs in one Worker, in one
namespace, with one set of dependencies**. The compliance check is
implemented as an Activity (`check_compliance`) imported into the
Payments Worker.

> A note on framing: this monolith is the *most extreme* form of
> coupling, where Compliance code is registered as an activity on the
> Payments worker. In real production deployments most teams already
> separate workers per workflow type, so the more universal version of
> the problem is "two teams in the same namespace with no contract
> between them." Nexus is the canonical fix for both shapes. We chose
> the visceral version for Chapter 1 because you can literally watch
> Compliance code import into the Payments process; the lessons
> transfer to the more realistic case starting in Chapter 2.

That is fine when one team owns everything. It stops being fine the
moment Compliance becomes its own team:

- Compliance has its own deploy cadence. They cannot ship without
  coordinating a release with Payments.
- Compliance touches data Payments should not see. Putting it in the
  same Worker means the same process holds both PCI scope and customer
  KYC scope.
- A bug in compliance crashes the Payments Worker. There is no
  blast-radius boundary.
- Compliance wants to migrate to Java. Today they cannot, because they
  share a Python codebase with Payments.

By the end of the workshop, Compliance will be its own service in its
own namespace, exposed to Payments through a single typed contract that
both teams agree on. Payments will not import any Compliance code, and
the Compliance team will be free to deploy, scale, and rewrite their
half independently. The bridge between the two will be a Temporal
**Nexus Endpoint**.

But first, the monolith.

## What you will do

- Start the Payments Worker as it exists today (compliance and all).
- Run three transactions through it: a low-risk approval, a medium-risk
  edge case, and a high-risk decline.
- Inspect the Web UI and notice that the compliance check appears as an
  ordinary `ActivityTaskScheduled` event in the Payments workflow's
  history. There is no boundary to be seen.

## Step 1: Start the Payments Worker

Click the [button label="Worker" background="#444CE7"](tab-1) terminal.
Start the Worker:

```bash,run
uv run python -m payments.worker
```

You should see a startup banner that looks like this:

```bash,nocopy
  Payments Worker started on: payments-processing
  Namespace: default
  Registered: PaymentProcessingWorkflow
              validate_payment, execute_payment
              check_compliance (monolith - will decouple)
```

Two things to notice in that banner:

1. The Worker is in the `default` namespace and polls the
   `payments-processing` task queue. There is no separation between
   Payments and Compliance yet; everything lives in one place.
2. The `Registered:` block lists `check_compliance` alongside
   `validate_payment` and `execute_payment`, with the parenthetical
   `(monolith - will decouple)`. Compliance code is loaded directly
   into the Payments Worker process today, and the worker itself
   knows it is going to lose that activity in a later chapter.

Leave the Worker running. The next step uses a different terminal.

## Step 2: Run three transactions

Click the [button label="Starter" background="#444CE7"](tab-2)
terminal. Run the starter:

```bash,run
uv run python -m payments.starter
```

The starter runs three transactions back to back:

- **TXN-A**: a $250 routine supplier payment (US to US). Should
  approve as LOW risk.
- **TXN-B**: a $12,000 international consulting fee (US to UK). The
  rule-based compliance check classifies it as MEDIUM risk because it
  crosses the $10,000 international threshold, and auto-approves it
  with an AML monitoring note.
- **TXN-C**: a $75,000 large capital transfer (US to US). Trips the
  over-$50,000 threshold rule and declines.

For each transaction the starter prints a multi-line block with
`Result:`, `Risk:`, `Reason:`, and (for approvals) `Conf#:`. The three
blocks should look something like this:

```bash,nocopy
  Result: COMPLETED
  Risk:   LOW
  Reason: Routine domestic/standard international transfer. No regulatory concerns.
  Conf#:  ...

  Result: COMPLETED
  Risk:   MEDIUM
  Reason: International transfer above $10K threshold. Approved with AML monitoring note.
  Conf#:  ...

  Result: DECLINED_COMPLIANCE
  Risk:   HIGH
  Reason: Transaction amount exceeds $50,000 threshold. Requires enhanced due diligence review.
```

> Note: TXN-B completing instead of waiting for human review is a
> property of the rule-based checker we ship with: any MEDIUM-risk
> transaction is auto-approved with a monitoring note. Chapter 6
> introduces a real human-review path for MEDIUM transactions.
>
> Note: `Result: DECLINED_COMPLIANCE` is a *return value* from the
> Workflow, not a Workflow execution failure. The Temporal UI will
> still show `payment-TXN-C` as `Completed`, because the Workflow
> function returned cleanly. This distinction matters again in
> Chapter 7 when we look at real failures.

## Step 3: Inspect the Web UI

Click the [button label="Temporal UI" background="#444CE7"](tab-3) tab.
Make sure the namespace selector at the top is set to `default`.

You should see three workflow executions in the **Workflows** view:

- `payment-TXN-A` (Completed)
- `payment-TXN-B` (Completed)
- `payment-TXN-C` (Completed)

Click into `payment-TXN-A` and look at the Event History. Find the
event named `ActivityTaskScheduled` for the `check_compliance`
activity. **This is the seam we are about to break.**

A few things worth noticing:

- The compliance check is a regular Activity from the Payments
  workflow's perspective. There is no "Nexus" anywhere in the history.
- The Activity runs in the Payments task queue
  (`payments-processing`), polled by the Payments Worker.
- The Compliance team has no visibility into this run. There is no
  separate workflow execution they can audit. There is no separate
  namespace they can apply their own retention or access control to.

This is what "tightly coupled" looks like in Temporal. The teams are
welded together at the Activity level. To pull them apart, we will
replace the Activity call with a **Nexus Operation** call: a typed
remote-invocation primitive that runs in a different namespace, with a
different worker, owned by a different team.

## Step 4: Stop the Worker

Back in the [button label="Worker" background="#444CE7"](tab-1)
terminal, stop the Worker with `Ctrl+C` so it does not pollute the next
chapter's task queue.

```bash,run
# Press Ctrl+C in the Worker terminal.
```

You can also stop it from the Starter terminal with:

```bash,run
pkill -f "payments.worker" || true
```

## Wrapping up

In this chapter you ran the application as it exists before any Nexus
work. Three transactions executed end-to-end through a single Worker
that owned both Payments and Compliance code. The compliance check
appeared as an ordinary Activity in the Payments workflow's history,
with no boundary visible.

The next chapter introduces the **Nexus Service contract**: the typed
Python interface that the Payments and Compliance teams will share, and
the Nexus Endpoint that will route calls between them. The contract
itself is small, and Chapter 2 is largely about what it means and where
it lives. The actual decoupling happens across Chapters 3 and 4.

> Knowledge check (instructor-led in Live Event mode, self-check in
> self-paced mode):
>
> - The four Nexus building blocks are **Service**, **Operation**,
>   **Endpoint**, and **Registry**. Try to predict which of those you
>   will define in code, which on the server, and which by importing
>   shared types.
> - The synchronous Nexus handler deadline is **10 seconds**. Anything
>   that needs more time runs as an asynchronous, workflow-backed
>   operation (Chapter 5).
> - The asynchronous Schedule-to-Close ceiling on Temporal Cloud is
>   **60 days**. Plenty of room for a human-in-the-loop review
>   (Chapter 6).
