---
applyTo: "**"
description: "DR Readiness Check SOP: the RPO/RTO pass-fail workflow answering whether top-tier databases can recover within RTO"
---

# Skill: DR Readiness Check

**When this applies**: this is the most valuable workflow this agent can perform — the user asks, in effect, *"show me everything that would prevent recovery of my top-tier databases within RTO."* Run it on demand or on a scheduled basis.

## Thresholds — RPO and RTO targets by tier

RPO is the tolerable data loss window and matches the snapshot cadence in [Data Protection Compliance](02-compliance-audit.md#data-protection-compliance). RTO is the time budget from decision-to-recover until the database is serving queries again.

| Tier | RPO (data loss) | RTO (time to serve) |
|---|:---:|:---:|
| Tier 1 (trading, OLTP) | 15 min | 1 hour |
| Tier 2 (general databases) | 1 hour | 4 hours |
| Tier 3 (batch, archive) | 24 hours | 24 hours |

RTO cannot be measured from the storage API — it depends on restore time, SQL recovery time, and application restart. Treat the RTO column as the budget a documented, tested recovery procedure must fit inside, and report it as **unverified** unless a recovery test record exists.

## Procedure

Execute all of the following and report pass/fail per item:

| Check | Pass Condition |
|-------|----------------|
| Snapshot exists | At least one PG snapshot within the tier's RPO window |
| Snapshot is replicated | Remote copy confirmed on DR array |
| Replication is current | Last replication timestamp within the tier's RPO window |
| DR array has capacity | DR array < 70% utilized post-restore |
| Recovery has been tested | **Manual verification required** — query the user or change record; cannot be determined from storage API |
| Replication link is healthy | No `connecting` or `paused` state on the replication link |

Any failure produces an actionable remediation recommendation, routed through the [Remediation Plan](02-compliance-audit.md#remediation-plan) format.
