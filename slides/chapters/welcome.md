---
layout: default
---

# About Me

### Mason Egger - mason@temporal.io
Senior Solutions Architect, Commercial

- Previously on the Education team
  - Wrote all the Java courses, most of the Python ones, and Ruby 101
- PyTexas Foundation President, Conference Chair, Meetup Organizers
- PSF Fellow

---
layout: default
---

# Facilities

- Wifi
- Restrooms
- Food

---
layout: default
---

# What You'll Build Today

A real-world payments scenario, running on Temporal.

<v-clicks>

- A **Payments** team with a `PaymentProcessingWorkflow`
- A **Compliance** team with risk checks and human review
- One **Nexus Endpoint** routing calls between them, across namespace boundaries
- A second handler in **Java**, hitting the same Service contract from a Python caller

</v-clicks>

<br>

<v-click>

You'll write Python today. The Temporal concepts transfer to every other SDK.

</v-click>

<!--
- A real-world payments scenario, running on Temporal.
  - The scenario is intentionally narrow: validate a transaction, run compliance, execute the payment
  - Every Temporal user has a moral equivalent of this in their codebase
- **Build 1 -** A Payments team with a `PaymentProcessingWorkflow`
  - Owns validate and execute
  - Today this team starts as the only team and ends with a clean boundary
- **Build 2 -** A Compliance team with risk checks and human review
  - Today they're co-tenants of one Worker. By 11:00 they own their own namespace.
  - Their work includes both an automated rule check **and** a human-in-the-loop reviewer path
- **Build 3 -** One Nexus Endpoint routing calls between them, across namespace boundaries
  - This is the moment the architecture changes shape
  - The Endpoint is the public DNS-equivalent for cross-team Temporal calls
- **Build 4 -** A second handler in **Java**, hitting the same Service contract from a Python caller
  - Demo only, not an exercise. About 5 minutes near the end.
  - The point is to feel the contract is universal, regardless of SDK
- **Build 5 -** You'll write Python today. The Temporal concepts transfer to every other SDK.
  - Same Service / Operation / Endpoint vocabulary in Go, TypeScript, Java, .NET
  - APIs differ at the surface; the concepts are identical
-->

---
layout: default
---

# Agenda

| Time          | Block                                                                  |
| :------------ | :--------------------------------------------------------------------- |
| 9:00 - 9:45   | Welcome, **Ch 1**: Why Nexus, **Ch 2**: Service contract               |
| 9:45 - 10:00  | **Break**                                                              |
| 10:00 - 11:15 | **Ch 3 - 5**: Sync handler, caller workflow, async                     |
| 11:15 - 11:30 | **Halftime + Break**                                                   |
| 11:30 - 11:55 | **Ch 6**: Updates Through Nexus                                        |
| 11:55 - 12:15 | **Ch 7**: Cancellation, errors, the circuit breaker                    |
| 12:15 - 12:30 | Polyglot demo, wrap, and Q&A                                           |

<style>
.slidev-layout table { font-size: 1.15rem; }
.slidev-layout th,
.slidev-layout td { padding: 0.35rem 0.7rem; }
</style>

---
layout: default
---

# Three Environments

You'll move between three browser tabs all day.

<br>

<div class="flex items-start gap-8">

<div class="flex-1">

| Surface       | What lives there         | How to access |
| :------------ | :----------------------- | --- |
| **Instruqt**  | Hands-on coding environment | https://t.mp/replay26-nexus |
| **AhaSlides** | Interactive exercises | https://ahaslides.com/NEXUSWS |
| **Slidev**    | Live view of slides (Optional) | |

<br>

</div>

<img src="/ahaslides-qrcode.png" alt="AhaSlides QR code" class="w-48 h-48 shrink-0" />

</div>

---
layout: default
---

# What I Assume You Know

You're comfortable with Temporal's core model and the Python programming language.  

<v-clicks>

- **Workflows**, **Activities**, and **Workers**
- **Signals**, **Queries**, and **Updates**
- Temporal timeouts including **start_to_close**, **schedule_to_close**, and **schedule_to_start**
- The Temporal Web UI and Event History

</v-clicks>

<br>

<v-click>

Brand new to **Nexus**. That's the goal of today.

</v-click>

<!--
- You're comfortable with Temporal's core model and the Python programming language.
- **Build 1 -** Workflows, Activities, and Workers.
  - Workflows = durable orchestrators. Activities = work that touches the outside world. Workers = the processes hosting both.
- **Build 2 -** Signals, Queries, and Updates.
  - Updates is the load-bearing one for today.
  - Signals are write-only from outside. Queries are read-only. Updates are write-with-return-value.
- **Build 3 -** Temporal timeouts: start_to_close, schedule_to_close, and schedule_to_start.
  - The room needs to recognize these names; we'll use all three on async Nexus calls.
- **Build 4 -** The Temporal Web UI and Event History.
  - We read Event History live more than once today.
- **Build 5 -** Brand new to Nexus. That's the goal of today.

## Teaching notes

- Python comfort assumed via the intro line ("the Python programming language"); the bullet for it lived on an earlier draft and has been pulled because the intro covers it. We're not testing Python expertise; we're testing comfort with `await` and `async`.
-->

---
layout: default
---

# Asking Questions & Getting Help

<v-clicks depth="3">

- Have a question? Just raise your hand
  - I'll come to a stopping point and answer
  - Would rather you ask in the moment so the question is in context
  - **I do reserve the right to go "Great question! Find me later and let's discuss."**
- Getting help during the exercises
  - Raise your hand, one of the TAs will come by and help
  - You can also look in the Solution tab for the answer
  
</v-clicks>

<!-- 
- **Build 1 -** Have a question? Just raise your hand
- **Build 2 -** I'll come to a stopping point and answer
- **Build 3 -** Would rather you ask in the moment so the question is in context
- **Build 4 -** **I do reserve the right to go "Great question! Find me later and let's discuss.**
  - Sometimes your question will be answered later
  - Sometimes it's beyond the scope of the workshop and will take off off track
- **Build 5 -** Getting help during the exercises
- **Build 6 -** Raise your hand, one of the TAs will come by and help
- **Build 7 -** You can also look in the Solution tab for the answer
-->

---
layout: default
---

# During this workshop, you will

<v-clicks>

- **Distinguish** when to use Nexus versus Child Workflows, Activities, and bespoke gateways for cross-team integration
- **Name** the four Nexus building blocks: Service, Operation, Endpoint, and Registry
- **Define** a typed Nexus Service contract that both teams import
- **Implement** synchronous and asynchronous Nexus Operation handlers
- **Invoke** a Nexus Operation from a caller Workflow across a Namespace boundary
- **Propagate** a Workflow Update through Nexus for human-in-the-loop review
- **Configure** Nexus Operations for cancellation, error handling, and the circuit breaker
- **Recognize** the same Service contract serving handlers in multiple SDKs

</v-clicks>

<!--
- **Build 1 -** **Distinguish** when to use Nexus versus Child Workflows, Activities, and bespoke gateways for cross-team integration
- **Build 2 -** **Name** the four Nexus building blocks: Service, Operation, Endpoint, and Registry
- **Build 3 -** **Define** a typed Nexus Service contract that both teams import
- **Build 4 -** **Implement** synchronous and asynchronous Nexus Operation handlers
- **Build 5 -** **Invoke** a Nexus Operation from a caller Workflow across a Namespace boundary
- **Build 6 -** **Propagate** a Workflow Update through Nexus for human-in-the-loop review
- **Build 7 -** **Configure** Nexus Operations for cancellation, error handling, and the circuit breaker
- **Build 8 -** **Recognize** the same Service contract serving handlers in multiple SDKs
-->



---
layout: section
---

# Warmup

ahaslides.com/NEXUSWS

<!--
- "Alright, while you're settling in, let's get a feel for the room. Hop over to your AhaSlides tab. Two quick questions."
- AhaSlides word cloud: "One word for cross-team Temporal integration today."
- AhaSlides scale 1-5: "How comfortable are you with Temporal Workflows, Activities, and Updates?"
- "Cool, that gives me what I need to pace this. Back to the main screen, let's actually look at what we're going to build."
-->
