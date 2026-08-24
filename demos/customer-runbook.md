# Customer Demo Run-Book — Fusion MCP

**Audience:** enterprise financial-services customer · AI infrastructure operations team
**Sponsor:** the executive who owns AI infrastructure (referred to below as *the sponsor*)
**Segment:** 25 minutes, live, inside the 60-minute session
**Driver:** Anthony Nocentino
**Environment:** lab fleet — 6 FlashArray, 2 FlashBlade, 2 sites, 3 AZs, 5 SQL Server instances
**Companion:** [`demo-script.md`](demo-script.md) — the technical walkthrough. It is a *different
demo*, not a different numbering of this one: it covers SQL Server discovery, volume correlation,
and application-consistent snapshots. Only fleet discovery and compliance & audit appear in both.

---

## How to use this file

Six steps. Each one has the exact prompt to type, what to say while it runs, what to point at in
the output, and a time box. The right-hand column of the *Demo: Run of Show* slide names the customer
ask each step answers — say that ask out loud before you type. That is what keeps this from
becoming a product tour.

All six steps are backed by workflows in `../database-sre-agent.md`. Before the meeting, work
[Pre-flight](#pre-flight) and the two open checks in
[Skills-file dependencies](#skills-file-dependencies).

**Time discipline:** if you are past 12 minutes at the end of step 3, cut step 5 (dashboard) and
go straight to step 6 (tickets). Tickets were the sponsor's first ask; the dashboard is a nice-to-have.

With step 1 pre-run and the step 2 prompt split, you should reach the end of step 3 around 9–10
minutes rather than 12–13. Spend the recovered time on step 6, not on step 4.

---

## Pre-flight

Do these the day before, not the morning of.

- [ ] `auth-config.json` has a valid API token for **every** array you intend to show
- [ ] Fusion fleet membership confirmed; note which arrays are non-members so the gap is
      intentional rather than a surprise
- [ ] `.claude/settings.json` pre-approves the Fusion MCP tools so you are not clicking through
      permission prompts on a shared screen
- [ ] Both FlashBlades reachable and returning file/object data — the FB story is the point of
      this meeting and your blog post explicitly scoped them out
- [ ] Fresh session, `CLAUDE.md` loading `database-sre-agent.md` at start
- [ ] **Run step 1 before they are in the room, in the session you will present from.** Steps 1 and 2
      re-derive the same fleet facts, so this recovers the full 2-minute box and gives step 2 topology
      already in context. Open on step 2 and scroll back: *"I established topology before we started —
      here's what it found."* That is honest. Implying it just ran is not.
- [ ] Terminal font at presentation size; window sized so full tables fit without horizontal scroll
- [ ] **Full dry run, end to end, timed.** Note the actual wall-clock of each step and adjust the
      boxes below to match reality
- [ ] Screen-record the dry run — that recording is your fallback
- [ ] Anything in the lab you do *not* want a bank to see (customer names, internal hostnames,
      Slack notifications) closed or renamed
- [ ] Decide the ITSM story for step 6: real ServiceNow/Jira sandbox, or the local mock in
      `fixtures/mock-itsm-tickets.md` (11 open tickets with statuses and blockers, enough for prompt C)

---

## Step 1 — Fleet discovery

**Their ask:** sets the FlashBlade context
**Box:** 2 minutes

### Prompt

```
You're a Database SRE agent. Your skills and workflows are defined in @database-sre-agent.md.
Establish fleet topology: list every array, its type, site, availability zone, Purity version,
fleet membership, and API access method. Include both FlashArrays and FlashBlades.
```

### Talk track while it runs

"I'm using the `@` prefix deliberately so you can see exactly what's steering this agent — it's a
Markdown file in a repo, not a hidden system prompt. Everything the agent knows about my
environment is in a file my team owns and reviews."

### What to point at

- FlashBlades appearing in the same inventory as the FlashArrays — one query, both platforms
- The two arrays that are **not** fleet members, and the note explaining that fleet-routed
  operations can't reach them. This is the moment to say: *the agent tells you where its own
  visibility ends.* For a bank, an honest tool beats a confident one.

### Do not

Do not linger on Purity versions here — that's step 3's material.

---

## Step 2 — Compliance & audit

**Their ask:** "Make sure replication is set up"
**Box:** 6 minutes — this is the centerpiece, give it room

### Prompt A — coverage

```
Produce the "Compliance & Audit" report.
```

### Prompt B — the plan

```
Now the remediation plan for those findings.
```

**Why two prompts.** The single-prompt version runs ~35 tool calls before a character of output appears,
which is a long silence on a shared screen. Splitting it lands the coverage tables at roughly 40% of
the elapsed time and gives you a natural beat to deliver the line below while the plan runs.

**The trade:** it slightly softens the "notice how short that prompt was" point. Prompt A is still two
words, and step 3 carries the same story, so this is worth it — but if you are on time and want the
single-prompt version for effect, just don't type Prompt B and the plan comes with the report.

### Talk track while it runs

"Notice how short that prompt was. The agent already has my fleet topology, my SLA tiers, my
retention policy, my encryption requirements, and my HA placement rules from the skills file. I'm
not describing what good looks like — I encoded that once, and now it's a two-word request. That's
roughly fifty API calls happening right now. Doing this by hand across six arrays is an hour or
two of careful, brittle work — the kind of work that gets skipped when everything looks fine."

### What to point at, in this order

1. **Protection group coverage table** — walk the rows top to bottom
2. **The DR instance with no protection group.** Stop here and tell the story properly:
   > "This instance migrated to the DR array. The VM moved, the old volumes were destroyed, and
   > nobody created a protection group on the destination. No snapshots. No replication. And no
   > alert — because nothing had failed. The DR environment itself had no DR. We'd have found out
   > when we needed to recover."
3. **The empty-shell protection group** — exists by name, contains zero volumes, both schedules
   disabled. Looks protected on a report. Isn't. Say: *"this is the one that would pass a
   spreadsheet audit."*
4. **Unencrypted replication links** — "in a regulated environment this isn't a
   misconfiguration, it's a fleet-wide finding"
5. **Databases at risk, ranked** — the payoff. Findings expressed in database names, not volume
   serial numbers, because the tags carry the mapping.

### The line that lands

"The agent didn't ask 'are there any alerts?' It asked 'does every instance actually meet policy?'
In a regulated environment those are two completely different questions."

### If they interrupt with "how do we know it's right?"

Good sign — that's the security-minded question. Answer: every tool call and REST response is in
the transcript, the server is open source, and the policy it's checking against is a file they can
read and diff. Offer to scroll the raw tool output for any single finding they pick.

---

## Step 3 — Config drift & security posture

**Their ask:** config drift / security posture
**Box:** 3 minutes

### Prompt

```
Now show me configuration drift and security posture across the fleet: Purity version consistency,
replication encryption status, fleet link health, and SafeMode configuration. Rank by risk to a
regulated environment.
```

> **Certificate expiry is deliberately not in that prompt.** This MCP build exposes no `/certificates`
> endpoint, so asking for it produces a dead-end call and a paragraph of explanation. Two options —
> pick one before the dry run, don't let it happen live:
>
> 1. **Leave it out** (the prompt above). Fastest, and nothing is lost.
> 2. **Ask for it on purpose** as a trust moment: *"watch what it does when I ask for something the API
>    can't give it."* The agent reports the control as unverified and names the missing endpoint rather
>    than inventing a pass. For a bank that is worth more than one more green check — but only if you
>    frame it as intentional.

### What to point at

- Purity skew across arrays in the same availability zone
- The degraded fleet management link — and that alert queries are timing out through the gateway,
  so that array's true state is unknown without querying it directly
- SafeMode off on all six FlashArrays while data-at-rest encryption is on everywhere — the capability
  is licensed and understood, it just wasn't applied. Nothing is broken yet, and that's the point.
- SafeMode / encryption posture

### Talk track

"This is the check you'd normally do quarterly, by hand, in a spreadsheet. Here it's the same two
prompts every time, so it can run weekly — or on a schedule with no human in the loop at all."

### Bridge to the next step

"So that's observing and auditing. Let's talk about doing something."

---

## Step 4 — Preset creation

**Their ask:** templates for provisioning
**Box:** 4 minutes

> **Verify this works in dry run.** Preset creation is a Fusion MCP guided action. Confirm the
> tool is exposed in your build and that the agent will *propose* rather than *apply*.

### Prompt

```
Look at how aen-sql-25-a is currently provisioned and protected. Draft a Fusion preset that
captures that configuration as our Tier 1 SQL Server standard — QoS, protection group membership,
snapshot schedule, retention, and replication. Show me the preset definition before creating
anything.
```

### What to point at

- The agent **reverse-engineers the standard from what's deployed** rather than asking you to write
  it from scratch
- The preview step: nothing changed yet. This is the supervised model from the governance slide,
  demonstrated instead of asserted.
- Then: "and once this preset exists, every future workload deployed from it is compliant by
  construction — the drift check in step 3 has much less to find"

### Optional follow-up if time allows

```
Which existing workloads deviate from that preset?
```

That closes the loop between provisioning standards and drift detection in one breath.

---

## Step 5 — Dashboard build (cut this first if you're behind)

**Their ask:** metrics into a dashboard / their monitoring platform has no FlashBlade support
**Box:** 4 minutes

### Prompt

```
Pull capacity and performance metrics for both FlashBlades — used vs. total, data reduction,
per-filesystem space consumption, and throughput. Generate a single-file HTML dashboard I can open
in a browser, with the arrays as cards and the top filesystems by size as a bar chart.
```

### Talk track

"Your team is trying to get FlashBlade metrics into your monitoring platform and it doesn't support
FlashBlade. This is a different answer to that problem: you don't need the monitoring vendor to
add support, because your agent can build the view you actually want from the same APIs."

### The honest caveat — say it, don't hide it

"For a persistent, alerting, on-call dashboard you'd wire the Pure1 metrics endpoint into your
existing observability stack. What this is good for is the view nobody built yet — the one-off
question at 2am, or the weekly report someone is currently assembling by hand."

That distinction is what keeps the room's trust. Do not let them think an agent replaces
monitoring infrastructure.

---

## Step 6 — Ticket the findings

**Their ask:** "Ask about tickets" — the sponsor's very first bullet
**Box:** 5 minutes

> Needs a second MCP server connected in the same session. Real ITSM sandbox if you can get one;
> a local mock is acceptable and still makes the point. Decide in pre-flight, not live.
>
> Fallback mock is `fixtures/mock-itsm-tickets.md`, wired into the skills file under *Change Management &
> Ticketing → Demo / Offline Ticket Store*. It carries the DR-array tickets and their blockers, so
> prompt C answers correctly with no connector at all. Say out loud that it's a fixture.

### Prompt A — produce the plan

```
Produce a prioritized remediation plan for everything found in the compliance and drift reports.
Order by severity and effort, and include risk and change type for each item.
```

### Prompt B — file the work

```
File a ticket for every CRITICAL and HIGH finding. Include the affected instance, the finding, the
recommended action, and the change type. Show me each ticket before you create it.
```

### Prompt C — close the loop

```
What tickets are open against the DR array right now, and what's blocking them?
```

### What to point at

- **Two MCP servers, one session, one conversation.** The agent is reading storage state from
  Fusion and writing work into ITSM without you switching tools or writing glue code.
- The preview-before-create step again — reinforcing supervised action for the third time
- Prompt C answers the sponsor's ask in the *other* direction: not just "create tickets from findings" but
  "tell me about my tickets"
- Then the forward look: "add your CMDB, your runbooks, your change system as MCP servers and this
  same agent operates across all of them. That's what 'operationalize' looks like."

### Land the segment here

"Six steps, all natural language, all against a live fleet, all governed by a policy file your team
owns. Nothing you saw required custom code from us."

---

## Skills-file dependencies

Steps 1–3 rely on workflows that have been in `../database-sre-agent.md` since the original demo.
Steps 4–6 rely on four sections added 2026-08-19: *Provisioning Standards* and *Presets* under
Proactive & Automation, *Reporting & Dashboards* after Output Format, and *Change Management &
Ticketing* after Compliance & Audit. All four are in the policy file now — the changelog at the top
of that file tracks them.

**Two things still need a human check before the dry run:**

1. **Tier values.** The provisioning tier table asserts QoS limits and retention targets. Verify each
   against how the lab is actually built and correct any that don't match.
2. **The `//C` snapshot-target array.** It reads as a 49% snapshot-share anomaly because the policy
   file doesn't know it is a snapshot target. This was flagged in the blog post. Fix it before
   showing a bank a false positive — it is a small edit and exactly the kind of thing they will poke at.

---

## Fallbacks

| Failure | Response |
|---|---|
| Fleet link down / array unreachable | Keep going and name it. A tool that reports its own blind spots is a feature — you already have language for this in step 1. |
| Live environment unusable | Switch to the dry-run recording. Say plainly: "this is a recording from yesterday against the same fleet." Never pretend a recording is live. |
| Model returns a wrong number | Correct it out loud, immediately, and show the raw tool output. Credibility survives a wrong number; it does not survive glossing over one. |
| ITSM connector fails | Fall back to prompt A only — the remediation plan still lands, and say the ticket integration is a two-line config change you'll show them offline. |
| Running long | Cut step 5. Then compress step 4 to the preview only. Never cut step 6. |
| Someone asks about unreleased MCP capability | Do not speculate. Confirm approved roadmap language with the account team beforehand and use exactly that wording. |

---

## Questions to expect from this room

**"Where does the model run?"**
Their choice. The MCP servers don't care — Fusion MCP is local and talks to whatever client they
point at it, including their own models behind their API gateway. Expect this question early.

**"What stops it from deleting something?"**
Three layers: the API token's role, the supervised preview step, and the policy in the skills file.
And it's open source, so their security team can verify all three rather than take our word for it.

**"Can it run without a human?"**
Yes, technically, for read-only workflows today — the audit and drift reports are safe to schedule.
Actions are where you'd want policy gating first. This is the maturity-path slide; don't oversell.

**"Who maintains the skills file?"**
Their AI infrastructure operations team, which is the answer the sponsor wants — storage ops isn't
taking this over. Offer to co-author the first version during a proof of concept.

**"What about agent memory / vector workloads?"**
Pull this thread hard if it comes up. It's the largest opportunity in the account and the real
"more than a storage company" proof. Have the StackOverflow embeddings work ready to reference.

---

## Note on sources

Built from the workflow list in the `mcp-server-demos` README, the two prompts published in the
July 17 blog post, and the run-of-show on the deck's demo slide. I could not read `demo-script.md`
directly — GitHub blocks automated source access — so **reconcile the exact prompt wording against
your own `demo-script.md` before the dry run.** Prompts for steps 4, 5, and 6 are new and have not been
run anywhere; treat them as drafts to test, not as known-good.
