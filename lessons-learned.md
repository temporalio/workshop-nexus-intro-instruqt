# Lessons Learned: Workshop Nexus Intro

A running record of design decisions, discoveries, and gotchas from building the Replay 2026 Nexus workshop. Organized by topic. Each bullet is intended to be self-contained so it can become a slide, a callout in a tutorial, or a sentence in a retro.

## Course design (Performance-Based Learning)

- **Start with the outcome, work backwards.** PBL forced us to define competencies first, then objectives, then performance assessments, then activities. Without this discipline we would have written exercises around what the existing Java tutorial does and ended up with a workshop that teaches "the tutorial" instead of "Nexus." Backwards design surfaces gaps.
- **"Understanding when to use X" is a real outcome and deserves competency status.** The first cut of competencies was all "do" verbs (decouple, implement, configure). The "primary goal is to introduce Nexus" framing meant we had no competency for the actual introduction. Adding a 4th competency at Bloom's Analyze level ("Distinguish when to use Nexus versus other Temporal integration patterns") fixed it. PBL gives a verb at every cognitive level so you do not need to reach for "understand."
- **Match Bloom's level to Dreyfus stage.** The audience knows Temporal (Advanced Beginner) but is new to Nexus (Novice). Apply-level competencies for the doing parts. Analyze-level for the choosing part because they have enough Temporal context to compare. Going higher (Evaluate, Create) would overshoot in a 3.5-hour workshop.
- **Write performance criteria before activities.** Every criterion must be testable. The criterion "Caller's Event History shows three Nexus events: Scheduled, Started, Completed" maps directly to a Web UI inspection step; the activity falls out of it.
- **Lecture before every exercise.** Our first cut had one upfront lecture and then a parade of exercises. Mason pushed back: "How are they supposed to learn the concept enough to do the exercise?" Each chapter now interleaves a short lecture cluster with one exercise, matching the edu-101 chapter format.
- **Roughly 45/55 lecture/exercise ratio.** Less than 50/50 keeps it hands-on without making attendees code in a vacuum. Each lecture cluster is built from "here is the problem you are about to hit" and the concept introduced as the answer (andragogy: orient to problems, not content).

## Nexus pedagogy

- **The four building blocks frame the rest of Nexus.** Service, Operation, Endpoint, Registry. Once attendees know which thing is which, the SDK API stops feeling magical. The first lecture spends most of its time on this vocabulary.
- **Sync handlers are easier to teach first, async second.** The original Java tutorial bundles `@workflow_run_operation` with `@sync_operation` in one chapter. Splitting them into Ch 3 (sync) and Ch 5 (async) gave us a clean pedagogical arc and a real "implement async" exercise. Without the split, Ch 5 would have nothing to implement because the async path already works in Ch 4.
- **MEDIUM-risk human review is the moment that sells Nexus.** TXN-B blocking until a reviewer submits an Update is the part attendees remember. It works because the underlying ComplianceWorkflow is durable, not because the Nexus operation is special. The Nexus part is just "expose this workflow to other teams without sharing namespaces."
- **The 10-second sync handler deadline is a teaching moment.** Most attendees will instinctively want to run "the work" inside a sync handler. The deadline forces the conceptual split: sync handlers for short interactions with existing state, workflow-backed async for anything with real duration.
- **The Started event is the visible difference between sync and async.** Tell attendees to look for `NexusOperationStarted` in the caller's history. If it is there, the operation is async. If only Scheduled and Completed appear, it is sync. This single observation crystallizes the lifecycle.
- **The circuit breaker per (caller-Namespace, Endpoint) pair is non-obvious and worth a slide.** It protects the platform; misbehaving Compliance code does not bring down all of Payments. The 5-errors-then-60-seconds-open behavior is concrete enough to demonstrate.

## Snapshot chain design

- **Each chapter's `solution/` is byte-identical to the next chapter's `exercise/`.** This identity makes the chain self-checking (`diff -rq` confirms it) and allows attendees to drop in at any chapter without prior chapters being done. It also lets Instruqt `solve` scripts copy the solution snapshot forward without reconstructing state.
- **The chain breaks textually but not behaviorally when a chapter introduces a new TODO in a previously-stable file.** Ch 6 introduces TODO 11 in `nexus_handler.py`, a file that Ch 5 already wrote. The Ch 5 sol vs Ch 6 ex difference is just an inline comment. Acceptable break; runtime behavior is identical.
- **Per-chapter incremental snapshots cost more disk than a single progressive codebase, but the cost is small.** Six 18-file snapshots of mostly-identical content totals well under a megabyte. The win in attendee onboarding ("just `cd` and run") is worth it.
- **Common files belong outside the changing files.** Most files (domain dataclasses, activities, payment gateway, starters, init files) do not change across snapshots. Identifying these once and rsync-ing them as a base saves both authoring effort and review effort.
- **Use a single root `pyproject.toml`, not per-snapshot.** The dependencies are identical across all 12 snapshots. One root file, one shared `.venv`, and `uv run` walks up the directory tree to find it. Per-snapshot pyprojects were noise.

## Repo structure

- **Code repo and content repo are separate.** `workshop-nexus-intro-code` holds Python and Java exercises. `workshop-nexus-intro` holds slides, course plan, and (eventually) Instruqt definition. The Tailscale workshop monorepo is a useful counter-example: mixing Python, Slidev, mkdocs, and Instruqt configs at one repo's root produces clutter that tires the eye.
- **Public-facing edu repos do not need ABOUTME comment headers.** The user's global `# ABOUTME:` convention is for personal grep-friendly metadata. Stripped from the workshop repo to look like clean educational code.
- **Tree-drawing characters are fine in READMEs but not in code.** Box-drawing in print banners or comment blocks reads as AI-generated when the rest of the file is plain Python. Keep tree characters in markdown for directory diagrams; replace with hyphens and pipes everywhere else.
- **Keep the asset import explicit.** The Java polyglot directory was copied verbatim from `edu-nexus-code/java/decouple-monolith/solution/`, then patched for snake_case. Document the provenance in the README so the next person knows what to compare against if they upgrade the source.

## Python Nexus SDK patterns

- **`@nexusrpc.service` on a Python class with `nexusrpc.Operation[Input, Output]` typed fields is the contract.** Both teams import this class. The decorator and type annotations carry all the metadata the runtime needs.
- **`@nexus.workflow_run_operation` returns a `WorkflowHandle`, not the workflow result.** The handler's job is to start the workflow; the Nexus machinery takes care of forwarding the eventual result. Common confusion when attendees first see the pattern.
- **`@nexusrpc.handler.sync_operation` covers everything that fits in 10 seconds.** Use it for Update calls, Query calls, simple CRUD against an existing workflow. Do not use it for anything that needs to survive a worker restart; that is what async + workflow-backing is for.
- **Sync handlers can call Temporal SDK operations directly via `nexus.client()`.** The submit_review handler shows the pattern: get the client, get a workflow handle, send the Update, return the result. All in one async function.
- **The `@review.validator` on a workflow Update is what makes Updates idempotent and safe.** It rejects review attempts that arrive before the workflow is ready or after a decision is already made. Without it, a duplicate Update could overwrite the first one. Worth pointing out in the lecture; many attendees miss it.
- **Configure timeouts on the caller side, not the handler side.** `schedule_to_close_timeout` is the overall ceiling. `schedule_to_start_timeout` trips early if no worker picks it up. `start_to_close_timeout` bounds the handler's runtime. The handler does not get to choose its own deadlines.
- **Use `uv run` for everything.** It walks up to find `pyproject.toml`, resolves the venv, and runs the command. Saves attendees from hunting for the right `python` binary or activating the venv manually.

## Cancellation patterns

- **Cancellation only applies to async operations.** Sync handlers hold no operation token; there is nothing to cancel. Tell attendees this up front.
- **The canonical Python cancellation pattern is `start_operation` + `asyncio.create_task` + `task.cancel()`.** This comes from `samples-python/nexus_cancel`. The caller workflow gets a handle on the operation and can cancel that specific task. Cleaner than cancelling the whole caller workflow.
- **External `client.cancel_workflow()` on the caller works but is the "blunt" version.** Cancellation propagates from the cancelled workflow through the in-flight Nexus operation to the underlying handler workflow. Useful for demos, less idiomatic for application code.
- **Cancellation propagation is observable.** The caller's history shows `NexusOperationCancelRequested`, `NexusOperationCancelRequestCompleted`, then `NexusOperationCanceled`. The handler workflow ends in `Canceled` state. Six events of evidence that the cancel made it through the boundary.
- **Handler workflows should catch `asyncio.CancelledError` and use `asyncio.shield` for cleanup.** Without this, cleanup work might also be cancelled. The pattern is "catch, do cleanup under a shield, re-raise." Shows up in `samples-python/nexus_cancel/handler/workflows.py`.
- **The cancellation type changes how long the caller waits for the cancel to land.** ABANDON does not wait at all; TRY_CANCEL waits for the request to be sent; WAIT_REQUESTED waits for the handler to acknowledge; WAIT_COMPLETED (default) waits for the handler to actually finish cleanup. Pick the weakest one that meets your correctness needs.

## Error handling and circuit breaker

- **`nexusrpc.OperationError` is non-retryable.** Use it for "this operation cannot succeed regardless of how many times you try." The caller records `NexusOperationFailed` and stops retrying.
- **`nexusrpc.HandlerError` is retryable by default but the type controls it.** `BAD_REQUEST`, `UNAUTHENTICATED`, `UNAUTHORIZED`, `NOT_FOUND`, `NOT_IMPLEMENTED` are non-retryable. `RESOURCE_EXHAUSTED`, `INTERNAL`, `UNAVAILABLE`, `UPSTREAM_TIMEOUT` are retryable. Picking the right type is part of the API design.
- **Failure injection by transaction-id prefix is a clean way to demo lifecycle behaviors without changing every handler.** The Ch 6 handler recognizes `TXN-FAIL-NONRETRY`, `TXN-FAIL-RETRY`, `TXN-CIRCUIT` prefixes and raises matching errors. Normal transactions go through unchanged. Lets one starter exercise four different failure modes.
- **The circuit breaker opens after 5 consecutive retryable failures on a (caller-Namespace, Endpoint) pair, not per-workflow.** This is per-pair; one misbehaving handler trips the breaker for everyone calling that endpoint from that namespace. Important when explaining why a single bad transaction can affect unrelated workflows.
- **Circuit-breaker state surfaces in `Pending Nexus Operations` as `State: Blocked` with `BlockedReason: The circuit breaker is open.`** Visible in the Web UI and in `temporal workflow describe`. Use this in the demo to show the breaker is real.
- **The breaker's half-open probe is a single request after 60 seconds.** Pass the probe and it closes. Fail and it reopens for another 60 seconds. Worth a slide.

## Polyglot interop (Python <-> Java)

- **Python and Java SDKs do not agree on default operation names or JSON field names.** Python uses snake_case for both (it follows Python idioms). Java uses camelCase (it follows Java idioms). Without explicit overrides, the wire formats do not align and cross-language calls fail.
- **Operation name: Java needs `@Operation(name = "snake_case_name")` to receive Python calls.** Without the explicit name, Java publishes the operation as `checkCompliance` and Python's call to `check_compliance` returns `NOT_FOUND: Unrecognized service ComplianceNexusService or operation check_compliance`.
- **Data class field names: Java needs `@JsonProperty("snake_case_name")` on every field, getter, and constructor parameter to receive Python data.** Without it, Jackson defaults to camelCase JSON keys and deserialization fails with `UnrecognizedPropertyException`. Errors look like field-name mismatches but are really serialization-format mismatches.
- **Use `@JsonCreator(mode = JsonCreator.Mode.PROPERTIES)` constructors so Jackson constructs the object from the JSON keys directly.** Standard Java convention for Jackson interop with explicit field names.
- **The polyglot tax falls on whichever side has the less idiomatic naming.** We added the annotations to Java because the Python contract should look like Python. The reverse choice (Python operation names in camelCase) would work but feel wrong to read.
- **Maven's `exec:java` ignores `-Dexec.mainClass` if a default mainClass is set in the pom.xml configuration block.** The Java polyglot pom.xml defaults to `payments.temporal.PaymentsWorkerApp`. Trying to override with `-Dexec.mainClass=compliance.temporal.ComplianceWorkerApp` silently runs the Payments worker. Use the named execution (`mvn exec:java@compliance-worker`) instead. Worth documenting in the workshop's polyglot demo instructions.
- **Worker identity in `temporal task-queue describe` output is just `pid@hostname`.** Helpful for debugging which process is on which queue. We caught the wrong-mainClass issue by noticing the Java worker was polling `payments-processing` instead of `compliance-risk`.
- **The polyglot demo only needs ONE side at a time on the task queue.** Two workers on the same task queue race for tasks. For the demo, stop the Python compliance worker before starting the Java one.

## Testing and operational

- **macOS `pkill -f` does not respect regex alternation.** `pkill -f "x\|y"` and `pkill -f "x|y"` silently match nothing. Use separate calls per pattern. This caused a 30-minute debugging session where multiple workers from different chapters were running concurrently and racing on the same task queue, producing tests that "passed" with wrong code paths. Always verify with `ps aux | grep` afterward.
- **Old workers from previous chapter tests can pick up workflows from later chapters.** If two workers register on the same task queue but for different code versions (or different namespaces by accident), Temporal can hand a workflow task to either. The first round of Ch 5 testing showed monolith behavior because a Ch 2 worker was still polling `payments-processing` and ran the older code.
- **Python output is buffered when running via `uv run`.** Use `PYTHONUNBUFFERED=1` and `python -u` for tests where you need to see output in real time. Without these, captured output appears empty until the process exits.
- **`temporal workflow describe` output changes mid-flight.** A Pending Operation in `BackingOff` state is only observable while the workflow is actually running. Once you cancel or terminate, that state is gone. To capture circuit-breaker `Blocked` state for a screenshot, run `describe` while the demo is in flight.
- **`temporal workflow show -w <id>` only shows the latest run by default.** When ID-reuse policy creates multiple runs, this can confuse history inspection. The list view (`temporal workflow list`) shows all runs. Useful when chasing why a `payment-TXN-X` looks different than the test you just ran.
- **The PaymentProcessingWorkflow's try/except catches the Nexus operation's failure as a regular Exception and returns `status=FAILED`.** This means `client.execute_workflow()` returns the FAILED result rather than raising. Tests need to inspect the result, not just rely on `try/except`. Took a wrong turn before catching this.
- **Background processes started via the harness need explicit cleanup.** `pkill` and verifying with `ps` is the discipline. Otherwise workers from earlier tests linger and pollute later tests. Captured this as a memory entry for future sessions.

## Style and writing conventions

- **No em-dashes anywhere in writing.** They read as AI-generated. Use commas, colons, parentheses, or sentence breaks instead. Apply this to READMEs, docs, slides, and code comments. The user rejected a draft of `course-plan.md` that had em-dashes.
- **Tree-drawing characters in markdown directory diagrams are fine.** Box-drawing characters in code comments or `print` banners are not.
- **No `# ABOUTME:` headers in public-facing edu repos.** That convention is for personal grep-friendly metadata. Strip them from anything attendees will see.
- **Avoid Python's `→` arrows in code comments.** Use `->` instead. The arrow looks fine in markdown but reads as AI-generated in `.py` files.
- **Lecture content frames the problem before introducing concepts.** Andragogy says adults learn best when they see "what's in it for me" up front. Every chapter's first slide names the problem; the second introduces the Nexus piece that solves it.

## Instruqt platform

- **Verify Instruqt features against the actual docs, not a summary, before designing around them.** A sidecar dev server using `containers[].command:` looked like the right pattern, but `command:` is not in the public Instruqt schema docs and the inspiration workshop (`temporal-java-hands-on`) actually used `virtualmachines:` with nested Docker, not native containers. The discovery cost was low (caught at scaffolding) but easily could have been high. Pull the actual `track/config.yml` from any reference repo before assuming what its features mean.
- **Native Instruqt `containers:` is the simplest path; reserve `virtualmachines:` for nested-Docker use cases.** Containers provision in seconds, support custom GHCR images, and have enough room for a Temporal dev server, two Python workers, and a JDK plus Maven.
- **Bake the install into the image.** Versioning workshop installs everything in `setup-workshop` at runtime; Java hands-on bakes a custom GHCR image. The bake-it-in pattern is strictly faster (seconds, not minutes) and gives you a precisely versioned environment per attendee. Worth the extra Dockerfile + GHA workflow.
- **In-process dev server > sidecar for "single container" workshops.** One image to build, no undocumented Instruqt fields, PID tracked in /tmp/temporal-server.pid for targeted kill, output to /tmp/temporal-server.log. The PID file plus a separate `temporal operator cluster health` poll for readiness is the whole pattern.
- **Per-challenge `cleanup-workshop` should kill workers but not the dev server.** Track-level cleanup kills the dev server. This way the attendee does not lose dev server state when transitioning between challenges; they only lose their worker processes, which they were going to restart anyway.
- **Idempotent `temporal operator nexus endpoint create || true` in every Ch 2-onwards setup script** is the right pattern. Belts-and-braces in case the attendee skipped Ch 2 via solve.

## Workshop format

- **3.5 hours is enough for 6 chapters with breaks if scope is tight.** Our final budget: 5 min welcome, 6 chapter blocks totaling 165 min, 30 min break, 5 min polyglot, 10 min wrap. The break placement (11:00 to 11:30) was Mason's call; everything else fell out of chapter timing.
- **One break is plenty.** Two 15-minute breaks fragment the flow more than they help. Attendees do better with a single solid break around the midpoint.
- **Live workshop and self-paced share the same lab definition.** Instruqt Live Event mode adds the instructor dashboard; everything else is identical. Build for self-paced as the harder constraint and the live mode comes free.
- **Validate with `temporal workflow describe` polls in `check` scripts, not by waiting for completion.** Instruqt's 30-second check timeout means you cannot wait for a long workflow to finish. Poll for state instead.
- **Pre-warm Hot Start ~30 minutes before the live workshop.** Attendees should not see a "provisioning your sandbox" screen at 9:00.

## Discoveries that surprised us

- **`MEDIUM` risk is auto-approved (`approved=True`) by the rule-based ComplianceChecker.** With an "AML monitoring note." This means in the sync-only Ch 3-4 design, TXN-B completes successfully even without human review. We initially thought TXN-B would fail in Ch 4 and only succeed in Ch 5 once review was added. It does not; it succeeds either way, but the path differs. Worth noting in the chapter README.
- **`asyncio.CancelledError` is a `BaseException`, not `Exception`.** A `try/except Exception` in a workflow does not catch cancellation. This is correct behavior but trips up developers expecting cancellation to flow through generic error handling.
- **`@Operation` and `@JsonProperty` do not appear in the basic Java Nexus tutorial.** They are introduced in `samples-java/.../nexus/service/SampleNexusService.java`. If you copy from the basic tutorial without these annotations, polyglot fails silently.
- **The Nexus operation result is what shows up in the caller's `await` return value.** This sounds obvious but matters when designing the workflow protocol. The handler workflow's return value becomes the Nexus operation's result becomes the caller's `compliance` variable. Three layers of indirection that all need to use compatible types.

## Open questions

- The Ch 6 lifecycle starter currently demonstrates cancellation by externally cancelling the caller workflow. The samples-python `nexus_cancel` pattern (in-workflow `start_operation` + `task.cancel()`) is more idiomatic but adds a new caller workflow. Decide which pattern the workshop should teach.
- The polyglot demo currently requires stopping the Python compliance worker before running the Java one. For Instruqt, decide whether the Java worker is pre-running and the Python one is stopped on demand, or vice versa.
- Slidev `theme-temporal` repository location is unconfirmed. Need the install path before slide authoring can start.
- Replay 2026 session date and slot are unconfirmed.
