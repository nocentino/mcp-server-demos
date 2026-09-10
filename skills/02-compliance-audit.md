---
applyTo: "**"
description: "Compliance & Audit SOP: FlashArray and FlashBlade data-protection compliance, replication topology verification, drift detection, and the Remediation Plan"
---

# Skill: Compliance & Audit

**When this applies**: the user asks for a compliance or audit report, a DR/backup posture check, or "what would fail an audit" for the SQL estate — volumes, Protection Groups, or the FlashBlade filesystems and buckets that hold SQL Server backups.

## Data Protection Compliance

**Scope**: Run against all configured arrays from `list_arrays`, applying [Query Scoping](01-fleet-awareness.md#query-scoping--keep-responses-small) so the report covers the SQL estate without dragging in other tenants' resources. Include only volumes tagged `environment=production` or with a `sql_instance` tag. Skip volumes tagged `environment=dev` or `environment=test`. Volumes with no `environment` tag and no `sql_instance` tag should be listed separately as **unclassified** — do not apply compliance checks to them, but flag their existence.

**Thresholds — every production database volume must meet all of the following:**
- Assigned to a Protection Group (PG).
- PG has active replication to at least one remote array.
- Replication link is encrypted.
- Snapshot cadence meets the volume's tier (see below).
- Snapshot retention meets policy: **7-day local minimum, 14-day remote minimum.** These are binding, not advisory.

A volume's protection is only half the recovery chain. Wherever that instance's backups land — a FlashBlade filesystem or an S3 bucket — those objects carry their own binding DR replication requirement; see [FlashBlade Data Protection Compliance](#flashblade-data-protection-compliance-file--object) below. Do not report an instance as compliant on the strength of its volumes alone.

**Snapshot cadence by tier** — cadence is derived from the tier's RPO window, so a volume's schedule and its RPO target never disagree. Local and remote cadence are the same; a local snapshot that has not replicated does not satisfy RPO.

| Tier | Local snapshots | Remote snapshots | RPO window |
|---|:---:|:---:|:---:|
| Tier 1 (trading, OLTP) | 15 min | 15 min | 15 min |
| Tier 2 (general databases) | 1 hour | 1 hour | 1 hour |
| Tier 3 (batch, archive) | 24 hours | 24 hours | 24 hours |

Determine tier per the [tier assignment rules](04-operational-visibility.md#decision-rules--tier-assignment). Unclassified volumes default to Tier 3 for cadence purposes but must still be flagged as unclassified — do not let a Tier 3 default silently excuse a trading volume that is missing its tag.

**Volume tagging requirements:**
- `sql_instance` — the SQL Server instance name.
- `databases` — comma-separated list of databases on this volume.
- `windows_drive` — the Windows mount point or drive letter.
- Only consider data volumes for this, config volumes can be ignored.
- Protection Group must also be tagged with `sql_instance`.

Report any volumes or Protection Groups missing required tags.

## FlashBlade Data Protection Compliance (File & Object)

**Why this is in scope for a database agent.** SQL Server backups land on FlashBlade — NFS/SMB shares for `BACKUP TO DISK`, and S3 buckets for backup-to-URL and data virtualization. A database backup written to unprotected storage is not a backup. The recovery chain does not end at the FlashArray snapshot, so neither does this audit. Treat every filesystem or bucket that receives database backups as part of the protected estate and hold it to the same policy floors as the volumes it protects.

**Hard boundary — every SQL Server backup landing zone must replicate to the DR site.** This is a policy floor, not a preference, and it applies to any filesystem or bucket that receives SQL Server backups regardless of platform.

- The landing zone must have an **active outbound replica link** whose target resolves to the **DR site** in the [fleet topology table](00-reference.md#availability-zone-requirements). For FlashBlade file and object the DR target is `slc6-fbs200-n3-b35-12` (DR-AZ1).
- **Local snapshots do not satisfy this.** A snapshot living on the same array as the backup is destroyed with that array. Snapshot policy and DR replication are two separate checks and both must pass.
- **A link to an array absent from the topology table does not satisfy it.** An unlisted array's site is unknown, so it cannot be shown to be DR. `sn1-fb-c07-17` is the current example — it carries real replication traffic and is not a fleet member, not configured, and not in the table.
- **A link to another array at the same site does not satisfy it.** Resolve the target's site, never just its name.
- The link must be **current**: within the lag budget in FlashBlade RPO by tier, and read per the [stale-`idle` trap](00-reference.md#field-traps--these-produce-false-passes) rather than from `status` alone.
- A landing zone failing this check is **`CRITICAL`** — a database backup with no DR copy is the file/object equivalent of a production volume with no Protection Group.
- The only exit from this rule is scope: a landing zone that receives *only* dev or test backups must be tagged `environment=dev` or `environment=test`. Untagged means in scope.

**Scope**: Run against every configured FlashBlade in `list_arrays`. A FlashBlade not in `list_arrays` cannot be audited at all — report it as a **visibility gap**, never as a pass. In scope:

- Filesystems and buckets whose name or owning object-store account contains `sqlbackup`, `sql-backup`, `backup`, or `datavirt`, or which are tagged `environment=production`. These are **database backup landing zones**.
- Any filesystem or bucket explicitly named in a backup job or `BackupUrl` snapshot tag.
- Everything else on the array is **out of scope but counted** — report the total and say it was not assessed. Do not silently narrow a fleet report to the SQL objects.

**File (NFS / SMB) requirements** — every database backup landing filesystem must meet all of the following:

| Check | Pass condition | Where to look |
|---|---|---|
| Snapshot policy attached | At least one `file-system-snapshots` policy is a member | `/file-systems/policies-all` — export and share policies do **not** count |
| Snapshots actually exist | `space.snapshots > 0` | `get_filesystems_multi_tool` |
| **Replicated to DR** | An outbound `file-system-replica-link` exists **and** its target resolves to the DR site in the fleet topology table (`slc6-fbs200-n3-b35-12`). A target absent from the table, or at the same site, is a **FAIL** | `/file-system-replica-links` + topology table |
| Replica link is current | `lag` within the tier RPO budget; read `lag` and `recovery_point`, never `status` alone | `/file-system-replica-links` |
| SafeMode protection | `eradication_config.manual_eradication` is `disabled` | `get_filesystems_multi_tool` |
| Export not world-open | Not `_smb_share_allow_everyone`; NFS rules not `*(rw,no_root_squash)` | `/file-systems/policies-all`, `nfs.rules` |
| Capacity bounded | `hard_limit_enabled` true where a quota is set | `get_filesystems_multi_tool` |

**Object (S3) requirements** — every database backup bucket must meet all of the following. Object storage holding financial records is where immutability is a regulatory question, not a preference:

| Check | Pass condition | Field |
|---|---|---|
| Versioning enabled | `versioning` is `enabled` | `versioning` |
| Object Lock enabled | `object_lock_config.enabled` is `true` | `object_lock_config` |
| Retention lock ratcheted | `retention_lock` is `ratcheted` | `retention_lock` |
| SafeMode protection | `eradication_config.manual_eradication` is `disabled` | `eradication_config` |
| Eradication delay ≥ 24 h | `eradication_config.eradication_delay` ≥ 86400000 | `eradication_config` |
| Not publicly accessible | `public_status` is `bucket-and-objects-not-public`, and both `block_public_access` and `block_new_public_policies` are `true` | `public_access_config` |
| Audit policy attached | An `audit-object-store-policies` member exists | `/buckets/audit-object-store-policies` |
| **Replicated to DR** | A `bucket-replica-link` exists, `status` is `replicating`, **and** its target resolves to the DR site in the fleet topology table. A target absent from the table, or at the same site, is a **FAIL** | `/bucket-replica-links` + topology table |
| Replica link is current | `lag` within the tier RPO budget; `unhealthy` or `paused` is a FAIL | `/bucket-replica-links` |

**Decision rule — immutability is the object-store equivalent of the retention floor.** A bucket with `versioning: none` and `object_lock_config.enabled: false` cannot satisfy any retention requirement, because nothing prevents an overwrite or delete from destroying the only copy. Rate this `CRITICAL` for a database backup bucket, not `HIGH` — it is the object-store form of "no protection group".

**FlashBlade RPO by tier.** Backup landing zones inherit the tier of the databases they protect, not a tier of their own. Where a landing zone serves several instances, the **highest** tier wins.

| Tier of protected database | Filesystem snapshot cadence | Replica link lag budget |
|---|:---:|:---:|
| Tier 1 | 15 min | 15 min |
| Tier 2 | 1 hour | 1 hour |
| Tier 3 | 24 hours | 24 hours |

**Required report output — Backup Landing Zone DR Replication.** Every Compliance & Audit report must include this table, even when the answer is that nothing replicates. Its absence is itself a reporting failure, because a backup chain with no DR copy is invisible in a volume-only report.

| Landing zone | Type | Source array / site | Replica link | Target | Target site | Lag | Verdict |
|---|:---:|---|:---:|---|---|---:|:---:|

- One row per landing zone in scope. Never aggregate.
- `Target site` resolves through the fleet topology table. An unlisted target renders as **unknown — not DR**.
- `Verdict` is `PASS` only when a link exists, its target is the DR site, and its lag is within budget. Everything else is `FAIL` with the reason.
- Where no link exists at all, render `Replica link` as **none** and `Verdict` as `FAIL — no DR copy`, and carry it into the Remediation Plan at `CRITICAL`.
- Roll the count up into the report Summary line: *"N of M backup landing zones replicate to DR."*

FlashBlade protection state is easy to misread. The traps that produce false passes on file and object — SafeMode's inverted boolean, stale `idle` replica links, export policies masquerading as protection — are in [Field Traps](00-reference.md#field-traps--these-produce-false-passes). Read them before scoring any filesystem or bucket.

## Replication Topology Verification

**Procedure** — for tier-1 databases, verify:
- Replication target array is healthy and has capacity.
- Replication type matches the tier (sync for highest-tier, async with tight RPO for others).
- Last successful replication timestamp is within the defined RPO window.

## Configuration Drift Detection

**Procedure**
- Flag arrays where Purity versions differ significantly across the fleet — version skew increases operational risk.
- Flag replication connections in `connecting` state for extended periods (fleet-management links showing `connecting` should be investigated).
- Flag unencrypted replication links on production data.

## Remediation Plan

**Procedure** — after completing any Compliance & Audit report, produce a structured remediation plan. Order items by severity first, then by effort (lowest effort items within the same severity tier should be done first). Present the plan as a table with the following columns:

| Priority | Finding | Recommended Action | Effort | Risk | Change Type |
|---|---|---|:---:|:---:|:---:|

**Column definitions:**
- **Priority**: Numbered sequence (1 = do first). Derive from severity tier and effort — a low-effort critical fix ranks above a high-effort critical fix.
- **Finding**: The specific gap identified (e.g., "aen-sql-25-d: no Protection Group").
- **Recommended Action**: The concrete step to take (e.g., "Create PG, add data volumes, configure async replication to sn1-c60-e12-16").
- **Effort**: `Low` (under 30 min, no dependencies), `Medium` (30 min–2 hrs, some coordination), `High` (multi-step, cross-team, or requires testing).
- **Risk**: `None` (fully online, no impact to running workloads), `Low` (brief metadata operation, no I/O interruption), `Medium` (requires a maintenance window or brief connection drop), `High` (potential for data unavailability; requires coordinated change and rollback plan).
- **Change Type**: `Emergency` (do immediately, outside normal change process), `Planned` (schedule in next maintenance window), `Routine` (next sprint or change cycle).

**After the table**, include a short narrative paragraph summarizing the critical path: which item unblocks others, which items can be parallelized, and whether any items require coordination with teams outside the storage/DBA boundary (e.g., network team for encryption, app team for maintenance window).
