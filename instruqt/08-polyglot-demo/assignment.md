---
slug: polyglot-demo
id: tfghat3l7rq0
type: challenge
title: Polyglot Connector Demo
teaser: Start a pre-built Java Compliance Worker on the same task queue the Python
  Worker used, and re-run a normal transaction. Same Service contract, different language,
  no Python code change.
notes:
- type: text
  contents: |-
    # The contract is the language

    Up to now, the Compliance team's Worker has been Python. It does
    not have to be. The Service contract is a wire-level agreement,
    not a language one. As long as the implementation honors the
    same Operation names and the same JSON shapes, anything can fulfill it.

    In this final challenge you swap a Java implementation in for the
    Python one, on the same task queue, and rerun a transaction. The
    Payments side does not change. The Endpoint does not change. From
    the caller's perspective, nothing happened.

    This is the polyglot story Nexus is built for.
tabs:
- id: dpnlvo1xqbnk
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/polyglot/java-legacy
- id: iuohxevuui2i
  title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/polyglot/java-legacy
- id: rhbebiylv3ci
  title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: nlb3ygsastqp
  title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: a5b11omshe6d
  title: Reviewer
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- id: 2pxhtk6xwtjz
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
difficulty: basic
timelimit: 600
enhanced_loading: false
---

This chapter has no TODOs. The Java Compliance Worker has been
pre-built and is sitting at `/root/workshop/polyglot/java-legacy/`.
You will start it on the **same** `compliance-risk` task queue the
Python Worker was using, then re-run a normal transaction and watch
the Java handler fulfill the same Nexus contract.

> [!NOTE]
> This chapter has no separate **Solution** tab because there is no
> exercise to solve. The **Code Editor** opens the finished Java
> implementation directly.

## What You're Solving

The Service contract you wrote in Chapter 2 is a typed Python class.
Decorators on it (`@nexusrpc.service`,
`nexusrpc.Operation[Input, Output]`) tell the runtime two things:

- The names of the Operations on the wire.
- The JSON shape of each Operation's input and output.

A Java implementation that uses the same Operation names AND the same
JSON shapes including field names (Java needs
`@Operation(name = "snake_case_name")` for the operation names, and
`@JsonProperty("snake_case_name")` on every data class field for the
JSON shapes) can serve the same callers. **No Python code change.**

The two annotations are not optional. They are how Java earns the
right to be on the other end of a Python-authored contract:

- Without `@Operation(name = "check_compliance")`, the Java SDK
  defaults to the Java method name (`checkCompliance`) on the wire,
  and Python's call fails server-side with
  `NOT_FOUND: Unrecognized operation`.
- Without `@JsonProperty("transaction_id")` (and friends) on every
  field, getter, and the `@JsonCreator` constructor, Jackson defaults
  to camelCase (`transactionId`) on the wire and deserialization
  fails with `UnrecognizedPropertyException`. The Python dataclass
  serializer never produces those keys.

Jackson itself does not appear in `pom.xml`; `jackson-databind`
arrives transitively via `io.temporal:temporal-common`. You do not
need to declare it.

The Java worker is the Chapter 6 solution equivalent on the Java side
(workflow-backed `check_compliance` plus the review path), with
explicit Jackson and operation-name annotations to match the Python
wire format. Because Workflow histories produced by different SDKs
are not interchangeable, only one of (Python, Java) Compliance Worker
may be active on `compliance-risk` at a time. The Compliance Worker
process slot is empty when this chapter starts (the Python Worker
from earlier chapters has already been cleaned up). You will start a
Java Compliance Worker into that empty slot.

## What you will do

- Confirm the pre-built Java Worker is on disk.
- Start the Java Compliance Worker on `compliance-risk`.
- Start the Payments Worker (unchanged).
- Run a normal transaction (`TXN-A`) with the starter.
- See a Java-authored compliance workflow appear in
  `compliance-namespace`.

## Step 1: Confirm the Java Worker is on disk

Click the [button label="Code Editor" background="#444CE7"](tab-0).
The editor is rooted at `/root/workshop/polyglot/java-legacy/`. You
should see a `pom.xml` and a `src/main/java/` tree containing:

- `compliance/temporal/ComplianceWorkerApp.java` (entry point)
- `shared/nexus/ComplianceNexusService.java` (the Nexus contract
  interface: operation names via `@Operation(name = ...)` and the
  request/result types each operation carries)
- `compliance/temporal/ComplianceNexusServiceImpl.java` (Nexus
  handler implementation, carrying `@ServiceImpl` and `@OperationImpl`
  on the methods that fulfill the interface)
- `compliance/temporal/workflow/ComplianceWorkflowImpl.java` (the
  workflow the Nexus handler launches)
- `compliance/domain/` and `shared/domain/` (data classes carrying
  `@JsonProperty(...)` and `@JsonCreator(mode = PROPERTIES)`
  annotations on their fields and constructors)

The tree also contains the Activity classes
(`compliance/temporal/activity/`), the rule-based checker
(`compliance/ComplianceChecker.java`), and the
`ComplianceWorkflow` interface alongside its implementation. They are
the Java equivalents of the Python helpers from earlier chapters and
are not where the polyglot interest lives, so the chapter calls out
only the Nexus-relevant files above.

The Java Worker has already been compiled when the workshop image was
built. There is a `target/` directory with the compiled class files
and a project jar; the dependency jars are cached in the Maven local
repository (`~/.m2/repository/`, populated as a side effect of the
image's build-time `mvn package`). Maven will not need to download
anything when you run `mvn -q exec:java`. **You do not run `mvn
package` here.**

## Step 2: Start the Java Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal. The terminal is rooted in the Java polyglot directory.
Start the Worker via Maven's `exec:java`:

```bash,run
mvn -q exec:java
```

You should see Maven start, JVM start, then SLF4J initialization and
Temporal SDK log lines, and finally:

```bash,nocopy
  ComplianceWorkerApp: started
    Namespace:   compliance-namespace
    Task Queue:  compliance-risk
    Workflow:    ComplianceWorkflowImpl
    Activity:    ComplianceActivityImpl
    Nexus:       ComplianceNexusServiceImpl
```

The Java Worker is now polling `compliance-risk` in
`compliance-namespace`. Same task queue, same namespace, different
language.

> [!WARNING]
> If you see an error about port 7233 or "namespace not found,"
> something has gone wrong with the dev server. Run
> `temporal operator cluster health` in any other terminal to verify.

## Step 3: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-2) terminal.
The terminal is rooted in the Chapter 7 exercise dir. Start the
Worker:

```bash,run
uv run python -m payments.worker
```

This is **the same Python Worker from Chapter 7**. No code changed.
The Endpoint name is the same. The Operation names are the same. The
JSON shapes are the same. The fact that a Java handler is on the
other end is invisible to it.

## Step 4: Run a transaction

Click the [button label="Starter" background="#444CE7"](tab-3)
terminal. Run the regular starter (not the lifecycle starter):

```bash,run
uv run python -m payments.starter
```

The Java Compliance Worker is the **Chapter 6-equivalent** solution
(workflow-backed `check_compliance` plus the human-review path). The
workflow-ID prefix you will see in the UI is `compliance-ch07-` so it
lines up with the Ch7 Python starter you just ran; the workflow body
itself is the Ch6 shape (workflow-backed plus review). So the starter
behaves the same way it did at the end of Chapter 6:

- TXN-A returns immediately with `Result: COMPLETED` / `Risk: LOW`.
- TXN-B blocks. The starter sits on `execute_workflow` waiting for
  TXN-B to complete. On the Compliance side, `compliance-ch07-TXN-B`
  ran the auto-check, classified MEDIUM, slept 10 seconds, and is now
  waiting on a review Update.

Leave the starter running. Move to Step 5 to unblock TXN-B.

## Step 5: Submit the review for TXN-B

Click the [button label="Reviewer" background="#444CE7"](tab-4)
terminal. Run the review starter:

```bash,run
uv run python -m payments.review_starter
```

This is the same `payments.review_starter` you used in Chapter 6. It
builds a `ReviewRequest` approving TXN-B, runs `ReviewCallerWorkflow`
through the `compliance-endpoint`, and returns once the Java
`ComplianceWorkflowImpl` has accepted the Update.

Watch the [button label="Starter" background="#444CE7"](tab-3)
terminal: TXN-B unblocks with `Result: COMPLETED` / `Risk: MEDIUM`,
then the starter moves on to TXN-C, which declines as
`Result: DECLINED_COMPLIANCE` / `Risk: HIGH`.

The `Reason:` strings are byte-for-byte identical to the Python ones,
because the Java handler intentionally returns the same explanation
text the Python handler does. That is the point: the contract
includes the *content* of the result, not just its shape.

> [!NOTE]
> The Java Worker is the Chapter 6-equivalent solution. It implements
> both `check_compliance` (workflow-backed) and the review path. It
> does **not** implement the Chapter 7 failure injections
> (`TXN-FAIL-*`, `TXN-CIRCUIT-*`), so the lifecycle starter is out of
> scope for the polyglot demo. The standard starter plus the review
> starter exercises the happy path that both implementations share.

## Step 6: Inspect the Java-authored workflow

Click the
[button label="Temporal UI" background="#444CE7"](tab-5) tab. Switch
to `compliance-namespace`. Open `compliance-ch07-TXN-A`.

Look for the **Worker Identity** field on the workflow's Detail page,
or run in the starter terminal:

```bash,run
temporal task-queue describe \
  --task-queue compliance-risk \
  --namespace compliance-namespace
```

The Java SDK's default Worker identity is `<PID>@<hostname>` based on
the Java process; the exact rendering in the UI's Detail page may
differ slightly from the CLI output. Earlier chapters showed a Python
interpreter; this chapter shows a JVM. Same task queue, different
runtime.

The Event History on `compliance-ch07-TXN-A` looks like a normal
workflow execution: `WorkflowExecutionStarted`, the activity
round-trip for the rule-based check, and `WorkflowExecutionCompleted`.
Now switch back to `payments-namespace`
and open `payment-ch07-TXN-A`. Because the Java handler also uses
the workflow-backed pattern, the caller's history shows the same
three events as in the earlier pure-Python run:
`NexusOperationScheduled`, `NexusOperationStarted`,
`NexusOperationCompleted`. Identical event names, identical event
order. The bytes are written by Java code on the handler side, but
the caller cannot tell.

## Key Takeaways

That is the workshop. You built a Nexus Service contract in Python,
implemented it as a sync handler, swapped the caller, made it async
with a real workflow, added a human-review path, exercised the
lifecycle modes, and proved that the contract is language-agnostic by
swapping the implementation to Java with **zero changes** on the
caller side.

The Nexus boundary you built isolates teams' deploy cadence,
namespaces, blast radius, and **languages**. Whether the handler is
Python today and Java tomorrow (or the reverse) is a decision the
Compliance team can make on their own.
