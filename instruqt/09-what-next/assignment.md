---
slug: what-next
id: fy7zye3lnbyw
type: quiz
title: What Next - Resources and Going Deeper
teaser: Reference page for continuing your Nexus journey - documentation, tutorials,
  sample code, and community.
answers:
- "Yes"
- "No"
solution:
- 0
- 1
difficulty: basic
timelimit: 1800
enhanced_loading: false
---

# Where to go from here

You just built a Nexus-decoupled application end to end. This page is
the reference you can come back to when you start applying Nexus to
real systems.

## Official documentation

- **Nexus on docs.temporal.io** — The canonical reference for Nexus
  concepts, lifecycle, and configuration:
  [`https://docs.temporal.io/nexus`](https://docs.temporal.io/nexus).
- **Temporal docs home** — Everything else (Workers, Workflows,
  Activities, namespaces, observability, Cloud):
  [`https://docs.temporal.io`](https://docs.temporal.io).
- **Workflow Updates** (the primitive Chapter 6 used through Nexus) —
  [`https://docs.temporal.io/develop/python/message-passing`](https://docs.temporal.io/develop/python/message-passing).

## Hands-on tutorials and courses

- **learn.temporal.io** is Temporal's tutorials and courses hub. Look
  for the Nexus tutorial track in Python, and follow-on courses on
  durable execution, error handling, and versioning:
  [`https://learn.temporal.io`](https://learn.temporal.io).

## Sample code by language

The `samples-*` repositories are where the SDK team ships runnable
patterns. The Nexus directories cover patterns this workshop did not
have time to touch (workflow-side cancellation with `asyncio.shield`,
the `asyncio.create_task` + `task.cancel()` pattern, multi-handler
endpoints, and more).

- **Python**:
  [`https://github.com/temporalio/samples-python`](https://github.com/temporalio/samples-python)
  (look under `nexus_*`).
- **Java**:
  [`https://github.com/temporalio/samples-java`](https://github.com/temporalio/samples-java)
  (look under `nexus/`). This is also where the polyglot demo's Java
  side comes from.
- **Go**:
  [`https://github.com/temporalio/samples-go`](https://github.com/temporalio/samples-go).
- **TypeScript**:
  [`https://github.com/temporalio/samples-typescript`](https://github.com/temporalio/samples-typescript).

## What you specifically built today

This workshop's source repo is on GitHub. Clone it to keep iterating,
fork it to extend it, or use it as a reference when you stand up your
own Nexus boundary:

- **Workshop code**:
  [`https://github.com/temporalio/workshop-nexus-intro-code`](https://github.com/temporalio/workshop-nexus-intro-code).

The code repo contains both the exercise scaffolds and the finished
solutions for every chapter, plus the polyglot Java implementation
from Chapter 8.

## Patterns we did not cover that you may want next

- **In-workflow cancellation with `asyncio.create_task`** — the
  pattern for cancelling a long-running Nexus operation from inside a
  workflow without cancelling the whole workflow. See `samples-python`.
- **Worker-side cleanup with `asyncio.shield`** — making handler
  cleanup work even when the caller has cancelled. See `samples-python`.
- **Multi-region and Cloud** — Nexus crosses namespaces. Crossing
  Temporal Cloud accounts and crossing regions both have additional
  considerations:
  [`https://docs.temporal.io/cloud`](https://docs.temporal.io/cloud).
- **Versioning and rollouts** — when the Service contract changes,
  both teams need a coordinated rollout. The Worker Versioning
  features in Temporal are designed for exactly this case:
  [`https://docs.temporal.io/worker-versioning`](https://docs.temporal.io/worker-versioning).

## Community

- **Community forum** — long-form questions, design feedback, and
  searchable history:
  [`https://community.temporal.io`](https://community.temporal.io).
- **Slack** — real-time chat with the Temporal team and other users:
  [`https://temporal.io/slack`](https://temporal.io/slack).

## A small ask

Now that you have seen what Nexus can do end to end, we want to know
whether it is the right tool for the work you are doing.

**Do you plan on using Nexus?**
