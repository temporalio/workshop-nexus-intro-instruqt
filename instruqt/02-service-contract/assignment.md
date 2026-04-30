---
slug: service-contract
id: prtnkhqjne0i
type: challenge
title: Define the Nexus Service Contract
teaser: Write the typed Python contract that the Payments and Compliance teams will
  share, then register a Nexus Endpoint that routes calls to the Compliance team.
notes:
- type: text
  contents: |-
    # Nexus has four building blocks

    Before you write any code, learn the vocabulary.

    - **Service**: a typed Python class that names the operations
      the Compliance team exposes. Both teams import it.
    - **Operation**: a single typed call inside a Service (input
      type, output type).
    - **Endpoint**: a server-side routing rule. Carries the target
      namespace, task queue, and a Markdown description.
    - **Registry**: what the server consults at dispatch time to
      resolve a Nexus request to its target. Endpoint names must be
      unique within it. The Web UI surfaces the Registry as a side
      benefit.

    In this chapter you will define the Service and Operations in
    Python, then create the Endpoint with the Temporal CLI.
tabs:
- id: bv3whihu2haz
  title: Code Editor
  type: code
  hostname: workshop
  path: /root/workshop/exercises/02_service_contract/exercise
- id: ystkhevci7d2
  title: Terminal
  type: terminal
  hostname: workshop
  workdir: /root/workshop/exercises/02_service_contract/exercise
- id: mtbmtvcf6wey
  title: Temporal UI
  type: service
  hostname: workshop
  port: 8233
- id: mkyu8fxrz4kn
  title: Solution
  type: code
  hostname: workshop
  path: /root/workshop/exercises/02_service_contract/solution
difficulty: basic
timelimit: 1200
enhanced_loading: false
---

In this chapter you define the shared Nexus Service contract between the
Payments and Compliance teams, and stand up the routing infrastructure
that will carry calls across the team boundary: a Nexus Endpoint that
points callers at the Compliance team's task queue.

## What You're Solving

Nexus exists so that two teams can call each other's Temporal code
without sharing a codebase or having to share a namespace. The
mechanism that makes that work is a **typed contract** that both teams
import, plus a **routing rule** (the Endpoint acts as a reverse proxy
to a target task queue) in the server that says "calls to this
Endpoint go to that team."

There are two distinct artifacts in this chapter:

- The **Service contract** is a Python class decorated with
  `@nexusrpc.service`. It names the Operations and types their inputs
  and outputs. It lives in `shared/service.py`. Payments imports it to
  build a caller-side stub; Compliance imports it to implement a
  handler. The dev server has no awareness of this class. It is a pure
  Python interface that both teams agree on.
- The **Endpoint** is a routing rule in the dev server's Nexus
  registry. It carries the target namespace, task queue, and a Markdown
  description that documents what the contract exposes. The Endpoint
  description is the only Markdown-rendered field Nexus exposes in the
  Web UI. The Endpoint name, target namespace, and target task queue
  also render on the Nexus Endpoints index (as plain text), and
  `NexusOperation*` events show up in workflow histories once a caller
  workflow is dispatching through it.

By the end of the chapter you will be able to navigate to **Nexus
Endpoints** in the Web UI and see the Endpoint description rendered as
Markdown. That description is what an engineer on a different team
reads first when they want to call your Service.

> [!NOTE]
> The two namespaces (`payments-namespace` and `compliance-namespace`)
> were pre-created when you entered the workshop. The Endpoint is the
> only routing artifact you create in this chapter. From now on, every
> chapter assumes both namespaces exist.

> [!NOTE]
> The contract interface lives in the `shared/` package because both
> teams import it. Neither team owns the interface itself. `payments/`
> and `compliance/` each import `ComplianceNexusService` from
> `shared/service.py`, which is what makes the contract a third
> artifact rather than something either team can change unilaterally.
> The request and result dataclasses live alongside their domain
> teams (`compliance.models` for `ComplianceRequest` /
> `ComplianceResult`, `shared.models` for `ReviewRequest`), so each
> team owns the data shapes they introduced.

## What you will do

- Apply **TODOs 1a–1c** to add `@nexusrpc.service` and the typed
  Operation declarations to `shared/service.py`.
- Verify the two namespaces exist.
- Create the `compliance-endpoint` Nexus Endpoint with the Temporal
  CLI, attaching a Markdown description from `compliance-endpoint.md`.
- Find the Endpoint in the Web UI and read its Markdown description.

> [!NOTE]
> Stuck on a TODO? The **Solution** tab (rightmost) shows the finished
> file. Try the exercise first, then peek if you need to.

## Step 1: Apply TODOs 1a–1c in `shared/service.py`

Open `shared/service.py` in the
[button label="Code Editor" background="#444CE7"](tab-0). The file
contains a `ComplianceNexusService` class with three TODO markers and
a placeholder `pass`.

### TODO 1a: Decorate the class

Add `@nexusrpc.service` directly above the `class ComplianceNexusService:`
line:

```python
@nexusrpc.service
class ComplianceNexusService:
```

### TODO 1b: Declare the `check_compliance` Operation

Inside the class body, add the typed Operation:

```python
check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]
```

### TODO 1c: Declare the `submit_review` Operation

Directly below it, add:

```python
submit_review: nexusrpc.Operation[ReviewRequest, ComplianceResult]
```

You can remove the `pass` line once both operations are declared. The
class no longer needs it.

After your edits, the relevant block should look like:

```python
@nexusrpc.service
class ComplianceNexusService:
    """Nexus Service Interface - the shared contract between Payments and Compliance teams."""

    check_compliance: nexusrpc.Operation[ComplianceRequest, ComplianceResult]
    submit_review: nexusrpc.Operation[ReviewRequest, ComplianceResult]
```

Both Operations belong in the contract from the start. The contract
declares the full surface area both teams will use; the matching
handlers and caller wiring come later in this workshop.

> [!WARNING]
> If you forget the `@nexusrpc.service` decorator, the file still
> loads. The class is just an undecorated Python class with no Nexus
> metadata. Nothing complains until a module that depends on the
> contract is imported, e.g., a handler module that applies
> `@nexusrpc.handler.service_handler(service=ComplianceNexusService)`
> at import time and raises a message like:
>
> ```text
> ValueError: <class 'shared.service.ComplianceNexusService'> is not a
> valid Nexus service definition. Use the @nexusrpc.service decorator
> on a class to define a Nexus service definition.
> ```
>
> The error fires before the Worker is constructed, but the traceback
> points at the handler module, not the contract, so it can look like
> a handler-side bug when it is really a missing decorator on the
> contract. Catching it now saves debugging later: the line above the
> class must be `@nexusrpc.service`, and both Operation lines must use
> the `nexusrpc.Operation[Input, Output]` annotation form (no `=`, no
> body).

## Step 2: Verify the namespaces

The Payments and Compliance teams live in separate namespaces. Each
namespace is its own isolated execution environment with separate
workflows and separate task queues (and, in production or on Temporal
Cloud, separate access control via a configured Authorizer). **Nexus
is the only thing that crosses the boundary.**

Both namespaces were created for you when the track started. Verify
they exist. In the [button label="Terminal" background="#444CE7"](tab-1):

```bash,run
temporal operator namespace list
```

You should see `payments-namespace` and `compliance-namespace`
alongside `default` and `temporal-system`.

## Step 3: Create the Nexus Endpoint

A Nexus Endpoint is a routing rule. It tells the server: when a caller
invokes the Endpoint named `compliance-endpoint`, deliver the request
to a Worker polling the `compliance-risk` task queue in
`compliance-namespace`. Callers reference the Endpoint by name. They do
not need to know the target namespace or task queue.

The Endpoint also carries a Markdown description that documents the
contract for anyone browsing the registry. We ship one at the repo
root in `compliance-endpoint.md`.

Create the Endpoint:

```bash,run
temporal operator nexus endpoint create \
  --name compliance-endpoint \
  --target-namespace compliance-namespace \
  --target-task-queue compliance-risk \
  --description-file /root/workshop/compliance-endpoint.md
```

Confirm it exists and the description is attached:

```bash,run
temporal operator nexus endpoint list
```

```bash,run
temporal operator nexus endpoint get --name compliance-endpoint
```

The `get` output should include the Markdown description from
`compliance-endpoint.md` under the `Description` field.

## Step 4: Find the Endpoint in the Web UI

Click the [button label="Temporal UI" background="#444CE7"](tab-2)
tab. In the left navigation, click **Nexus Endpoints** (or browse to
`/nexus/endpoints` directly).

You should see a single Endpoint row, `compliance-endpoint`, targeting
`compliance-namespace` / `compliance-risk`. Click into it. You will see
the description rendered as Markdown. **This page is what an engineer
on a different team would look at to understand what the Endpoint
exposes before writing a caller workflow against it.**

The Endpoint exists at the cluster level on a self-hosted server like
the workshop dev server, and at the account level on Temporal Cloud.
Either way, it is not scoped to any one namespace, which is what lets
it bridge teams.

## Key Takeaways

You wrote the contract that the Payments and Compliance teams will
share, and you registered the routing rule that the dev server will use
to deliver calls between them. There is no Worker to start in this
chapter. The contract is just Python; the Endpoint is just a row in the
server's registry.

With the contract written and the Endpoint registered, the Compliance
team has everything it needs to implement a handler against this
Service, and the Payments team has everything it needs to build a
caller-side stub against the same shared interface.

> [!NOTE]
> Take-away: the contract is ordinary Python. The Nexus runtime reads
> the type annotations on a `@nexusrpc.service` class to figure out
> what operations exist and what shape their requests and responses
> take. The contract has no UI surface; it lives only in the Python
> files both teams import. The Endpoint is the matching server-side
> artifact, plus a description that documents what the contract does.
