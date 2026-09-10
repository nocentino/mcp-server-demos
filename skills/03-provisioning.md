---
applyTo: "**"
description: "Proactive & Automation SOP: provisioning standards, presets, workload placement, anomaly detection, pre-deployment snapshots"
---

# Skill: Proactive & Automation

**When this applies**: the user asks to provision a new database workload, capture a deployed instance as a preset, check for drift against a tier standard, evaluate placement for a new volume, or run a pre-deployment snapshot ahead of a change.

## Provisioning Standards

Every new database workload is deployed to a tier standard. These definitions are the source of truth for both provisioning and drift detection — a workload that does not match its tier standard is a drift finding, not a variation.

| Attribute | Tier 1 (trading, OLTP) | Tier 2 (general databases) | Tier 3 (batch, archive) |
|---|---|---|---|
| QoS IOPS limit | Unlimited | 100,000 | 25,000 |
| QoS bandwidth limit | Unlimited | 2 GB/s | 512 MB/s |
| Latency SLA | < 0.5 ms | < 2 ms | < 10 ms |
| Snapshot cadence (local and remote) | 15 min | 1 hour | 24 hours |
| Local retention | 14 days | 7 days | 7 days |
| Remote retention | 30 days | 14 days | 14 days |
| Replication | Async to DR, 15 min RPO | Async to DR, 1 hour RPO | Async to DR, 24 hour RPO |
| Replication encryption | Required | Required | Required |
| Replication target | `sn1-c60-e12-16` (DR-AZ1) | `sn1-c60-e12-16` (DR-AZ1) | `sn1-c60-e12-16` (DR-AZ1) |
| Zone placement | Cluster pair split across two PROD zones | Cluster pair split across two PROD zones | Any PROD zone |
| Protection Group | Dedicated PG per SQL instance | Dedicated PG per SQL instance | Shared PG permitted within a tier |

The replication target column assumes a production workload. For an instance already resident on the DR array (`aen-sql-25-dr`), the target is a production array in a PROD zone — an array never satisfies a replication requirement by replicating to itself.

Retention values are tier **targets** and must always meet or exceed the binding policy floors in [Data Protection Compliance](02-compliance-audit.md#data-protection-compliance) (7-day local, 14-day remote). If a tier target and the policy floor ever disagree, the higher value wins.

**Decision rules — naming and tagging.** Any new volume, Protection Group, or preset must satisfy all of the following before it is considered compliant:
- Volume names are prefixed with the owning SQL Server instance name (e.g. `aen-sql-25-a-...`), so a volume's owner is identifiable without a tag lookup.
- Protection Group names contain the owning SQL Server instance name.
- Volumes carry `sql_instance`, `databases`, and `windows_drive` tags. Data volumes only — config volumes are out of scope.
- Volumes carry `environment` (`production`, `dev`, or `test`) and `workload_tier` (`tier1`, `tier2`, `tier3`). An untagged tier is not a Tier 3 workload, it is an unclassified one — report it as such.
- Protection Groups carry the `sql_instance` tag.

A preset that would produce a resource failing any of the above is incomplete. Fix the preset, do not deploy and tag afterward.

## Presets

Presets are the mechanism that makes the tier standards above enforceable at deploy time rather than discoverable at audit time.

**Procedure — deriving a preset from a deployed workload.** When asked to capture an existing instance's configuration as a standard:
1. Enumerate the instance's volumes via its `sql_instance` tag, and record QoS limits, host/host-group connections, and tags.
2. Resolve Protection Group membership, snapshot schedule, local and remote retention, and replication targets for those volumes.
3. Resolve the host array and zone from the [fleet topology table](00-reference.md#availability-zone-requirements).
4. Compare what is deployed against the tier standard above. Report every difference explicitly — the deployed state is the starting point for a standard, not automatically the standard itself. Never encode a deviation into a preset without naming it first.
5. Call `preset_schema` to confirm the preset shape before constructing a definition.

**Hard boundaries — presets are proposed and previewed, never applied without approval.** This is binding and has no exceptions:
- Present the complete preset definition — every field, in full — and the tier standard it claims to implement, before any create or update call.
- `presets_create` and `presets_update` are confirmation-gated (see [Guided Runbooks](06-incident-response.md#guided-runbooks)). Wait for explicit approval on the previewed definition. Approval of a preview covers that definition only; a changed definition needs fresh approval.
- Never create a preset as a side effect of another workflow, and never modify an existing preset when asked to create a new one.
- `workloads_deploy` is separately gated. Approving a preset is not approving a deployment from it.

**Decision rule — deviation reporting.** When asked which workloads deviate from a preset or tier standard, evaluate every attribute in the tier table above, report per-instance pass/fail per attribute, and route the results through the [Remediation Plan](02-compliance-audit.md#remediation-plan) format. Deviation findings are drift findings — severity comes from the [Severity Scale](05-ticketing.md#thresholds--severity-scale).

## Workload Placement

**Procedure** — when asked to provision a new database or volume, evaluate placement using:
1. Available free capacity (with headroom — apply capacity thresholds from [Real-Time Operational Visibility](04-operational-visibility.md)).
2. Array performance headroom (current IOPS + latency trends).
3. Replication topology (does the array replicate to the required DR target?).
4. Purity version (prefer arrays on the latest tested version).

Avoid placing new tier-1 workloads on arrays at or above the warn threshold.

Present placement recommendations as a scored table:

| Array | Free Capacity (TiB) | Capacity % Used | Avg Latency (ms) | Replicates to DR | Purity Version | Score | Recommendation |
|-------|--------------------:|----------------:|-----------------:|:----------------:|----------------|:-----:|----------------|

Score each candidate 1–5 (5 = best fit). The top-scoring array is the recommended target. If no array meets the headroom requirement, state that explicitly and escalate to Procurement.

## Anomaly Detection

**Procedure**
- Detect sudden IOPS or latency spikes and correlate with known batch job schedules.
- Identify volume-level latency outliers — volumes running 10x higher latency than the array average.
- Compare current snapshot consumption vs. baseline to detect runaway snapshot growth.

## Pre-Deployment Snapshot

**Procedure** — before any database schema change, application deployment, or OS patching:
1. Identify all volumes associated with the target database.
2. Create a PG snapshot with `SnapshotMode=pre-deployment` and appropriate tags.
3. Confirm the snapshot is complete and optionally replicated.
4. Report the snapshot name and timestamp for the change record.
