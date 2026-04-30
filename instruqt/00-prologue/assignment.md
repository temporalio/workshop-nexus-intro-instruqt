---
slug: prologue
type: challenge
title: 'Prologue: Topology Sandbox'
teaser: A two-minute visual preview of the resilient end-state you are about to
  build. Click Stop on a service and watch in-flight work pause, not fail.
notes:
- type: text
  contents: |-
    # Before You Begin

    The next three and a half hours are hands-on. Before you start
    writing code, take two minutes to look at the system you are
    about to build.

    The **Topology Sandbox** in this chapter is a visualizer, not a
    real Temporal cluster. Three boxes (Payments Worker, Nexus
    Endpoint, Compliance Worker), wires between them, and synthetic
    payments flowing through. Each service has a Stop button.

    Click Stop on any service and watch what happens to the in-flight
    payments. Then click Start. You should see work pause, not fail.

    Treat this as a brochure, not a lab. You have not built any of
    this yet, so do not worry about the vocabulary on the boxes. The
    point is to see the shape of the resilient end-state before we go
    pull apart a monolith.
tabs:
- title: Topology Sandbox
  type: service
  hostname: workshop
  port: 8765
difficulty: basic
timelimit: 600
enhanced_loading: false
---

A two-minute visual preview of the system you are about to build,
running entirely in your browser. Nothing to install, nothing to run,
no real Temporal cluster behind it. Just the shape of the end-state.

> [!NOTE]
> Everything in this sandbox depicts the architecture you will be
> working toward over the next several chapters. The labels
> (`Nexus Endpoint`, `compliance-endpoint`, `NexusOperationScheduled`)
> will be defined later. Do not memorize them now. Watch what
> happens when you click a Stop button.

## What's on screen

- **Topology** (top): three services, with a Stop / Start button on
  each.
- **Score**: cumulative counters for completed, declined, in-flight,
  blocked, and lost transactions.
- **Workflows In Flight**: each row is one synthetic payment moving
  through three steps (validate, compliance check, execute).
- **Event History** (right): the same event names the real Temporal
  Web UI uses.

## Step 1: Stop the Compliance Worker

Find the **Compliance Worker** box on the right side of the topology.
Click its **Stop** button.

Watch the workflows in flight:

- Any payment that has reached the compliance step turns **yellow**
  ("blocked"). It does not turn red. It does not fail.
- New payments still get scheduled. They progress through the first
  step and pile up at the compliance step.
- The `Lost` counter does not move.

Now click **Start** on the Compliance Worker. The blocked payments
turn back to blue and continue. They resume from where they were,
not from the beginning.

## Step 2: Stop the Nexus Endpoint

Click **Stop** on the **Nexus Endpoint** box (the middle one).

Same shape: in-flight payments at the compliance step turn yellow.
The `Lost` counter does not move. New payments queue up. Click
**Start** and they flow again.

## Step 3: Notice What Did Not Happen

In a minute of stopping and starting random services, you should see:

- The `Lost` counter is still **0**.
- No payment crashed. None disappeared. None silently retried until
  it gave up.
- Every workflow either completed, declined cleanly (a business
  outcome, not a failure), or paused and resumed when its dependency
  came back.

That is the durability story. Stop a service, the work waits. Start
it back up, the work resumes. Nothing is lost.

## Key Takeaways

- The system you are about to build keeps in-flight work **paused,
  not failed**, when a downstream service is unavailable.
- The boundary between teams (the `Nexus Endpoint`) is a first-class
  part of the topology, not a hidden function call.
- The `Lost` counter does not move. That property is the load-bearing
  reason this architecture is worth the work.
