---
layout: default
---

# About Me

<br>

### Mason Egger
Senior Solutions Architect, **Temporal**

- Previously on the Education team at Temporal
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

<!-- 
  - Wifi
    - Get info and put on slide
  - Restrooms
    - Locate
  - Food
    - Locate
-->

---
layout: default
---

# What You'll Build Today

<br>

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
- **Build 1** A Payments team with a `PaymentProcessingWorkflow`
  - Owns validate and execute
  - Today this team starts as the only team and ends with a clean boundary
- **Build 2** A Compliance team with risk checks and human review
  - Today they're co-tenants of one Worker. By 11:00 they own their own namespace.
  - Their work includes both an automated rule check **and** a human-in-the-loop reviewer path
- **Build 3** One Nexus Endpoint routing calls between them, across namespace boundaries
  - This is the moment the architecture changes shape
  - The Endpoint is the public DNS-equivalent for cross-team Temporal calls
- **Build 4** A second handler in **Java**, hitting the same Service contract from a Python caller
  - Demo only, not an exercise. About 5 minutes near the end.
  - The point is to feel the contract is universal, regardless of SDK
- **Build 5** You'll write Python today. The Temporal concepts transfer to every other SDK.
  - Same Service / Operation / Endpoint vocabulary in Go, TypeScript, Java, .NET
  - APIs differ at the surface; the concepts are identical
- The "two teams" framing is what makes Nexus click. Sell that hard.
-->

---
layout: default
---

# How Today Runs

<br>

| Time          | Block                                                                  |
| :------------ | :--------------------------------------------------------------------- |
| 9:00 - 9:25   | **Ch 1**: Why Nexus, run the monolith                                  |
| 9:25 - 11:00  | **Ch 2 - 4**: Service contract, sync handler, caller workflow          |
| 11:00 - 11:30 | **Break**                                                              |
| 11:30 - 11:50 | **Ch 5**: Async Operations                                             |
| 11:50 - 12:15 | **Ch 6**: Updates Through Nexus                                        |
| 12:15 - 12:35 | **Ch 7**: Cancellation, errors, the circuit breaker                    |
| 12:35 - 12:50 | Polyglot demo, wrap, and Q&A                                           |

<!--
- Map of the whole day. Show, don't dwell.
- 9:00 - 9:25 | **Ch 1**: Why Nexus, run the monolith
  - Easiest chapter. Sets the why. Quiz block on AhaSlides at the end.
- 9:25 - 11:00 | **Ch 2 - 4**: Service contract, sync handler, caller workflow
  - The real meat of the morning. Three chapters, one continuous storyline: contract → handler → caller.
- 11:00 - 11:30 | **Break**
  - Halftime leaderboard right before. Encourage screenshots, drives the energy back into the room after the break.
- 11:30 - 11:50 | **Ch 5**: Async Operations
  - Shortest chapter. Convert sync handler to workflow-backed async.
- 11:50 - 12:15 | **Ch 6**: Updates Through Nexus
  - Highest-friction chapter. Plan to walk the room.
- 12:15 - 12:35 | **Ch 7**: Cancellation, errors, the circuit breaker
  - Production readiness. Mostly observation, light coding.
- 12:35 - 12:50 | Polyglot demo, wrap, and Q&A
  - Java handler runs the same Service. Then Q&A and final leaderboard.
- The break exists because brains hit a ceiling at ~90 minutes of focused new content. Don't skip it.
-->

---
layout: default
---

# Three Environments

<br>

You'll move between three browser tabs all day.

<br>

| Surface       | What lives there         | How to access
| :------------ | :----------------------- | ---
| **Instruqt**  | Hands-on coding environment |
| **AhaSlides** | Interactive exercises             |
| **Slidev**    | Live view of slides (Optional)      |

<br>

**Join AhaSlides now**: `ahaslides.com/O8RSE`

<!--
- You'll move between three browser tabs all day.
  - Tell people to open all three tabs now. Browser tab fumbling is the #1 thing that drops energy.
- **Slidev** | Lecture content, the screen I'm presenting from
  - "When I'm talking, look at my screen, not your laptop."
- **AhaSlides** | Polls, warmups, knowledge checks, the leaderboard
  - This is the interactive layer. They join once and stay there for 3.5 hours.
  - Same browser tab the whole time. Their score persists across all 38 AhaSlides slides.
- **Instruqt** | Your hands-on coding environment, two containers, terminals, UI
  - Two containers (`payments`, `compliance`) plus the Temporal Web UI tab
  - Hot Start should already have provisioned everyone's sandbox
- **Join AhaSlides now**: `ahaslides.com/O8RSE`
  - Hold here. Look around the room. Wait until you see most laptops have AhaSlides on screen before moving on.
  - "Anybody not on AhaSlides yet? Raise a hand."
- Logistics matter. People get confused if they don't know what to look at. Spend the time here, it pays off later.
-->

---
layout: default
---

# Asking Questions & Getting Help

<v-clicks>
- Have a question? Just raise your hand
  - I'll come to a stopping point and answer
  - Would rather you ask in the moment so the question is in context
  - **I do reserve the right to go "Great question! Find me later and let's discuss.**
    - Sometimes your question will be answered later
    - Sometimes it's beyond the scope of the workshop and will take off off track
- Getting help during the exercises
  - Raise your hand
  - One of the TAs will come by and help
  - You can also look in the Solution tab for the answer
</v-clicks>

<!-- 
- Have a question? Just raise your hand
  - I'll come to a stopping point and answer
  - Would rather you ask in the moment so the question is in context
  - **I do reserve the right to go "Great question! Find me later and let's discuss.**
    - Sometimes your question will be answered later
    - Sometimes it's beyond the scope of the workshop and will take off off track
- Getting help during the exercises
  - Raise your hand
  - One of the TAs will come by and help
  - You can also look in the Solution tab for the answer
-->

---
layout: default
---

# A Preview, Before We Begin

<br>

Open your **Instruqt** tab. The first card is the **Topology Sandbox**.

<br>

Stop a service. Watch what happens. Start it again. Watch what happens.

<!--
- Brochure for the journey, not the journey itself. They have not built any of this yet.
  - This is the first time we send the room to Instruqt today. Make sure they actually open the tab. Look around the room.
  - "You will see three services and an event log on the right. Do not worry about the labels yet. We will name them in a few minutes."
- Demo script (~90 seconds). Their hands, their tab. You can mirror your screen if useful, but the goal is them clicking, not you presenting.
  - "Click Stop on Compliance Worker. Watch the in-flight payments. They turn yellow. They do not fail."
  - "Click Start. They resume from where they were."
  - "Now do the same to Nexus Endpoint. Same story."
  - Pause. Let the room watch their own screens for a beat.
- Land the punchline last. "Look at the `Lost` counter. It is still zero. That is the property worth the rest of the morning."
- Off-ramp before energy fades. "Two minutes is enough. Come back to the slides when you are ready."
- After this beat, advance to "What Is Nexus?" The vocabulary lands harder when the picture is already in their head.
-->

---
layout: default
---

# What Is Nexus?

<br>

A typed, durable, namespace-crossing call between two Temporal applications.

<v-clicks>

- Built into the Temporal Platform. Public Preview at Replay 2024, **GA at Replay 2025** on Temporal Cloud and self-hosted.
- The contract lives in your SDK's native types. The runtime handles the wire, the routing, retries, cancellation, and durability.
- Built on the open **Nexus RPC** protocol at `github.com/nexus-rpc/api`. Cross-language by design, not by translation.
- In production at Netflix, Miro, and Duolingo.

</v-clicks>

<br>

<v-click>

**The contract is the integration.**

</v-click>

<v-click>

Maxim Fateev's one-liner: *"RPC service that guarantees delivery of requests, and any operation can be as long as needed."*

</v-click>

<!--
- A typed, durable, namespace-crossing call between two Temporal applications.
  - One sentence answer to "what is this thing." Memorize this framing.
  - The four words to land: typed, durable, namespace-crossing.
- **Build 1** Built into the Temporal Platform. Public Preview at Replay 2024, **GA at Replay 2025** on Temporal Cloud and self-hosted.
  - This is not a beta. It is shipping product across SDKs and across Temporal Cloud + self-hosted.
  - The room should hear "GA, all SDKs, both deployment models" and stop wondering if they should bet on it.
- **Build 2** The contract is in your SDK's native types. The runtime handles the wire, the routing, retries, cancellation, and durability.
  - The contract = code, no IDL files (unless you want one via nexus-rpc-gen).
  - Everything past the contract is platform: retries, durability, cancellation propagation.
- **Build 3** Built on the open Nexus RPC protocol at github.com/nexus-rpc/api. Cross-language by design, not by translation.
  - The wire format is HTTP-based and language-agnostic.
  - The wire format is HTTP-based and language-agnostic, so the same contract holds across Python, Go, Java, TypeScript, and .NET.
- **Build 4** In production at Netflix, Miro, and Duolingo.
  - Netflix: each team owns a Namespace and exposes capabilities to other teams.
  - Miro: cross-region data migration over days/weeks across regions with no direct network connectivity.
  - Duolingo: self-service infrastructure case study.
  - This is the credibility moment. Three names the room recognizes.
- **Build 5** **The contract is the integration.**
  - **Key point:** plant the thesis here. It returns at the Ch2 "Why Types Matter" close (the pivot) and again at the wrap.
  - That sentence is the spine of today. Say it once, slowly, then advance.
- **Build 6** Maxim's one-liner.
  - "RPC service that guarantees delivery of requests, and any operation can be as long as needed."
  - Quote it as a quote. Pause after.
- This slide is the answer to the implicit question every senior engineer in the room has: "is this production-ready, and should I bet a quarter of my morning on it?" Answer is yes.
-->



---
layout: default
---

# What I Assume You Know

<br>

You're comfortable with Temporal's core model.

If any of these feel rusty, especially **Updates**, find me at the break and I'll walk you through it.

<v-clicks>

- **Workflows**, **Activities**, and **Workers**
- **Signals**, **Queries**, and **Updates**
- The Temporal Web UI and Event History
- A bit of Python, enough to follow `async def`

</v-clicks>

<br>

<v-click>

Brand new to **Nexus**. That's the goal of today.

</v-click>

<!--
- You're comfortable with Temporal's core model.
  - Calibration moment. Set the floor of what we'll assume.
  - The AhaSlides 1-to-5 scale right before this gives the real read on the room.
- **Build 1** **Workflows**, **Activities**, and **Workers**
  - Workflows = durable orchestrators. Activities = work that touches the outside world. Workers = the processes hosting both.
  - If anyone here is shaky on these, flag for a side conversation at the break.
- **Build 2** **Signals**, **Queries**, and **Updates**
  - Updates is the load-bearing one for today.
  - Signals are write-only from outside. Queries are read-only. Updates are write-with-return-value.
- **Build 3** The Temporal Web UI and Event History
  - We read Event History live more than once today. The room needs to know how to navigate.
- **Build 4** A bit of Python, enough to follow `async def`
  - We're not testing Python expertise. We're testing comfort with the words `await` and `async`.
- **Build 5** Brand new to **Nexus**. That's the goal of today.
  - This is the punchline. Anchors why they showed up.
- If the room is shaky, slow down on the foundational material. We have buffer in the schedule.
-->

---
layout: default
---

# During this workshop, you will

<v-clicks>

- **Distinguish** when to use Nexus versus other Temporal integration patterns
- **Name** the four Nexus building blocks: Service, Operation, Endpoint, and Registry
- **Define** a typed Nexus Service contract that both teams import
- **Implement** synchronous and asynchronous Nexus Operation handlers
- **Invoke** a Nexus Operation from a caller Workflow across a Namespace boundary
- **Propagate** a Workflow Update through Nexus for human-in-the-loop review
- **Configure** Nexus Operations for cancellation, error handling, and the circuit breaker
- **Recognize** the same Service contract serving handlers in multiple SDKs

</v-clicks>

<!--
- The contract with the room. One bullet per build, verb-led. Read each, then advance.
- **Build 1** **Distinguish** when to use Nexus versus other Temporal integration patterns
  - The framing payload of Chapter 1.
- **Build 2** **Name** the four Nexus building blocks: Service, Operation, Endpoint, and Registry
  - Vocabulary that the rest of the morning runs on.
- **Build 3** **Define** a typed Nexus Service contract that both teams import
  - The Chapter 2 outcome. Code-level shape.
- **Build 4** **Implement** synchronous and asynchronous Nexus Operation handlers
  - Chapters 3 and 5 together.
- **Build 5** **Invoke** a Nexus Operation from a caller Workflow across a Namespace boundary
  - The Chapter 4 punchline. The morning's "shipped" moment.
- **Build 6** **Propagate** a Workflow Update through Nexus for human-in-the-loop review
  - Chapter 6's pattern. The most reusable one in production.
- **Build 7** **Configure** Nexus Operations for cancellation, error handling, and the circuit breaker
  - Chapter 7. Production reflexes.
- **Build 8** **Recognize** the same Service contract serving handlers in multiple SDKs
  - The polyglot demo's payoff.
- These are the bullets the Essential Points slides at the wrap mirror. Three exposures: outcomes, lecture, wrap synthesis.
-->



---
layout: section
---

# Warmup

ahaslides.com/O8RSE

<!--
- **Switch to AhaSlides slides 2-3** (warmup pair, ~1 minute total).
- This is the **first interactive moment**. Set the tone: "your laptops are part of this workshop, not just a screen to read."
- **Lead-in**: "Alright, while you're settling in, let's get a feel for the room. Hop over to your AhaSlides tab. Two quick questions."
- **AhaSlides slide 2 (word cloud)**: "One word for cross-team Temporal integration today."
  - Read 3-5 responses aloud. Riff on them.
  - Listen for words like "painful," "hacky," "HTTP," "tickets", those become reference points throughout the morning.
  - If responses skew "smooth/easy," joke that you might be in the wrong room.
- **AhaSlides slide 3 (scale 1-5)**: "How comfortable are you with Temporal Workflows, Activities, and Updates?"
  - This is your **calibration**. If average is below 3, slow down on foundational material and unpack Updates more carefully.
  - If average is 4+, you can move faster through familiar material.
  - Read the average aloud: "Looks like we're a 3.8 average, solid mid-room comfort. We'll move at a confident pace."
- AhaSlides slide 5 (Pattern Roulette spinner) is **skipped during presentation** (set in AhaSlides). It stays in the editor but won't show up in the live show.
- **Lead-out**: "Cool, that gives me what I need to pace this. Back to the main screen, let's actually look at what we're going to build."
- After this transition, advance to the chapter divider for Chapter 1.
-->
