---
applyTo: "**"
description: "Real-Time Operational Visibility SOP: health/alerting, capacity thresholds, and performance SLA monitoring per workload tier"
---

# Skill: Real-Time Operational Visibility

**When this applies**: the user asks for current health, capacity, or performance posture of the fleet — alerts, hardware health, replication lag, "days to full," or latency against SLA.

## Procedure
- Surface active alerts with severity, affected resource, and estimated time-to-impact.
- Report array hardware health (controllers, drives, power, fans).
- Monitor replication lag — RPO violations in a financial environment are a compliance issue, not just an operations issue.
- Highlight unencrypted replication links; all replication should be encrypted in a regulated environment.
- Report physical capacity utilization per array with a `% used` column.
- Calculate "days to full" projections from historical space samples: call `get_arrays_performance_multi_tool` with `startTime` / `endTime` / `resolution` over a defined window (default 30 days), fit the growth trend, and **state the window used**. If history is unavailable, say so — do not omit the column silently or estimate without data.
- Flag provisioning overcommit — high overcommit on a near-full array is a risk. Use `used_provisioned / capacity`, not `space.thin_provisioning` (see [Key Formulas](00-reference.md#key-formulas--units)).
- Always present snapshot consumption separately from primary data consumption.
- Track latency per array and per volume against workload tier SLAs.
- Identify latency outliers — volumes or arrays performing significantly worse than their peers.
- Track IOPS and throughput trends to detect degradation before users notice.

## Thresholds: what "good" looks like

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Capacity `% used` | < 70% | 70–85% | ≥ 85% (escalate), ≥ 90% (critical) |
| Tier 1 latency (trading, OLTP) | < 0.5 ms | — | ≥ 0.5 ms |
| Tier 2 latency (general databases) | < 2 ms | — | ≥ 2 ms |
| Tier 3 latency (batch, archive) | < 10 ms | — | ≥ 10 ms |

## Decision rules — tier assignment

Determine a volume's tier using the `workload_tier` volume tag (`tier1`, `tier2`, `tier3`). If the tag is absent, apply these defaults:
- Volumes tagged `sql_instance` containing "trading" or "oltp" → Tier 1
- All other tagged SQL volumes → Tier 2
- Untagged volumes → Tier 3 (flag as unclassified in reports)

This tier-assignment rule is the source of truth other skills cite (Compliance & Audit's snapshot cadence, Provisioning Standards, DR Readiness's RPO/RTO). Do not redefine it elsewhere.
