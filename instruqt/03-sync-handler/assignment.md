---
slug: sync-handler
id: ej0zdzotknxb
type: challenge
title: Implement the Sync Handler
teaser: Implement a synchronous Nexus handler for the check_compliance Operation,
  register it on a brand new Compliance Worker, and watch the Worker poll the compliance-risk
  task queue.
notes:
- type: text
  contents: |-
    # Sync handlers, the 10-second deadline, and Worker registration

    A synchronous Nexus Operation is one whose handler runs to
    completion within 10 seconds and returns a result directly. No
    workflow runs on the Compliance side. The handler is just a
    decorated `async def` method.

    In this chapter you will implement the synchronous handler for
    `check_compliance`, then register the handler class on a new
    Compliance Worker. The Compliance Worker is the first piece of the
    workshop that lives in `compliance-namespace` and polls the
    `compliance-risk` task queue.

    The Payments side is unchanged in this chapter. Payments still
    calls compliance as a local Activity. We swap that to a Nexus
    call in Chapter 4.
tabs:
- id: xfdtnwwhspay
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/03_sync_handler/exercise
- id: e7jjwc3fiqn3
  title: Compliance Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/03_sync_handler/exercise
- id: qq9b9ssolert
  title: Payments Worker
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/03_sync_handler/exercise
- id: zejg03cce3vo
  title: Starter
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/03_sync_handler/exercise
- id: bmzepejh9nox
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
- title: Solution
  type: code
  hostname: workshop
  path: /root/workshop/exercises/03_sync_handler/solution
difficulty: intermediate
timelimit: 1800
enhanced_loading: null
---

# Chapter 3: Implement the Sync Handler

Now you write the Compliance side. By the end of the chapter the
Compliance Worker will be running in `compliance-namespace`, polling
the `compliance-risk` task queue, with a registered handler for the
`check_compliance` Nexus Operation. Payments is unchanged; it still
calls a local Activity.

## Why this chapter exists

A Nexus Operation has two sides: the **caller** (the workflow that
invokes the Operation) and the **handler** (the code that fulfills it).
You wrote the contract in Chapter 2. This chapter writes the handler.

Two things matter:

1. **Synchronous handlers complete in 10 seconds or less.** This is a
   hard cap. Anything longer must be implemented as a
   workflow-backed asynchronous Operation, which you will see in
   Chapter 5. For `check_compliance`, the rule-based check returns in
   milliseconds, so sync is fine for now.
2. **The Worker registers the handler via the
   `nexus_service_handlers` argument**, exactly the way it registers
   workflows and activities. This makes the Worker a participant in
   the Nexus Endpoint's task queue.

The decorator stack that turns a class into a Nexus handler is small:

- `@nexusrpc.handler.service_handler(service=...)` on the class binds
  it to a specific Service contract.
- `@nexusrpc.handler.sync_operation` on each method declares it as a
  synchronous Operation handler.

That is the whole API. The handler is just an async method that takes
the typed input and returns the typed output.

## What you will do

- Apply **TODO 2** to decorate `ComplianceNexusServiceHandler` and
  implement the `check_compliance` and `submit_review` methods.
- Apply **TODO 3** to register the handler on the Compliance Worker.
- Start the Compliance Worker in `compliance-namespace`.
- Start the Payments Worker (still the monolith from Chapter 1).
- Run the starter and watch transactions flow.

The Payments Worker still uses its local `check_compliance` Activity
because Chapter 4 has not happened yet. The Compliance Worker is up
but nothing is calling it. That is expected. We are validating the
plumbing, not the data flow.

## Step 1: Apply TODO 2 in `compliance/service_handler.py`

Open `compliance/service_handler.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). The file
contains a class `ComplianceNexusServiceHandler` with two methods that
return `None`.

Three changes:

1. Add the service-handler decorator above the class:

   ```python
   @nexusrpc.handler.service_handler(service=ComplianceNexusService)
   class ComplianceNexusServiceHandler:
       ...
   ```

2. Decorate `check_compliance` with `@nexusrpc.handler.sync_operation`
   and replace the `return None` body with a call to the rule-based
   check:

   ```python
   @nexusrpc.handler.sync_operation
   async def check_compliance(
       self, ctx: nexusrpc.handler.StartOperationContext, input: ComplianceRequest
   ) -> ComplianceResult:
       return _check_compliance(input)
   ```

3. Decorate `submit_review` with `@nexusrpc.handler.sync_operation`
   and replace its body with a `NotImplementedError` stub. The real
   implementation arrives in Chapter 6:

   ```python
   @nexusrpc.handler.sync_operation
   async def submit_review(
       self, ctx: nexusrpc.handler.StartOperationContext, input: ReviewRequest
   ) -> ComplianceResult:
       raise NotImplementedError(
           "submit_review needs a workflow to send Updates to "
           "(introduced in Ch 5; implemented in Ch 6)"
       )
   ```

Both methods are async and take a `StartOperationContext` plus a typed
input. The return type matches the Operation declaration in the
contract. If you mistype the input or output, Python's type checker
will not catch it at file-load time, but the Nexus runtime will reject
the registration when the Worker starts.

## Step 2: Apply TODO 3 in `compliance/worker.py`

Open `compliance/worker.py`. Find the TODO 3 comment in the `Worker(...)`
constructor call. Add the `nexus_service_handlers` argument:

```python
worker = Worker(
    client,
    task_queue=TASK_QUEUE,
    nexus_service_handlers=[ComplianceNexusServiceHandler()],
)
```

The Worker polls the `compliance-risk` task queue (set above by the
`TASK_QUEUE` constant). That name **must** match the
`--target-task-queue` you gave when creating the Endpoint in Chapter 2.

## Step 3: Start the Compliance Worker

Click the
[button label="Compliance Worker" background="#444CE7"](tab-1)
terminal. Start the Worker:

```bash,run
uv run python -m compliance.worker
```

You should see a startup banner that ends with:

```bash,nocopy
  Compliance Worker started on: compliance-risk
  Namespace: compliance-namespace
  Registered: ComplianceNexusServiceHandler (sync only)
```

Two things to notice:

1. The namespace is `compliance-namespace`, not `default`. Compliance
   has its own execution boundary now.
2. There are no workflows or activities registered. The Compliance
   Worker exists only to serve Nexus Operations.

Leave the Worker running.

## Step 4: Start the Payments Worker

Click the
[button label="Payments Worker" background="#444CE7"](tab-2) terminal.
Start the Payments Worker:

```bash,run
uv run python -m payments.worker
```

This is still the **monolith** version of the Payments Worker. It runs
in `payments-namespace`, polls `payments-processing`, and uses its
local `check_compliance` Activity. We swap that out in Chapter 4.

## Step 5: Run the starter

Click the [button label="Starter" background="#444CE7"](tab-3)
terminal. Run the starter:

```bash,run
uv run python -m payments.starter
```

You should see the same three results as Chapter 1: TXN-A approved
LOW, TXN-B approved MEDIUM with monitoring, TXN-C declined HIGH. The
Payments Worker's history will still show
`ActivityTaskScheduled` for `check_compliance`. **Nothing has been
routed through Nexus yet.**

That is the expected end-state for Chapter 3. The Compliance Worker is
a Nexus participant, but no caller has been wired to it.

## Step 6: Confirm both Workers are healthy

In the Web UI, click **Workers** in the left navigation. Switch
namespaces with the selector at the top.

- In `payments-namespace`, you should see one Worker polling
  `payments-processing` (the Payments Worker).
- In `compliance-namespace`, you should see one Worker polling
  `compliance-risk` (the Compliance Worker).

Both Workers are alive. Chapter 4 connects them.

## Step 7: Stop both Workers

Press `Ctrl+C` in both Worker terminals (or use the cleanup at the
end of the challenge). You can also stop them from the Starter
terminal:

```bash,run
pkill -f "compliance.worker" || true
pkill -f "payments.worker"   || true
```

## Wrapping up

You wrote the synchronous handler that fulfills the `check_compliance`
contract, and you stood up a brand new Compliance Worker to serve it.
The handler runs in `compliance-namespace` and is a participant in the
`compliance-endpoint` Nexus Endpoint. Right now nothing is calling it,
because the Payments side still uses a local Activity.

In Chapter 4 you swap the Payments-side activity call for a Nexus call,
and the two halves of the application start talking to each other
across the namespace boundary for the first time.
