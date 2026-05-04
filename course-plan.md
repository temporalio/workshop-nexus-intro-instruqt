# Course Plan: Introduction to Temporal Nexus (Replay Workshop)

## Metadata

- **Description:** A 3.5-hour hands-on workshop introducing Temporal Nexus through a payment-processing scenario. Attendees decouple a monolith into two namespace-isolated services connected by a Nexus Endpoint, then layer in asynchronous Operations, human-in-the-loop Updates, lifecycle controls (cancellation, errors, circuit breaker), and a polyglot connector demo. Designed for live delivery at Replay and self-paced follow-up. Builds on the [Java sync Nexus tutorial](https://learn.temporal.io/tutorials/nexus/nexus-sync-tutorial-java/) on learn.temporal.io and ports its code to Python (see the companion `workshop-nexus-intro-code` repository).
- **Author:** Mason Egger
- **Target learner:** Software engineers comfortable with the core Temporal model (Workflows, Activities, Workers, Signals, Queries, Updates) but new to Temporal Nexus. Comfortable writing Python.
- **Dreyfus stage:** Advanced Beginner for Temporal; Novice for Nexus specifically.
- **Estimated instruction time:** 210 minutes (3.5 hours), 9:00 AM to 12:30 PM.
- **Lab platform:** Instruqt. Live Event mode for Replay; Self-paced mode for the public version.
- **Slides:** Slidev with the `theme-temporal` theme.
- **Last updated:** 2026-04-26

## Program Outcomes This Course Supports

- Develop production-ready Temporal applications that span team and namespace boundaries.
- Recognize when and how to apply Temporal's cross-team coordination features.
- Adapt to Temporal's evolving capabilities as new features reach general availability.

## External Standards

None.

## Competencies

### 1. Distinguish when to use Nexus versus other Temporal integration patterns

*Bloom level: Analyze. The audience knows Temporal well enough to compare Nexus to Activities and Child Workflows on day one. Analyze is honest given prior context, while Apply would understate what the workshop's primary goal asks of them.*

#### Learning Objectives

- Describe the cross-namespace integration problem Nexus solves *(Understand)*
- List the four Nexus building blocks (Service, Operation, Endpoint, Registry) and the role of each *(Remember)*
- Compare Nexus to Activities-wrapping-HTTP, shared Activities, and Child Workflows *(Analyze)*
- Identify scenarios where namespace isolation, blast radius, or team boundaries make Nexus appropriate *(Understand)*
- Explain Nexus's key constraints: the 10-second sync handler deadline and the 60-day async ceiling *(Understand)*

#### Performance Assessment

**Condition:**

At the end of Chapter 1, the learner completes a 3-minute scenario-based quiz delivered via Instruqt's native `quiz` resource, followed by a brief instructor-led discussion debrief in Live Event mode.

**Criteria, performance will be successful when:**

- Given 3 short scenarios (cross-namespace, intra-namespace, custom HTTP today), the learner correctly selects the appropriate integration pattern (Activity, Child Workflow, Nexus, Shared Activity) for each.
- For at least one scenario, the learner justifies their choice by referencing namespace isolation, blast radius, or team boundaries.
- The learner correctly names the four Nexus building blocks (Service, Operation, Endpoint, Registry) and states the role of each.
- The learner correctly states the 10-second sync handler deadline and the 60-day async Schedule-to-Close ceiling.

#### Learning Activities

| #   | Activity                                                                | Type     | Covers objectives | Time (min) |
| :-- | :---------------------------------------------------------------------- | :------- | :---------------- | ---------: |
| 1.1 | The cross-team integration problem and shared blast radius              | Lecture  | 1.1               |          5 |
| 1.2 | Run the monolith and feel the problem                                   | Exercise | 1.4               |          7 |
| 1.3 | The four Nexus building blocks: Service, Operation, Endpoint, Registry  | Lecture  | 1.2               |          5 |
| 1.4 | **Quiz:** Pick the integration pattern (Comp 1 assessment)              | Quiz     | 1.2, 1.3, 1.4, 1.5 |        3 |

---

### 2. Decouple a Temporal application across Namespaces using a Nexus Service

*Bloom level: Apply. The doing competency for the synchronous half of the workshop. By the end of Chapter 4, the learner has split a monolith into two Workers running in separate namespaces, connected by a Nexus Endpoint and a synchronous Nexus Service.*

#### Learning Objectives

- Write a Nexus Service contract using `@nexusrpc.service` and Operation type signatures *(Apply)*
- Implement a synchronous Nexus Operation handler with `@nexusrpc.handler.sync_operation` *(Apply)*
- Register a Nexus Service implementation with a Worker via the `nexus_service_handlers` argument *(Apply)*
- Register a Nexus Endpoint with the Temporal CLI *(Apply)*
- Invoke a Nexus Operation from a caller Workflow using `workflow.create_nexus_client` *(Apply)*
- Interpret the two-event sync Nexus pattern (`NexusOperationScheduled`, `NexusOperationCompleted`) in a caller's Event History *(Apply)*

#### Performance Assessment

**Condition:**

The learner completes the decoupling exercises across Chapters 2 through 4. The monolithic exercise is transformed into two Workers running in `payments-namespace` and `compliance-namespace`, connected by the `compliance-endpoint` Nexus Endpoint. End-to-end behavior is verified on Instruqt.

**Criteria, performance will be successful when:**

- A `ComplianceNexusService` contract is defined in `shared/service.py` with `@nexusrpc.service` and exposes `check_compliance` and `submit_review` Operations with typed inputs and outputs.
- A `check_compliance` sync handler is implemented in `compliance/service_handler.py` with `@nexusrpc.handler.sync_operation` and returns within the 10-second deadline by delegating to the rule-based check.
- The Compliance Worker (`compliance/worker.py`) registers the Nexus Service via the Worker's `nexus_service_handlers` argument.
- A Nexus Endpoint `compliance-endpoint` is registered via `temporal operator nexus endpoint create` and routes to `compliance-namespace` and the `compliance-risk` task queue.
- `PaymentProcessingWorkflow` invokes `check_compliance` via `workflow.create_nexus_client(...).execute_operation(...)` instead of a direct activity call.
- `check_compliance` is removed from the Payments Worker's activities list.
- TXN-A (LOW), TXN-B (MEDIUM auto-approved with the AML monitoring note), and TXN-C (HIGH declined) all complete with their expected outcomes through the sync Nexus path.
- The caller's Event History shows `NexusOperationScheduled` and `NexusOperationCompleted` for each Nexus call. There is no compliance activity event on the caller side, and no workflow appears in `compliance-namespace`.

#### Learning Activities

| #   | Activity                                                                                                       | Type     | Covers objectives  | Time (min) |
| :-- | :------------------------------------------------------------------------------------------------------------- | :------- | :----------------- | ---------: |
| 2.1 | Service contracts as shared language between teams                                                             | Lecture  | 2.1                |          4 |
| 2.2 | `@nexusrpc.service` and Operation type signatures                                                              | Lecture  | 2.1                |          4 |
| 2.3 | Define the `ComplianceNexusService` contract (TODO 1)                                                          | Exercise | 2.1                |         12 |
| 3.1 | Synchronous Nexus handlers and the 10s deadline                                                                | Lecture  | 2.2                |          6 |
| 3.2 | Worker registration and Endpoint creation with the CLI                                                         | Lecture  | 2.3, 2.4           |          6 |
| 3.3 | Implement sync handlers, register the Worker, create the Endpoint (TODOs 2, 3)                                 | Exercise | 2.2, 2.3, 2.4      |         18 |
| 4.1 | Caller-side stub: `create_nexus_client` and `execute_operation`                                                | Lecture  | 2.5                |          4 |
| 4.2 | The two-event sync pattern in the caller's Event History                                                       | Lecture  | 2.6                |          4 |
| 4.3 | Swap activity call to Nexus call, drop compliance from caller worker, witness Event History (TODOs 4, 5)       | Exercise | 2.5, 2.6           |         17 |

---

### 3. Implement asynchronous Nexus Operations backed by handler Workflows

*Bloom level: Apply. Async Operations have their own concept set (operation token, the `Started` event, the 60-day ceiling, multi-phase timeouts), and they gate Competencies 4 and 5 since only async Operations support cross-boundary Updates and cancellation.*

#### Learning Objectives

- Implement an asynchronous Nexus Operation handler using `@nexus.workflow_run_operation` *(Apply)*
- Read Event History to confirm the async Operation lifecycle: `Scheduled`, `Started`, `Completed` *(Apply)*
- Use the operation token to identify a long-running async Operation in `Pending Nexus Operations` *(Apply)*
- Configure Schedule-to-Close, Schedule-to-Start, and Start-to-Close timeouts on a Nexus Operation *(Apply)*
- Use `WorkflowIDConflictPolicy.USE_EXISTING` to make a workflow-backed handler idempotent on retry *(Apply)*

#### Performance Assessment

**Condition:**

The learner completes Chapter 5 by converting `check_compliance` to a workflow-backed async Operation, registering `ComplianceWorkflow` and the `check_compliance` activity on the Compliance Worker, and configuring the full set of timeouts on the caller. The async lifecycle is observed in the Temporal Web UI.

**Criteria, performance will be successful when:**

- `ComplianceWorkflow.run` (in `compliance/workflows.py`) is implemented to run the rule-based `check_compliance` activity and return its result.
- The `check_compliance` Nexus handler is implemented as `@nexus.workflow_run_operation` and returns a `WorkflowHandle` from `ctx.start_workflow(...)` with `id_conflict_policy=WorkflowIDConflictPolicy.USE_EXISTING`.
- The Compliance Worker registers `ComplianceWorkflow` as a workflow and `check_compliance` as an activity, alongside the Nexus service handler.
- For any normal transaction, the caller's Event History shows three Nexus events (`NexusOperationScheduled`, `NexusOperationStarted`, `NexusOperationCompleted`), confirming async lifecycle versus the two-event sync flow.
- `compliance-namespace` shows a `compliance-TXN-*` workflow per transaction.
- The caller's Nexus Operation has `schedule_to_close_timeout`, `schedule_to_start_timeout`, and `start_to_close_timeout` all configured.

#### Learning Activities

| #   | Activity                                                                                       | Type     | Covers objectives          | Time (min) |
| :-- | :--------------------------------------------------------------------------------------------- | :------- | :------------------------- | ---------: |
| 5.1 | `@nexus.workflow_run_operation` and the three-event async lifecycle                            | Lecture  | 3.1, 3.2                   |          3 |
| 5.2 | Operation tokens and `Pending Nexus Operations`                                                | Lecture  | 3.3                        |          2 |
| 5.3 | The three timeouts and idempotency on retry                                                    | Lecture  | 3.4, 3.5                   |          2 |
| 5.4 | Build `ComplianceWorkflow`, convert handler, register worker, set timeouts (TODOs 6, 7, 8, 9)  | Exercise | 3.1, 3.2, 3.3, 3.4, 3.5    |         13 |

---

### 4. Propagate Workflow Updates through Nexus to support human-in-the-loop patterns

*Bloom level: Apply. Standalone competency because the Update path has its own primitives (the `@workflow.update` handler, the validator, the sync-handler-as-Update-sender pattern, the caller workflow that triggers the Update). Builds directly on Competency 3, since the Update target is the running handler workflow from Chapter 5.*

#### Learning Objectives

- Implement a `@workflow.update` handler with a `@review.validator` that enforces idempotency *(Apply)*
- Implement a synchronous Nexus Operation handler that resolves a running workflow and sends it a Workflow Update *(Apply)*
- Build a short-lived caller workflow that submits an Update through a Nexus Operation *(Apply)*
- Identify `WorkflowExecutionUpdateAccepted` and `WorkflowExecutionUpdateCompleted` events on the handler workflow's Event History *(Apply)*

#### Performance Assessment

**Condition:**

The learner completes Chapter 6 by adding a human-review path to `ComplianceWorkflow`, implementing `submit_review` as a real Update sender, and adding `ReviewCallerWorkflow` on the Payments side. The pre-supplied `review_starter.py` triggers the review flow. The Update path is verified end-to-end: TXN-B blocks until the reviewer submits a decision.

**Criteria, performance will be successful when:**

- `ComplianceWorkflow` has a `@workflow.update review` handler that records the reviewer's decision, and a `@review.validator validate_review` that rejects review attempts before the workflow is awaiting review and after a decision was already made.
- `ComplianceWorkflow.run` branches on risk level: LOW and HIGH return immediately; MEDIUM sleeps and waits on a `wait_condition` that the review Update resolves.
- The `submit_review` Nexus handler in `compliance/service_handler.py` is implemented with `nexus.client().get_workflow_handle_for(...).execute_update(...)`, replacing the `NotImplementedError` stub.
- `ReviewCallerWorkflow` exists in `payments/workflows.py` and is registered on the Payments Worker.
- TXN-B (MEDIUM) blocks during `payments.starter` until `payments.review_starter` (pre-supplied) is invoked, after which TXN-B completes and TXN-C runs and is declined.
- The compliance-side `compliance-TXN-B` workflow's Event History shows `WorkflowExecutionUpdateAccepted` and `WorkflowExecutionUpdateCompleted` events for the `review` Update.

#### Learning Activities

| #   | Activity                                                                                          | Type     | Covers objectives  | Time (min) |
| :-- | :------------------------------------------------------------------------------------------------ | :------- | :----------------- | ---------: |
| 6.1 | `@workflow.update`, the validator pattern, and `wait_condition` durability                        | Lecture  | 4.1, 4.4           |          4 |
| 6.2 | Sending an Update from a sync Nexus handler via the Temporal Client                               | Lecture  | 4.2                |          3 |
| 6.3 | Caller workflows that route human input through Nexus                                             | Lecture  | 4.3                |          1 |
| 6.4 | Add review path, real `submit_review`, `ReviewCallerWorkflow`; run pre-supplied review starter (TODOs 10, 11, 12) | Exercise | 4.1, 4.2, 4.3, 4.4 | 17 |

`payments/review_starter.py` is supplied complete in the exercise directory. The chapter focuses tightly on the new concepts (validator, Update sender, caller workflow); the starter is mechanical glue and reads better as a finished example than as a fourth TODO.

---

### 5. Configure Nexus Operations for cancellation, error handling, and reliability

*Bloom level: Apply. The "production readiness" competency. The learner selects the right primitive for a stated scenario and observes the result.*

#### Learning Objectives

- Cancel an async Nexus Operation from a caller Workflow and observe cancellation propagating to the handler workflow *(Apply)*
- Select the appropriate cancellation type (`ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, `WAIT_COMPLETED`) for a given scenario *(Understand)*
- Raise a non-retryable `OperationError` from a handler to fail an Operation permanently *(Apply)*
- Raise a retryable `HandlerError` and observe automatic retry behavior in the UI *(Apply)*
- Identify circuit-breaker `Blocked` state in `Pending Nexus Operations` via the Temporal UI or `temporal workflow describe` *(Understand)*

#### Performance Assessment

**Condition:**

The learner completes Chapter 7 by injecting failure branches into the compliance handler (TODO 13) and running the lifecycle starter, which exercises each scenario in turn. Behavior is observed in the UI and via `temporal workflow describe`.

**Criteria, performance will be successful when:**

- A caller Workflow successfully requests cancellation of an in-flight async `check_compliance` Operation, the cancellation propagates through the Nexus boundary, and both the caller and `compliance-TXN-CANCEL-1` end in `Canceled` state.
- For a stated scenario (for example, "the caller is being terminated; you don't want to wait for the handler to acknowledge cancel"), the learner correctly selects between `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, and `WAIT_COMPLETED` and explains the trade-off.
- A handler raises `nexusrpc.OperationError`; the caller Workflow records `NexusOperationFailed` immediately without retry and ends in `Failed` state.
- A handler raises a retryable `HandlerError`; the caller's `Pending Nexus Operations` show increasing attempt count and `BackingOff` state.
- After 5 or more consecutive retryable errors on the same caller-Namespace/Endpoint pair, the circuit-breaker open state is observed in `temporal workflow describe` output as `State: Blocked` with `BlockedReason: The circuit breaker is open.`

#### Learning Activities

| #   | Activity                                                                                                  | Type     | Covers objectives           | Time (min) |
| :-- | :-------------------------------------------------------------------------------------------------------- | :------- | :-------------------------- | ---------: |
| 7.1 | Cancellation propagation across the Nexus boundary; the four cancellation types                          | Lecture  | 5.1, 5.2                    |          4 |
| 7.2 | Retryable vs non-retryable errors: `OperationError` and `HandlerError`                                    | Lecture  | 5.3, 5.4                    |          3 |
| 7.3 | The circuit breaker (5 errors, then open 60s, then half-open)                                             | Lecture  | 5.5                         |          1 |
| 7.4 | Inject failures (TODO 13), run the lifecycle starter, observe each scenario in the UI and CLI            | Exercise | 5.1, 5.2, 5.3, 5.4, 5.5     |         12 |

---

### Reinforcement: Polyglot Connector Demo

The polyglot demo is not its own competency. It reinforces Competency 2's "Service contract is the shared language" thesis. It is a 5-minute presenter-driven moment between Chapter 7 and the wrap-up, run against the Chapter 7 solution state.

| #   | Activity                                                                            | Type | Covers objectives | Time (min) |
| :-- | :---------------------------------------------------------------------------------- | :--- | :---------------- | ---------: |
| 8.1 | Same Nexus Service, Java handler. Python caller hits a Java legacy worker.          | Demo | 2.1 (reinforced)  |          5 |

The Java legacy worker is pre-built and pre-running on the `java-legacy` container. The Python and Java compliance workers cannot share the `compliance-risk` task queue safely (workflow histories produced by different SDKs are not interchangeable), so the demo flow is:

1. Stop the Python compliance worker.
2. Start the Java compliance worker on the same `compliance-risk` task queue.
3. From the Chapter 7 solution directory, run `python -m payments.starter`.
4. TXN-A returns LOW and completes immediately. The Web UI shows a Java-authored `compliance-TXN-A` workflow in `compliance-namespace`.

The Java handler is the equivalent of the Chapter 6 solution (workflow-backed `check_compliance` plus the review path), so MEDIUM risk transactions still pause for review and HIGH risk transactions still decline. The lifecycle scenarios from Chapter 7 (TXN-FAIL-*, TXN-CIRCUIT-*) are out of scope for the polyglot demo because the Java handler does not implement the Python failure-injection branches; the demo deliberately uses normal transactions to keep the message tight.

Same Service contract, different language, no code change in Python.

## Learning Plan (Module Sequence)

```
Welcome -> Ch 1 -> Ch 2 -> Ch 3 -> Ch 4 -> BREAK -> Ch 5 -> Ch 6 -> Ch 7 -> Polyglot -> Wrap
```

| Time          | Block                                                                         | Lect | Ex |
| :------------ | :---------------------------------------------------------------------------- | ---: | -: |
| 9:00 - 9:05   | Welcome and Instruqt smoke test                                               |    5 |    |
| 9:05 - 9:25   | **Ch 1**: Why Nexus and run the monolith                                      |   10 | 10 |
| 9:25 - 9:45   | **Ch 2**: The Nexus Service contract                                          |    8 | 12 |
| 9:45 - 10:00  | **Break**                                                                     |      |    |
| 10:00 - 10:30 | **Ch 3**: Sync handlers, Worker wiring, Endpoint                              |   12 | 18 |
| 10:30 - 10:55 | **Ch 4**: Calling Nexus from a caller Workflow                                |    8 | 17 |
| 10:55 - 11:15 | **Ch 5**: Async Operations (workflow-backed handler)                          |    7 | 13 |
| 11:15 - 11:30 | **Halftime + Break**                                                          |      |    |
| 11:30 - 11:55 | **Ch 6**: Updates Through Nexus (human-in-the-loop)                           |    8 | 17 |
| 11:55 - 12:15 | **Ch 7**: Lifecycle control: cancellation, errors, circuit breaker            |    8 | 12 |
| 12:15 - 12:20 | **Polyglot connector**: same Service, Java handler                            |    5 |    |
| 12:20 - 12:30 | Wrap and Q&A                                                                  |   10 |    |

**Totals:** 81 min lecture, 99 min exercise, 30 min break (15 + 15), 5 min welcome, 5 min polyglot, 10 min wrap, totaling 210 min. Lecture/exercise ratio about 45/55.

The day splits into three blocks. **Block 1 (45 min)**: Welcome + Ch 1 + Ch 2 — set up the problem and define the contract. **Break.** **Block 2 (75 min)**: Ch 3 + Ch 4 + Ch 5 — build the integration end-to-end, from sync handler through the caller swap into async. **Halftime + Break.** **Block 3 (60 min)**: Ch 6 + Ch 7 + Polyglot + Wrap — human-in-the-loop, lifecycle control, polyglot demo, close. The two 15-minute breaks replace the prior single 30-minute break at 11:00.

## Implementation Notes

This section captures decisions a future Claude Code session needs to build the workshop without rethinking the design.

### Lab platform: Instruqt

- **Lab type:** Instruqt Lab using the Lab/chapter/page/task model (the current direction, not the legacy track/challenge model).
- **Live Event mode** for Replay: instructor dashboard, real-time progress, hand-raising, attendee assistance via screen-share or take-control.
- **Self-paced mode** for the public version. Pausable Tracks enabled so attendees can resume.
- **Hot Start enabled.** Provision the pool about 30 minutes before Replay session start. Size the pool slightly above expected headcount with a small fallback pool for resilience.
- **IP limits raised** (or use an invite with a claim limit). Replay attendees may share co-located network infrastructure.
- **Single Live Event invite** for all content, gated by business email confirmation.

### Multi-container layout

Three Linux containers per Lab:

| Container         | Purpose                                                               | Always running?                  |
| :---------------- | :-------------------------------------------------------------------- | :------------------------------- |
| `payments`        | Python Payments Worker (caller side)                                  | Yes                              |
| `compliance`      | Python Compliance Worker (handler side)                               | Yes, except during polyglot demo |
| `java-legacy`     | Pre-built Java Compliance Worker for the polyglot connector demo      | Started for the polyglot demo    |

A single Temporal dev server runs in either an additional container or co-located with one of the workers. Decide during the Instruqt build. The Temporal CLI dev server is lightweight enough to share.

The Python compliance worker and the Java compliance worker poll the same `compliance-risk` task queue, so only one of them may be active at a time. The polyglot demo stops the Python worker, starts the Java worker, and runs a transaction.

### Tab layout

Per the Instruqt `layout` HCL:

- **Editor tab:** multi-workspace editor across the `payments` and `compliance` containers.
- **Terminal tab:** one per container so attendees can see logs concurrently.
- **Service tab:** proxies `localhost:8233` for the Temporal Web UI.
- **Notes tab:** static markdown reference for Nexus event names, CLI cheat sheet, and the building-blocks quick-match table.

### Lifecycle scripts

Every task has the four standard scripts:

- `setup`: pre-create namespaces, seed config, optionally pre-start workers (`uv run python -m payments.worker`, etc.).
- `check`: validation. Must complete in 30 seconds or less (the default Lab task timeout).
- `solve`: auto-fast-forward state if the attendee skips, so downstream tasks still work.
- `cleanup`: reset state for the next task.

#### Validation strategy for `check` scripts

All checks poll for state. They never wait for completion.

- **File contents:** grep for `@nexusrpc.service`, `@nexusrpc.handler.sync_operation`, `@nexus.workflow_run_operation`, `@workflow.update`, etc.
- **CLI state:** `temporal operator nexus endpoint list | grep compliance-endpoint`, `temporal workflow list -n compliance-namespace`, etc.
- **Event History:** `temporal workflow show -w <id>` and grep for specific event names (`NexusOperationScheduled`, `NexusOperationStarted`, `NexusOperationCompleted`, `NexusOperationFailed`, `NexusOperationCanceled`, `WorkflowExecutionUpdateAccepted`, `WorkflowExecutionUpdateCompleted`).
- **Pending Operations:** `temporal workflow describe -w <id>` and grep for `Pending Nexus Operations`, `State: Blocked`, etc.

Failure messages should be specific and actionable. For example: "Couldn't find `@nexusrpc.service` decorator in `shared/service.py`. Did you complete TODO 1?"

### Code source

- The Instruqt copy resource pulls the `workshop-nexus-intro-code` repo at a stable tag (not `main`). Each chapter has `exercise/` (the starting point, with TODOs to fill) and `solution/` (reference state).
- The `solution/` of one chapter is a close starting point for the next chapter's `exercise/`, but Chapters 5, 6, and 7 also introduce skeleton files (e.g. `compliance/workflows.py` in Ch 5 starts with a `NotImplementedError` body that TODO 6 fills in).
- The Java code under `polyglot/java-legacy/` is pre-compiled and deployed to the `java-legacy` container. It uses explicit Jackson `@JsonProperty` annotations to align its wire format with Python's snake_case dataclasses, so the same Nexus Service contract works against both languages.

### Quiz

The Comp 1 assessment uses Instruqt's native `quiz` resource. Question types:

- **Multiple choice (single answer):** "Given this scenario, pick the integration pattern" (3 scenarios).
- **Multiple choice (multi-select):** "Which of these are Nexus building blocks?"
- **Numeric:** "What is the maximum duration of a synchronous Nexus handler in seconds?" (Answer: 10)
- **Numeric:** "What is the maximum Schedule-to-Close timeout for an async Nexus Operation, in days, on Temporal Cloud?" (Answer: 60)

Configure per-question hints and explanations.

### Local-first fallback

Every exercise must also run locally without Instruqt:

- `uv sync` from the repo root (a single `.venv/` is shared across all chapter snapshots).
- `temporal server start-dev` for the dev cluster.
- `temporal operator namespace create payments-namespace` and `... compliance-namespace` (Chapter 2 onward).
- `temporal operator nexus endpoint create --name compliance-endpoint --target-namespace compliance-namespace --target-task-queue compliance-risk --description-file compliance-endpoint.md` (Chapter 2 onward).

The instructor-facing setup script (Instruqt-side) and the local-fallback README converge on the same end-state so exercise content reads identically in both environments.

### Slides

- **Tool:** Slidev, via the `slidev:slidev` skill.
- **Theme:** `theme-temporal` (Temporal-branded Slidev theme).
- **One deck per chapter.** About 26 lecture activities total across Chapters 1 through 7, producing roughly 26 to 32 content slides plus per-chapter title and recap slides.
- **Activity boundaries are slide boundaries.** Each lecture activity in this plan corresponds to a small cluster of slides, not a long monologue. Per the andragogy principle, every chapter's first slide frames the problem the upcoming exercise will solve before introducing concepts.

### Instructor playbook (live delivery)

- **Pre-event:** start Hot Start pool 30 min before; verify Java legacy container is healthy in a sample sandbox; confirm Live Event invite link works from a non-instructor account.
- **During:** monitor the Live Event dashboard (about 5s refresh); use direct chat for individual help, broadcast chat for class-wide notes; expect to take control of one or two attendee sandboxes during the Chapter 6 exercise (highest-friction segment because the Update path involves the validator, the Update sender, the caller workflow, and the starter all in one chapter).
- **Post-event:** export activity report; revoke or restrict invite; reset IP concurrency limits; spin down Hot Start pool.

## Alignment Check

- [x] Every competency has at least one learning objective.
- [x] Every learning objective is covered by at least one learning activity.
- [x] Every performance criterion has a learning activity that prepares the learner for it.
- [x] Every competency uses a verb at Bloom's Apply level or higher.
- [x] No competency uses "understand," "know," or other below-Apply verbs.

| Competency | Objectives | Activities | Bloom level |
| :--------- | ---------: | ---------: | :---------- |
| 1          |          5 |          4 | Analyze     |
| 2          |          6 |          9 | Apply       |
| 3          |          5 |          4 | Apply       |
| 4          |          4 |          4 | Apply       |
| 5          |          5 |          4 | Apply       |
| **Total**  |     **25** |     **25** *(plus 1 reinforcement demo)* |             |

## Open Questions

- Confirm Replay session date and slot to lock the schedule in any public-facing materials.
- Confirm the Slidev `theme-temporal` repository location, likely an internal `temporalio` repo, so the future content session has the install path.
- Decide whether the public/self-paced version of the workshop will be posted to learn.temporal.io as a course or to Instruqt's catalog only.
- Decide whether the Comp 1 quiz includes a 5th question on a constraint that disqualifies Nexus (for example, "you need to call from non-workflow code," currently unsupported), to give the quiz five questions for symmetry.
