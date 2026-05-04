---
slug: what-next
id: fy7zye3lnbyw
type: quiz
title: What Next - Resources and Going Deeper
teaser: Reference page for continuing your Nexus journey - documentation, tutorials,
  sample code, and community.
answers:
- "A typed Service contract plus a Nexus Endpoint"
- "A shared task queue"
- "A shared workflow definition"
- "A shared Worker process"
solution:
- 0
difficulty: basic
timelimit: 1800
enhanced_loading: false
---

<!--
CLAUDE_HELP: Release blocker before this workshop runs.
The repo `https://github.com/temporalio/workshop-nexus-intro-code` referenced
below is currently empty (only `.gitignore` and `LICENSE`). Push the exercise
scaffolds, finished solutions for every chapter, and the polyglot Java
implementation before this chapter ships, otherwise the description below is
a broken promise. This comment is HTML-only and never renders to attendees.
-->

# Where to go from here

You just built a Nexus-decoupled application end to end. This page is
the reference you can come back to when you start applying Nexus to
real systems.

## Official documentation

- **Nexus on docs.temporal.io**: the canonical reference for Nexus
  concepts, lifecycle, and configuration:
  [`https://docs.temporal.io/nexus`](https://docs.temporal.io/nexus).
- **Temporal docs home**: everything else (Workers, Workflows,
  Activities, namespaces, observability, Temporal Cloud):
  [`https://docs.temporal.io`](https://docs.temporal.io).
- **Workflow Updates** (the primitive Chapter 6 used through Nexus):
  [`https://docs.temporal.io/develop/python/message-passing#updates`](https://docs.temporal.io/develop/python/message-passing#updates).

## Hands-on tutorials and courses

- **learn.temporal.io** is Temporal's tutorials and courses hub:
  [`https://learn.temporal.io`](https://learn.temporal.io). The Nexus
  tutorial track lives at
  [`https://learn.temporal.io/tutorials/nexus/`](https://learn.temporal.io/tutorials/nexus/);
  as of April 2026, the published entry is the Java sync tutorial.
  Adjacent courses on durable execution, error handling, and Worker
  Versioning round out the rest of the platform fundamentals (they are
  not Nexus-specific).
- **Python Nexus quickstart** is the canonical entry point for Python
  Nexus development on the docs site:
  [`https://docs.temporal.io/develop/python/nexus/quickstart`](https://docs.temporal.io/develop/python/nexus/quickstart).

## Sample code by language

The `samples-*` repositories are where the SDK team ships runnable
patterns. The Nexus directories cover patterns this workshop did not
have time to touch (fan-out with `WAIT_REQUESTED` cancellation,
operations that take multiple typed arguments, additional sync
operation shapes, and more).

- **Python**:
  [`https://github.com/temporalio/samples-python`](https://github.com/temporalio/samples-python)
  (look under `hello_nexus/` for the canonical sample, and
  `nexus_cancel/`, `nexus_multiple_args/`, and `nexus_sync_operations/`
  for additional patterns).
- **Java**:
  [`https://github.com/temporalio/samples-java`](https://github.com/temporalio/samples-java)
  (look under `core/src/main/java/io/temporal/samples/nexus/`, with
  sibling `nexuscancellation/` and `nexuscontextpropagation/` directories
  for additional patterns).
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

- **Fan-out with first-result cancellation**: a caller workflow that
  starts several Nexus operations concurrently, takes the first
  result, and cancels the rest. See `samples-python/nexus_cancel/`,
  which also demonstrates `WAIT_REQUESTED` cancellation semantics
  (the caller proceeds once the handler has received the cancel
  request without waiting for cleanup to finish).
- **Multi-region and Temporal Cloud**: Nexus crosses namespaces. Crossing
  namespaces within an account and crossing regions both have
  additional considerations on Temporal Cloud:
  [`https://docs.temporal.io/cloud/nexus`](https://docs.temporal.io/cloud/nexus).
- **Versioning and rollouts**: when the Service contract changes,
  both teams need a coordinated rollout. Breaking contract changes are
  a multi-team API rollout problem (additive operations, migration
  windows, dual-writing the new shape). Worker Versioning helps on
  the workflow-code side once the new contract is in place:
  [`https://docs.temporal.io/worker-versioning`](https://docs.temporal.io/worker-versioning).

## Community

- **Community forum**: long-form questions, design feedback, and
  searchable history:
  [`https://community.temporal.io`](https://community.temporal.io).
- **Slack**: real-time chat with the Temporal team and other users:
  [`https://temporal.io/slack`](https://temporal.io/slack).

## One last reflection

Before you wrap up, lock in the central idea of this workshop.

**What does Nexus let two teams share so that they can call each
other's Temporal code without sharing a namespace or a codebase?**
