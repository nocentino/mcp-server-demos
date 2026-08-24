# Mock Ticket Store

**Purpose:** demonstration fixture standing in for a ServiceNow / Jira instance during the Fusion
MCP demo. It exists so the agent can answer "what tickets are open against the DR array right now,
and what's blocking them?" without a live ticketing connector.

**This is not a system of record.** Any answer drawn from this file must say so.

**How the agent uses it:** read the index and detail sections to answer questions about existing
tickets. Append newly approved tickets to the index and add a matching detail section, using the
ticket format defined in `database-sre-agent.md` → Change Management & Ticketing. Never edit the
status, severity, or assignment of an existing ticket without explicit approval.

**Snapshot date:** 2026-08-19 (revised 20:30Z — reconciled against live fleet state)

---

## Open Ticket Index

| Ticket | Severity | Affected Resource | Finding | Status | Owning Team | Change Type | Blocked By |
|---|:---:|---|---|---|---|:---:|---|
| INC0104412 | CRITICAL | aen-sql-25-dr | No Protection Group on any data volume — no snapshots, no replication | In Progress | Storage | Emergency | CHG0038871 awaiting CAB approval |
| CHG0038871 | CRITICAL | sn1-c60-e12-16 | Create `aen-sql-25-dr-pg`, add data volumes, configure schedule and retention | Awaiting Approval | Storage | Emergency | CAB slot 2026-08-22 20:00 ET; DR array alert state unverified (INC0104501) |
| INC0104388 | CRITICAL | aen-sql-25-c-pg | Replicates only within PROD-AZ1 and to off-fleet `gso-cbs-azure` — no copy reaches the DR site | Open | Storage | Emergency | Not blocked — unassigned, needs owner |
| INC0103977 | HIGH | Fleet-wide | Replication links between prod arrays and DR are unencrypted | On Hold | Network | Planned | Awaiting Network team key exchange and cipher policy sign-off |
| CHG0038650 | HIGH | sn1-x90r2-f06-33 → sn1-c60-e12-16 | Enable replication encryption on the array connection | Scheduled | Storage | Planned | Parent INC0103977 still on hold; window 2026-08-26 22:00 ET |
| INC0104501 | MEDIUM | sn1-c60-e12-16 | Fleet management link degraded — alert queries time out through gateway; true array state unknown | In Progress | Network | Planned | Awaiting network path trace between fleet gateway and DR site |
| INC0104233 | MEDIUM | sn1-x90r2-f07-27 | Management TLS certificate expires 2026-09-30 | Open | Storage | Planned | Not blocked — CSR not yet submitted to internal PKI |
| TASK0092210 | MEDIUM | sn1-x90r2-f05-33 → sn1-x90r2-f07-27 | Sync-replication pair spans three Purity releases (6.9.5 ↔ 6.12.1); DR target older than its source | Open | Storage | Routine | Not blocked — needs upgrade window request |
| INC0104610 | CRITICAL | aen-sqlbackups (FB filesystem) | Replica link to DR exists but has never transferred — `lag: null`, `recovery_point: 0`, no replication policy attached | Open | Storage | Emergency | Not blocked — newly raised |
| INC0102944 | HIGH | aen-sql-25-dr | No recorded recovery test; RTO for DR instance is unverified | On Hold | DBA | Planned | Awaiting DBA test window; dependent on INC0104412 (nothing to restore from yet) |
| TASK0091877 | LOW | sn1-s200-c09-33 | Filesystems missing `environment` and `workload_tier` tags; array unzoned in topology table | Open | Storage | Routine | Not blocked |

## Recently Closed

| Ticket | Affected Resource | Finding | Status | Closed |
|---|---|---|---|---|
| CHG0038102 | sn1-s200-c09-33 | Add API token to Fusion MCP auth config for FlashBlade visibility | Closed Complete | 2026-08-11 |
| TASK0092044 | slc6-fbs200-n3-b35-12 | No API token configured; alerts and performance invisible | Closed Complete | 2026-08-19 |
| INC0103512 | aen-sql-25-b | Snapshot cadence 1 hour against a Tier 1 requirement of 15 min | Closed Complete | 2026-08-04 |

---

## Ticket Detail

### INC0104412 — CRITICAL: aen-sql-25-dr — no Protection Group on any data volume

- **Affected Resource:** aen-sql-25-dr (volumes on `sn1-c60-e12-16`, DR-AZ1)
- **Finding:** Observed — data volumes tagged `sql_instance=aen-sql-25-dr` belong to no Protection
  Group. Required — every production database volume assigned to a PG with active replication.
  No snapshots exist. No alert fired, because nothing failed.
- **Evidence:** `get_volumes_multi_tool` on `sn1-c60-e12-16` returns the instance's volumes with no
  `protection_groups` membership; no PG on the array carries `sql_instance=aen-sql-25-dr`.
- **Recommended Action:** Create `aen-sql-25-dr-pg`, add all data volumes, set 24-hour snapshot
  cadence with 7-day local / 14-day remote retention, and configure replication to a production
  array. Tracked as CHG0038871.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Compliance & Audit report 2026-08-18, Remediation Plan priority 1
- **Status:** In Progress · **Blocked By:** CHG0038871 awaiting CAB approval
- **Notes:** 2026-08-18 — the instance migrated to the DR array; old volumes were destroyed and no
  PG was created on the destination. The DR environment has no DR.

### CHG0038871 — CRITICAL: sn1-c60-e12-16 — create Protection Group for aen-sql-25-dr

- **Affected Resource:** sn1-c60-e12-16 (DR-AZ1)
- **Finding:** Remediation change for INC0104412.
- **Recommended Action:** Create PG `aen-sql-25-dr-pg`; add data volumes; enable local and remote
  snapshot schedules; tag PG with `sql_instance=aen-sql-25-dr`; verify first replicated snapshot.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Status:** Awaiting Approval
- **Blocked By:** CAB slot 2026-08-22 20:00 ET. Secondary blocker — the DR array's alert state is
  unverified while INC0104501 is open, so post-change validation cannot be confirmed through the
  fleet gateway.

### INC0104388 — CRITICAL: aen-sql-25-c-pg — no replicated copy reaches the DR site

- **Affected Resource:** Protection Group `aen-sql-25-c-pg` on `sn1-x90r2-f06-33` (PROD-AZ1)
- **Finding:** Observed — PG holds 9 volumes and snapshots every 10 minutes, and both schedules are
  enabled, so it looks healthy. Its two replication targets are `sn1-x90r2-f06-27`, which is in the
  **same availability zone** (PROD-AZ1), and `gso-cbs-azure`, which is not a fleet member, not
  configured, and absent from the topology table. Required — an active replicated copy on the DR
  array. Neither target satisfies a DR requirement, so `aen-sql-25-c` has no recoverable copy at the
  DR site. Local retention derives to 4 days against a 7-day floor; remote to 4 days against 14.
- **Evidence:** `GET /protection-groups/targets?group_names=aen-sql-25-c-pg` returns
  `sn1-x90r2-f06-27` and `gso-cbs-azure`, both `replicating`. `GET /protection-group-snapshots` on
  `sn1-c60-e12-16` filtered to `aen-sql-25` returns no `aen-sql-25-c-pg` copies.
- **Recommended Action:** Add `sn1-c60-e12-16` as a replication target. Keep or drop the intra-AZ1
  target as a local convenience copy, but it cannot count as DR. Raise `source_retention` and
  `target_retention` to the policy floors. Confirm whether `gso-cbs-azure` is sanctioned for
  production data.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Compliance & Audit report 2026-08-19
- **Status:** Open · **Blocked By:** Not blocked — currently unassigned
- **Notes:** 2026-08-19 — this ticket previously described the PG as an empty shell with disabled
  schedules. That was wrong; the PG is populated and snapshotting. Finding retargeted to the actual
  defect, which a schedule-flag check would pass.

### INC0103977 — HIGH: fleet-wide — unencrypted replication links

- **Affected Resource:** array connections from `sn1-x90r2-f06-33`, `sn1-x90r2-f06-27`,
  `sn1-x90r2-f05-27` to `sn1-c60-e12-16`
- **Finding:** Observed — replication connections report encryption disabled. Required — all
  replication encrypted in a regulated environment. This is a fleet-wide finding, not a single
  misconfiguration.
- **Recommended Action:** Enable encryption on each array connection during a maintenance window;
  brief replication interruption expected per link. Child changes tracked separately.
- **Severity:** HIGH · **Effort:** High · **Risk:** Medium · **Change Type:** Planned
- **Owning Team:** Network (with Storage)
- **Source:** Compliance & Audit report 2026-08-18, Remediation Plan priority 4
- **Status:** On Hold · **Blocked By:** Network team key exchange and cipher policy sign-off; no ETA
  recorded

### CHG0038650 — HIGH: sn1-x90r2-f06-33 → sn1-c60-e12-16 — enable replication encryption

- **Affected Resource:** array connection `sn1-x90r2-f06-33` → `sn1-c60-e12-16`
- **Finding:** First child change of INC0103977; pilot link before fleet-wide rollout.
- **Recommended Action:** Enable encryption on the connection, confirm replication resumes, and
  validate a replicated snapshot lands within the Tier 1 RPO window.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Medium · **Change Type:** Planned
- **Owning Team:** Storage
- **Status:** Scheduled 2026-08-26 22:00 ET
- **Blocked By:** Parent INC0103977 remains on hold pending cipher policy sign-off; change may slip

### INC0104501 — MEDIUM: sn1-c60-e12-16 — fleet management link degraded

- **Affected Resource:** sn1-c60-e12-16 (DR-AZ1)
- **Finding:** Observed — `get_fleet_overview` returns `alerts_status` other than `success` for this
  array (HTTP 503, failed to connect to remote target). The array answers direct queries, so this
  reads as a degraded fleet-management link rather than a down array. Its true alert state is
  **Unknown — query failed**, not clean.
- **Recommended Action:** Network path trace between fleet gateway and DR site; re-establish the
  management link. Until then, query the DR array directly for alerts and mark all fleet-routed
  findings for this array as unverified.
- **Severity:** MEDIUM · **Effort:** Medium · **Risk:** None · **Change Type:** Planned
- **Owning Team:** Network
- **Source:** Config drift & security posture report 2026-08-18
- **Status:** In Progress · **Blocked By:** Awaiting network path trace results

### INC0104233 — MEDIUM: sn1-x90r2-f07-27 — management certificate approaching expiry

- **Affected Resource:** sn1-x90r2-f07-27 (PROD-AZ3)
- **Finding:** Observed — management TLS certificate expires 2026-09-30, 42 days out. Nothing is
  broken yet; that is the point of the finding.
- **Recommended Action:** Generate CSR, submit to internal PKI, install renewed certificate ahead of
  expiry.
- **Severity:** MEDIUM · **Effort:** Low · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Config drift & security posture report 2026-08-18
- **Status:** Open · **Blocked By:** Not blocked — CSR not yet submitted

### TASK0092210 — MEDIUM: cross-zone Purity skew on a sync-replication pair

- **Affected Resource:** `sn1-x90r2-f05-33` (6.9.5) ↔ `sn1-x90r2-f07-27` (6.12.1), sync-replication
- **Finding:** Observed — within-zone consistency passes everywhere; both PROD-AZ2 arrays are on
  6.9.5 and both PROD-AZ1 FlashArrays on 6.10.6. The skew is **cross-zone**: three FlashArray
  releases across the estate, with a **synchronous** pair spanning 6.9.5 to 6.12.1. Separately,
  `sn1-x90r2-f07-27` (6.12.1) async-replicates to `sn1-c60-e12-16` (6.10.6), so the DR target runs an
  older release than the production source it must recover.
- **Evidence:** `GET /arrays` on each array directly. Note the gateway reports
  `slc6-fbs200-n3-b35-12` as 4.8.0 while the array reports 4.8.4 — fleet-routed version data is
  stale for arrays whose management link is not `connected`.
- **Recommended Action:** Align the sync pair first — a three-release gap is a supportability
  question before it is a technical one. Then bring the DR array to at least the release of its
  highest-version source. Request an upgrade window.
- **Severity:** MEDIUM · **Effort:** High · **Risk:** Medium · **Change Type:** Routine
- **Owning Team:** Storage
- **Status:** Open · **Blocked By:** Not blocked — upgrade window request not yet submitted
- **Notes:** 2026-08-19 — previously filed as a PROD-AZ2 within-zone skew. Both AZ2 arrays are on
  6.9.5, so that premise was false. Retargeted to the skew that actually exists.

### INC0102944 — HIGH: aen-sql-25-dr — recovery never tested

- **Affected Resource:** aen-sql-25-dr
- **Finding:** Observed — no recovery test record exists for this instance. Required — a documented,
  tested recovery procedure inside the tier RTO budget. RTO cannot be measured from the storage API,
  so this stays **unverified** until a test record exists.
- **Recommended Action:** Schedule a DR restore test once protection exists; record duration against
  the tier RTO budget.
- **Severity:** HIGH · **Effort:** High · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** DBA
- **Status:** On Hold
- **Blocked By:** Dependent on INC0104412 — there is currently no snapshot to restore from. Also
  awaiting a DBA test window.

### TASK0091877 — LOW: sn1-s200-c09-33 — missing tags, array unzoned

- **Affected Resource:** sn1-s200-c09-33 (FlashBlade, unassigned site/zone)
- **Finding:** Filesystems lack `environment` and `workload_tier` tags; the array carries no site or
  zone assignment in the topology table, so workloads on it cannot be placed by blast-radius
  analysis.
- **Recommended Action:** Apply tags per the tagging requirements; assign site and zone in the
  topology table.
- **Severity:** LOW · **Effort:** Low · **Risk:** None · **Change Type:** Routine
- **Owning Team:** Storage
- **Status:** Open · **Blocked By:** Not blocked

### TASK0092044 — LOW: slc6-fbs200-n3-b35-12 — no configured API token

- **Affected Resource:** slc6-fbs200-n3-b35-12 (FlashBlade)
- **Finding:** Array is not present in `list_arrays`. FlashBlade alerts cannot be retrieved through
  remote execution at all, so without a configured token this array has no alert, performance, or
  capacity visibility.
- **Recommended Action:** Request a read-only API token from the platform team and add it to the
  Fusion MCP auth config. Describe the edit; do not print token values.
- **Severity:** LOW · **Effort:** Low · **Risk:** None · **Change Type:** Routine
- **Owning Team:** Storage
- **Source:** Fleet discovery 2026-08-18 — visibility gap
- **Status:** Open · **Blocked By:** Not blocked — token request with platform team

### INC0104610 — CRITICAL: aen-sqlbackups — replica link exists but has never transferred

- **Affected Resource:** filesystem `aen-sqlbackups` on `sn1-s200-c09-33` (PROD-AZ1)
- **Finding:** Observed — an outbound `file-system-replica-link` exists and correctly targets
  `slc6-fbs200-n3-b35-12` (DR-AZ1), and it reports `status: "idle"`. But `lag` is `null`,
  `recovery_point` is `0`, and `policies` is empty — the link has never completed a transfer, and with
  no replication policy attached it has no schedule, so it never will. Required — an active replica
  link to the DR site within the tier lag budget. There is no recovery point at any age.
- **Evidence:** `GET /file-system-replica-links` on `sn1-s200-c09-33`, link id
  `983fbd36-3e5b-1fbc-ff8f-8b434027c9dc`: `direction: outbound`, `lag: null`, `recovery_point: 0`,
  `policies: []`, `status: "idle"`.
- **Recommended Action:** Attach a replication policy to the existing link at the tier cadence — the
  target is already correct, so this is the whole fix. Then confirm a non-zero `recovery_point`
  appears and that lag falls inside budget.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Compliance & Audit report 2026-08-19, Backup Landing Zone DR Replication table
- **Status:** Open · **Blocked By:** Not blocked — newly raised
- **Notes:** An existence check or a `status` check both pass this link. It is the half-configured
  case, and it is more dangerous than no link because it appears on a report as configured.
