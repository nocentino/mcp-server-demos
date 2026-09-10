---
applyTo: "**"
description: "Change Management & Ticketing SOP: severity scale, ticket format, auto-filing rules, and rules for existing tickets"
---

# Skill: Change Management & Ticketing

**When this applies**: findings from a Compliance & Audit or incident report need to become tracked work. When a ticketing MCP server is connected in the session, the agent files and queries tickets directly; the [Remediation Plan](02-compliance-audit.md#remediation-plan) is the input, tickets are the output.

## Thresholds — Severity Scale

Severity drives both remediation priority and whether a ticket is filed automatically. Assign it from the finding, not from whether anything is currently alerting.

| Severity | Definition | Examples |
|---|---|---|
| `CRITICAL` | A production or DR database is unrecoverable, or its RPO cannot be met at all | No Protection Group; PG with zero volumes or disabled schedules; no replication to DR; snapshots not replicating; a database backup bucket with no versioning and no Object Lock; a backup landing zone with no snapshots and no replication; **a SQL backup landing zone with no replica link to the DR site** |
| `HIGH` | Recoverability or compliance is materially degraded, but some protection exists | Unencrypted replication link; retention below the policy floor; cadence below tier RPO; cluster pair in the same zone; DR instance in a production zone; SafeMode off on a backup landing zone; a replica link stale beyond its RPO budget; a publicly accessible bucket |
| `MEDIUM` | Posture and drift issues with no current data-loss exposure | Purity version skew within a zone; certificate approaching expiry; degraded fleet-management link; capacity above the escalate threshold |
| `LOW` | Hygiene and classification gaps | Missing or incomplete tags; unclassified volumes; unzoned arrays; naming convention violations |

A finding whose true state is **Unknown — query failed** is not a pass and is not `LOW`. File it at the severity the worst plausible state would carry, and say in the ticket that the state is unverified.

## Ticket Format

Every ticket the agent files carries all of these fields. A ticket missing any of them is not ready to create.

| Field | Content |
|---|---|
| Title | `{severity}: {affected resource} — {finding in one line}` |
| Affected Resource | SQL Server instance, array, volume, or Protection Group by exact name. One primary resource per ticket. |
| Finding | What is wrong, stated as observed state vs. required state, with the policy or tier standard it violates. |
| Evidence | The tool calls and field values the finding rests on, so a reviewer can reproduce it without rerunning the agent. |
| Recommended Action | The concrete remediation step, specific enough to execute — target names, schedules, and retention values included. |
| Severity | `CRITICAL` / `HIGH` / `MEDIUM` / `LOW` per the scale above. |
| Effort | `Low` / `Medium` / `High` per the Remediation Plan definitions. |
| Risk | `None` / `Low` / `Medium` / `High` per the Remediation Plan definitions. |
| Change Type | `Emergency` / `Planned` / `Routine` per the Remediation Plan definitions. |
| Owning Team | Storage, DBA, Network, App, or Procurement — per [Escalation](06-incident-response.md#escalation). |
| Source | The report and Remediation Plan priority number the ticket came from, so the plan and the ticket queue stay reconcilable. |

## Decision rules — what gets ticketed automatically

| Severity | Behavior |
|---|---|
| `CRITICAL` | Ticket filed automatically. `Emergency` change type; page the owning team in the ticket body. |
| `HIGH` | Ticket filed automatically. `Planned` unless the finding leaves a production database with no recoverable copy, in which case escalate to `Emergency`. |
| `MEDIUM` | **Human decision required.** Present the proposed tickets as a list and ask which to file. Do not file unasked. |
| `LOW` | No ticket. Report in a consolidated hygiene list; file only on explicit request, and batch by array or instance rather than one ticket per tag. |

"Automatically" means without a separate prompt for each finding — it does not mean without preview. Present every ticket in full before creating it, in one batch, and create only after approval. This is the same supervised-action rule as [Guided Runbooks](06-incident-response.md#guided-runbooks) and it applies to ticket creation regardless of severity.

## Hard boundaries — rules for existing tickets

- **Never close, reprioritize, reassign, or change the severity of an existing ticket without explicit approval.** Propose the change and the reason; let a human make it. This holds even when the underlying finding is verifiably remediated — verify, report, and recommend closure, then stop.
- Before filing, query open tickets for the affected resource and finding. If one already exists, add a comment with the current observed state instead of filing a duplicate, and say in the report that you did so.
- One finding per ticket, one primary resource per ticket. Do not bundle findings across instances or arrays; a bundled ticket cannot be closed cleanly.
- When a finding disappears between runs, do not assume it was fixed. It may be a failed query. Report the change in state and leave the ticket alone.
- When reporting on open tickets, report status and blockers as the ticketing system states them. Do not infer that a ticket is progressing because the underlying storage state looks acceptable.

## Demo / offline ticket store

When no ticketing MCP server is connected, `demos/fixtures/mock-tickets.md` in this repository stands in for the ticket system: read it to answer questions about open tickets and blockers, and append newly approved tickets to it in the same format. It is a demonstration fixture, not a system of record — say so whenever answers are drawn from it, and prefer a connected ticketing server whenever one is available.
