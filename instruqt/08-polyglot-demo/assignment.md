---
slug: polyglot-demo
id: ""
type: challenge
title: Polyglot Connector Demo
teaser: Stop the Python Compliance Worker, start a pre-built Java Compliance Worker on the same task queue, and re-run a normal transaction. Same Service contract, different language, no Python code change.
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
- title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/polyglot/java-legacy
- title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/polyglot/java-legacy
- title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/07_lifecycle/exercise
- title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
difficulty: basic
timelimit: 600
---

# Chapter 8: Polyglot Connector Demo

This chapter has no TODOs. The Java Compliance Worker has been
pre-built and is sitting at `/root/workshop/polyglot/java-legacy/`.
You will start it on the **same** `compliance-risk` task queue the
Python Worker was using, then re-run a normal transaction and watch
the Java handler fulfill the same Nexus contract.

## Why this chapter exists

The Service contract you wrote in Chapter 2 is a typed Python class.
Decorators on it (`@nexusrpc.service`,
`nexusrpc.Operation[Input, Output]`) tell the runtime two things:

- The names of the Operations on the wire.
- The JSON shape of each Operation's input and output.

A Java implementation that uses the same Operation names (Java needs
`@Operation(name = "snake_case_name")` to get this right) and the same
JSON field names (Java needs `@JsonProperty("snake_case_name")` on
every data class field) can serve the same callers. **No Python code
change.**

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

Jackson itself does not appear in `pom.xml`; it is pulled in
transitively via `temporal-sdk`. You do not need to declare it.

The Java worker is the Chapter 6 solution equivalent on the Java side
(workflow-backed `check_compliance` plus the review path), with
explicit Jackson and operation-name annotations to match the Python
wire format. Because Workflow histories produced by different SDKs
are not interchangeable, only one of (Python, Java) Compliance Worker
may be active on `compliance-risk` at a time. In this chapter we
stop Python and start Java.

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
- `compliance/temporal/ComplianceNexusServiceImpl.java` (Nexus
  handler, with `@Operation(name = ...)` annotations)
- `compliance/temporal/workflow/ComplianceWorkflowImpl.java` (the
  workflow the Nexus handler launches)
- `compliance/domain/` and `shared/domain/` (data classes carrying
  `@JsonProperty(...)` and `@JsonCreator(mode = PROPERTIES)`
  annotations on their fields and constructors)

The Java Worker has already been compiled when the workshop image was
built. There is a `target/` directory with the dependency jars and
class files. **You do not run `mvn package` here.**

## Step 2: Start the Java Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal. The terminal is rooted in the Java polyglot directory.
Start the Worker via Maven's `exec:java`:

```bash,run
mvn -q exec:java
```

You should see Maven start, JVM start, then the Java SDK banner and
finally:

```output
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

You should see the same three result blocks as Chapter 5: a
`Result: COMPLETED` / `Risk: LOW` block for TXN-A, a
`Result: COMPLETED` / `Risk: MEDIUM` block for TXN-B with the AML
monitoring `Reason:` line, and a `Result: DECLINED_COMPLIANCE` /
`Risk: HIGH` block for TXN-C citing the over-$50,000 threshold rule.

The `Reason:` strings are byte-for-byte identical to the Python ones,
because the Java handler intentionally returns the same explanation
text the Python handler does. That is the point: the contract
includes the *content* of the result, not just its shape.

> Note: The Java Worker is the Chapter 6-equivalent solution. It
> implements both `check_compliance` (workflow-backed) and the review
> path. It does **not** implement the Chapter 7 failure injections
> (`TXN-FAIL-*`, `TXN-CIRCUIT-*`), so the lifecycle starter is out of
> scope for the polyglot demo. The standard starter exercises the
> happy path that both implementations share.

## Step 5: Inspect the Java-authored workflow

Click the
[button label="Temporal UI" background="#444CE7"](tab-4) tab. Switch
to `compliance-namespace`. Open `compliance-TXN-A`.

Look for the **Worker Identity** field on the workflow's Detail page,
or run in the starter terminal:

```bash,run
temporal task-queue describe \
  --task-queue compliance-risk \
  --namespace compliance-namespace
```

The Worker identity reports something like
`pid@hostname` based on the Java process. Earlier chapters showed a
Python interpreter; this chapter shows a JVM. Same task queue,
different runtime.

The Event History on `compliance-TXN-A` looks like a normal
workflow execution: `WorkflowExecutionStarted`,
`ActivityTaskScheduled` for the rule-based check, and
`WorkflowExecutionCompleted`. Now switch back to `payments-namespace`
and open `payment-TXN-A`. The Nexus operation in *this* history
shows the same three events the pure-Python Chapter 5 run produced:
`NexusOperationScheduled`, `NexusOperationStarted`,
`NexusOperationCompleted`. Identical event names, identical event
order. The bytes are written by Java code on the handler side, but
the caller cannot tell.

## Step 6: Stop both Workers

Press `Ctrl+C` in both Worker terminals, or:

```bash,run
pkill -f "payments.worker"     || true
pkill -f "ComplianceWorkerApp" || true
```

## Wrapping up

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

> Where to go next:
>
> - The Temporal docs on Nexus:
>   `https://docs.temporal.io/nexus`.
> - The Python Nexus tutorial on learn.temporal.io.
> - The `samples-python/nexus_*` directories for additional patterns:
>   the in-workflow cancellation pattern (`asyncio.create_task` +
>   `task.cancel()`), worker-side cleanup with `asyncio.shield`, and
>   more.
> - For polyglot work: the `samples-java/.../nexus/` directory for
>   how the Java side declares the same contract with explicit
>   `@Operation(name=...)` and `@JsonProperty(...)` annotations.
