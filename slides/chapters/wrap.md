---
layout: toc
current: wrap
---

---
layout: section
---

# Wrap-Up

---
layout: section
---

# Final Standings

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slide 35** (final leaderboard).
- This is the **moment** of the wrap. Make a big deal of it.
- **Lead-in**: "Alright, final standings. The whole morning's points are on this board. Let's see who's taking it home."
- **AhaSlides slide 35 (LEADERBOARD)**: Final standings.
  - Read the **top 3 names aloud, slowly**. Pause for applause between each.
  - "First place, name. Second, name. Third, name. Big round of applause."
  - If swag is on offer, hand it out now or tell them where to collect it.
  - Mention how close the race was: "If you missed the podium by one or two questions, that one was on slide [X]. Catch me at the booth if you want to argue."
- This celebration moment matters. People remember the workshop they won (or almost won). Don't rush it.
- **Lead-out**: "Congratulations to the top three. Before you go, let's recap what you actually did this morning, then I want one specific commitment from each of you."
- After this transition, advance to "What You Built Today."
-->

---
layout: default
---

# Essential Points (1)

The shape of the integration:

<v-clicks>

- Cross-team Temporal integration needs cross-team Nexus Endpoints. **Namespaces become tenancy boundaries with real teeth.**
- A Nexus **Service** is a typed Python class both teams import. **Operations** are the typed methods on it.
- An **Endpoint** is a routing entry the operator creates with the Temporal CLI. Caller code names only the Endpoint.
- Service and Operation are **code-level**. Endpoint and Registry are **operator-level**.

</v-clicks>

<!--
- First of five Essential Points. Synthesis, not transcript.
- **Build 1** Cross-team Temporal integration needs cross-team Nexus Endpoints. Namespaces become tenancy boundaries with real teeth.
  - The architectural reframe. Namespaces are not "groupings" anymore; they are tenancy units.
- **Build 2** A Nexus Service is a typed Python class both teams import. Operations are the typed methods on it.
  - The contract is the integration. Reasserts the workshop's thesis sentence.
- **Build 3** An Endpoint is a routing entry the operator creates with the Temporal CLI. Caller code names only the Endpoint.
  - DNS-entry mental model. The operator-side artifact.
- **Build 4** Service and Operation are code-level. Endpoint and Registry are operator-level.
  - The role split. Two halves of the responsibility.
-->

---
layout: default
---

# Essential Points (2)

The two handler shapes:

<v-clicks>

- **Synchronous handlers** run inline on the handler Worker, return a result directly, and must respond within a **10-second** per-request deadline.
- **Asynchronous handlers** return a `WorkflowHandle` to a workflow that produces the result. Up to **60 days** on Temporal Cloud.
- Choose sync when the work fits comfortably under five seconds. Choose async for everything else, especially anything that needs cancellation.
- Set all three timeouts (`schedule_to_close`, `schedule_to_start`, `start_to_close`) on every async caller. Use `WorkflowIDConflictPolicy.USE_EXISTING` for idempotent retries.

</v-clicks>

<!--
- Second Essential Points slide. Sync vs async, the design decision.
- **Build 1** Synchronous handlers run inline on the handler Worker, return a result directly, and must respond within a 10-second per-request deadline.
- **Build 2** Asynchronous handlers return a WorkflowHandle to a workflow that produces the result. Up to 60 days on Temporal Cloud.
- **Build 3** Choose sync when the work fits comfortably under five seconds. Choose async for everything else, especially anything that needs cancellation.
  - The decision rule from Chapter 3, restated.
- **Build 4** Set all three timeouts on every async caller. Use `WorkflowIDConflictPolicy.USE_EXISTING` for idempotent retries.
  - The two production gotchas of async.
-->

---
layout: default
---

# Essential Points (3)

The Update path:

<v-clicks>

- A **Workflow Update** has two stages: a **validator** that reads state and raises, then a **handler** that writes state and returns.
- A sync Nexus handler that resolves a running workflow and forwards an Update is the canonical cross-team **"tell-a-running-workflow-X"** pattern.
- A short-lived caller workflow lets reviewers route human input through the same Service contract every other caller uses.
- The handler workflow's Event History records `WorkflowExecutionUpdateAccepted` and `WorkflowExecutionUpdateCompleted` for a successful Update.

</v-clicks>

<!--
- Third Essential Points. The most reusable design pattern in the workshop.
- **Build 1** A Workflow Update has two stages: a validator that reads state and raises, then a handler that writes state and returns.
- **Build 2** A sync Nexus handler that resolves a running workflow and forwards an Update is the canonical cross-team "tell-a-running-workflow-X" pattern.
  - Memorize the pattern name. It travels.
- **Build 3** A short-lived caller workflow lets reviewers route human input through the same Service contract every other caller uses.
- **Build 4** The handler workflow's Event History records `WorkflowExecutionUpdateAccepted` and `WorkflowExecutionUpdateCompleted` for a successful Update.
-->

---
layout: default
---

# Essential Points (4)

Production reflexes:

<v-clicks>

- Sync events on the caller: **Scheduled, Completed.** Async events: **Scheduled, Started, Completed.**
- Cancellation crosses the boundary automatically. Pick `ABANDON`, `TRY_CANCEL`, `WAIT_REQUESTED`, or `WAIT_COMPLETED` based on what you need to wait for.
- `OperationError` is **permanent**. `HandlerError` is **transient** and retries with backoff.
- **5 consecutive retryable errors** on the same caller-Namespace and Endpoint pair open the circuit breaker for **60 seconds**.

</v-clicks>

<!--
- Fourth Essential Points. The recognition slides for incidents.
- **Build 1** Sync events on the caller: Scheduled, Completed. Async events: Scheduled, Started, Completed.
- **Build 2** Cancellation crosses the boundary automatically. Pick the cancel type based on what you need to wait for.
- **Build 3** OperationError is permanent. HandlerError is transient and retries with backoff.
- **Build 4** 5 consecutive retryable errors on the same caller-Namespace and Endpoint pair open the circuit breaker for 60 seconds.
  - "Most circuit breaker trips in the wild are handler workers not running." Plant the production anchor one more time on the way out the door.
-->

---
layout: default
---

# Essential Points (5)

One contract, every SDK:

<v-clicks>

- The same Nexus Service contract serves a Python handler today and a Java handler tomorrow without a Python change.
- The wire format is HTTP-based and language-agnostic, anchored by **snake_case field names** on both sides.
- Multi-language teams can each pick the SDK that fits their domain and still cooperate through Nexus.
- **The contract is the integration.**

</v-clicks>

<!--
- Fifth and final Essential Points. The polyglot punchline.
- **Build 1** The same Nexus Service contract serves a Python handler today and a Java handler tomorrow without a Python change.
- **Build 2** The wire format is HTTP-based and language-agnostic, anchored by snake_case field names on both sides.
  - The wire-level discipline that earns the "no Python change" claim.
- **Build 3** Multi-language teams can each pick the SDK that fits their domain and still cooperate through Nexus.
- **Build 4** The contract is the integration.
  - **Key point:** the workshop's thesis sentence, third exposure. First was the welcome ("What Is Nexus?"). Second was the Ch2 "Why Types Matter" close. Land it slowly. The room remembers a sentence; it doesn't remember a section.
-->

---
layout: default
---

# Patterns We Didn't Cover Today

<br>

<v-clicks>

- **In-workflow cancellation with `asyncio.create_task`**: cancel a long-running Nexus Operation from inside a workflow without cancelling the whole workflow.
- **Handler cleanup with `asyncio.shield`**: cleanup runs even when the caller cancels.
- **Multi-handler endpoints**: one Endpoint serving multiple Service handlers.
- **Cross-region and cross-account on Temporal Cloud**: Nexus crosses namespaces. Crossing regions and accounts has more considerations.

</v-clicks>

<br>

<v-click>

All three patterns are in the SDK samples repos.

</v-click>

<!--
- Honest closer. They have the foundation; here are the next three things to learn.
- **Build 1** In-workflow cancellation with asyncio.create_task.
  - The pattern for cancelling a long-running Nexus Operation from inside a workflow without cancelling the whole workflow.
  - See samples-python.
- **Build 2** Handler cleanup with asyncio.shield.
  - Making handler cleanup work even when the caller has cancelled.
  - See samples-python.
- **Build 3** Multi-handler endpoints.
  - One Endpoint serving multiple Service handlers, registry-style routing.
- **Build 4** Cross-region and cross-account on Temporal Cloud.
  - Nexus crosses namespaces. Cross-region and cross-account each have additional considerations.
  - docs.temporal.io/cloud/nexus is the entry point.
- **Build 5** All three patterns are in the SDK samples repos.
  - Direct them to the resources slide for the actual links.
- This slide tells the room "we covered the foundation, here's what's next" in a way that respects their time and their next steps.
-->

---
layout: default
---

# Where to Go Next

<br>

<v-clicks>

- **Docs**: [`docs.temporal.io/nexus`](https://docs.temporal.io/nexus)
- **Temporal Cloud-specific Nexus**: [`docs.temporal.io/cloud/nexus`](https://docs.temporal.io/cloud/nexus). Cross-account and cross-region considerations.
- **Versioning**: Service contract changes are an additive-and-rollout problem. [`docs.temporal.io/worker-versioning`](https://docs.temporal.io/worker-versioning) helps on the workflow-code side.
- **Tutorial**: [Java sync Nexus tutorial on learn.temporal.io](https://learn.temporal.io/tutorials/nexus/nexus-sync-tutorial-java/)
- **Samples**: [`samples-python/nexus`](https://github.com/temporalio/samples-python) and the equivalent in your SDK
- **Community**: `#nexus` channel in the Temporal Community Slack

</v-clicks>

<br>

<v-click>

Bring the contract you wrote today back to your team. Pick one cross-team call. Ship it through Nexus.

</v-click>

<!--
- Concrete next steps. Send them home with the right resources.
- **Build 1** **Docs**: `docs.temporal.io/nexus`
  - The reference. Conceptual overview, API specs per SDK, FAQs.
- **Build 2** **Tutorial**: Java sync Nexus tutorial on learn.temporal.io
  - The published tutorial this workshop is built on top of.
  - Worth pointing at attendees who want to do the same thing in Java.
- **Build 3** **Samples**: `samples-python/nexus` and the equivalent in your SDK
  - Working code in every SDK. The fastest way to bootstrap a new project.
  - The samples-python repo has the cleanest Python examples.
- **Build 4** **Community**: `#nexus` channel in the Temporal Community Slack
  - SDK maintainers hang out there. So do early Nexus adopters.
  - Get an invite from temporal.io/slack if they don't already have one.
- **Build 5** Bring the contract you wrote today back to your team. Pick one cross-team call. Ship it through Nexus.
  - The commitment device. Adult-learning research says specific intent dramatically improves retention.
  - "Pick one call" is the right scope: not "rewrite your platform," just one call.
-->

---
layout: section
---

# Reflection

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slides 36-38** (three slides: brainstorm, NPS, open feedback). ~2 minutes.
- This is the final interactive block. After this, the end slide stays up for Q&A.
- **Lead-in**: "Three last questions on AhaSlides. The first one is the only one that matters for you, pick something specific to try when you get back to your team."
- **AhaSlides slide 36 (brainstorm)**: "What will you try first when you get back to your team?"
  - **This is the commitment device.** Adult-learning research: specific intent dramatically improves retention.
  - Encourage everyone to type something. "Even one word. 'Refunds.' 'KYC.' 'The Go service.' Pick one."
  - Read 5-7 commitments aloud. Affirm them.
  - This is also great content for follow-up Slack/email outreach: "You said you'd try X, here's a sample for that."
- **AhaSlides slide 37 (scale 0-10)**: "Likelihood to recommend Nexus to a colleague."
  - NPS-flavored. Useful signal for course iteration.
  - Read the average aloud if it's positive: "We hit a 9.2 average, thank you, that's the best signal you can give me."
  - If lower than expected, don't dwell. Save analysis for after.
- **AhaSlides slide 38 (open-ended)**: "What still feels fuzzy?"
  - This is **the feedback gold** for the next iteration of the workshop.
  - Read 3-4 responses out loud, address each briefly. "Updates feels fuzzy? Let me give you the one-sentence summary right now."
  - For the rest, "I'll address these in a follow-up post in the #nexus channel."
- **Lead-out**: "Thank you. Final slide, Q&A is open. I'm staying right here, and I'm at the booth all afternoon."
- After this transition, advance to the end slide.
-->

---
layout: end
---

# Thank you for your time and attention

We welcome your feedback: **ahaslides.com/O8RSE**

<br>

**Mason Egger** | mason.egger@temporal.io

Questions, horror stories, or follow-ups: find me at the booth or in `#nexus` on Temporal Slack.

<!--
- Closing slide. Mirrors the 102 closer ("Thank you for your time and attention / We welcome your feedback") with feedback URL on the same slide.
- This slide stays up during Q&A. Pause. Let the room breathe. The first question takes about ten seconds.
- "Thank you for your time and attention" — say it as written. Sincere, plain.
- "We welcome your feedback" — point at the AhaSlides URL. Reflection slides 36-38 already ran above; the URL stays on screen for any late submissions.
- Mention the booth: "If your question takes more than two minutes, find me at the booth. I'm there all afternoon."
- The "horror stories" hook is the talk-register holdover for the booth invite. Use it if it lands; drop it if the room is fried.
- If there's a lull, ask: "What's the first cross-team call you're going to put through Nexus when you get back?" Their answers fuel post-workshop conversations at the booth.
-->
