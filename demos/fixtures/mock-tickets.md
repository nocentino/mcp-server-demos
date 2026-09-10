# Mock Ticket Store

**Purpose:** demonstration fixture standing in for a ServiceNow / Jira instance during the Fusion
MCP demo. It exists so the agent can answer "what tickets are open against the DR array right now,
and what's blocking them?" without a live ticketing connector.

**This is not a system of record.** Any answer drawn from this file must say so.

**How the agent uses it:** read the index and detail sections to answer questions about existing
tickets. Append newly approved tickets to the index and add a matching detail section, using the
ticket format defined in [`skills/05-ticketing.md`](../../skills/05-ticketing.md). Never edit the
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
- **Comment 2026-08-24 (agent):** Re-verified, no change in state. `aen-sql-25-dr`'s nine volumes on `sn1-c60-e12-16` are still in no protection group; `GET /protection-groups?filter=contains(name,'aen-sql-25')` on that array returns only the two inbound remote PGs replicated from `sn1-x90r2-f07-27` (`is_local: false`), and no local PG exists. The instance's volumes also carry zero tags of any kind. Not re-filed — this ticket covers it. Recommending no change to status or severity; CHG0038871 remains the remediation path.

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
- **Comment 2026-08-24 (agent):** Re-verified, no change in state. `GET /protection-groups/targets?group_names=aen-sql-25-c-pg` on `sn1-x90r2-f06-33` still returns exactly two targets, both `status: replicating`: `sn1-x90r2-f06-27`, which resolves to PROD-AZ1 — the same zone as the source — and `gso-cbs-azure`, which is absent from the Fleet topology table so its site cannot be resolved. `target_count: 2` with zero DR-resolving targets. Additionally noted: this PG's local and remote retention both derive to 4 days, tracked separately as INC0104629 and INC0104631. Not re-filed.

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
- **Comment 2026-08-24 (agent):** Re-verified and scope widened. Full link inventory taken by direct `GET /array-connections` on all eight configured arrays: **13 of 16 data-replication links are confirmed unencrypted**, including all five `sn1-c60-e12-16` DR links and all three sync-replication pairs. Two new facts for this ticket. First, the FlashBlade-to-FlashBlade DR link `sn1-s200-c09-33` → `slc6-fbs200-n3-b35-12` is also unencrypted (`encrypted: false`, read directly from slc6 — through the gateway it returns an empty `encryption` string and reads as no-data). Second, encryption demonstrably works on this fleet: the `gso-cbs-azure` links from `sn1-x90r2-f06-33` and `sn1-x90r2-f06-27` negotiate `encryption_mode: TLS-PSK-AES-256`, so the unencrypted state is a configuration choice rather than a platform limitation. Link 16 (`s200` → `sn1-fb-c07-17`) remains unverifiable — that array is unconfigured. Not re-filed. Recommending no change to status; the Network team hold is still the blocker.

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
- **Comment 2026-08-24 (agent):** Scope is wider than this ticket currently records. Recovery testing is unverified for **all five** SQL Server instances, not only `aen-sql-25-dr` — there is no recovery-test record for `aen-sql-25-a`, `-b`, `-c` or `-d` either, and RTO cannot be determined from the storage API for any of them. Recommending this ticket be re-scoped to the full estate, or four sibling tickets opened; either way that is a human decision and I have made no change to scope, severity or status. Not re-filed.

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
- **Comment 2026-08-24 (agent):** Re-verified, no change in state. Link `983fbd36-3e5b-1fbc-ff8f-8b434027c9dc` still reports `lag: null`, `recovery_point: 0`, `policies: []`, `status: "idle"`. Corroborating evidence added: the DR-side filesystem `aen-sqlbackups` on `slc6-fbs200-n3-b35-12` reports `space.total_used: 0` and `promotion_status: "demoted"`, and the DR array as a whole holds 191.10 MiB against 371.74 TiB of capacity with zero snapshots — consistent with nothing ever having transferred. The source filesystem also has no snapshot policy at all, filed separately as INC0104617. Not re-filed.

---

## Tickets filed 2026-08-24 — Consolidated Remediation Plan (CRITICAL and HIGH)

Filed on explicit approval. 38 tickets: 15 CRITICAL, 23 HIGH. Five findings from the same plan were **not** filed here because open tickets already cover them — INC0104388, INC0104610, INC0104412/CHG0038871, INC0103977/CHG0038650 and INC0102944 received comments instead.

| Ticket | Severity | Affected Resource | Finding | Status | Owning Team | Change Type | Blocked By |
|---|:---:|---|---|---|---|:---:|---|
| INC0104611 | CRITICAL | slc6-fbs200-n3-b35-12 | default `pureuser` password on the DR FlashBlade | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104612 | CRITICAL | aen-sql-25-d | no DR copy - protection group replicates to zero targets | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104613 | CRITICAL | bucket `aen-sql-backups` on sn1-s200-c09-33 | no object immutability on a database backup bucket | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104614 | CRITICAL | bucket `aen-sql-datavirt` on sn1-s200-c09-33 | no object immutability on a database backup bucket | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104615 | CRITICAL | bucket `backups` on sn1-s200-c09-33 | no object immutability on a database backup bucket | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104616 | CRITICAL | bucket `backup` on sn1-s200-c09-33 | no object immutability on a database backup bucket | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104617 | CRITICAL | filesystem `aen-sqlbackups` on sn1-s200-c09-33 | backup landing filesystem has no snapshot policy and no snapshots | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104618 | CRITICAL | filesystem `ayun-sqlbackups` on sn1-s200-c09-33 | backup landing filesystem has no snapshot policy and no snapshots | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104619 | CRITICAL | filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33 | backup landing filesystem has no snapshot policy and no snapshots | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104620 | CRITICAL | bucket `aen-sql-backups` on sn1-s200-c09-33 | no DR replica link on a database backup bucket | Open | Storage | Emergency | Blocked by INC0104613 - target and source versioning must be enabled before a replica link will establish |
| INC0104621 | CRITICAL | bucket `aen-sql-datavirt` on sn1-s200-c09-33 | no DR replica link on a database backup bucket | Open | Storage | Emergency | Blocked by INC0104614 - target and source versioning must be enabled before a replica link will establish |
| INC0104622 | CRITICAL | bucket `backups` on sn1-s200-c09-33 | no DR replica link on a database backup bucket | Open | Storage | Emergency | Blocked by INC0104615 - target and source versioning must be enabled before a replica link will establish |
| INC0104623 | CRITICAL | bucket `backup` on sn1-s200-c09-33 | no DR replica link on a database backup bucket | Open | Storage | Emergency | Blocked by INC0104616 - target and source versioning must be enabled before a replica link will establish |
| INC0104624 | CRITICAL | filesystem `ayun-sqlbackups` on sn1-s200-c09-33 | no DR replica link on a backup landing filesystem | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104625 | CRITICAL | filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33 | no DR replica link on a backup landing filesystem | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104626 | HIGH | sn1-x90r2-f05-33 | failed drive on the sync-replication target of production Pair 1 | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104627 | HIGH | protection group `aen-sql-25-a-pg` on sn1-x90r2-f07-27 | local snapshot retention below the 7-day policy floor | Open | Storage | Planned | Target value depends on the unresolved Tier 1 / Tier 2 classification - see Notes |
| INC0104628 | HIGH | protection group `aen-sql-25-b-pg` on sn1-x90r2-f07-27 | local snapshot retention below the 7-day policy floor | Open | Storage | Planned | Target value depends on the unresolved Tier 1 / Tier 2 classification - see Notes |
| INC0104629 | HIGH | protection group `aen-sql-25-c-pg` on sn1-x90r2-f06-33 | local snapshot retention below the 7-day policy floor | Open | Storage | Planned | Target value depends on the unresolved Tier 1 / Tier 2 classification - see Notes |
| INC0104630 | HIGH | protection group `aen-sql-25-a-pg` on sn1-x90r2-f07-27 | remote snapshot retention below the 14-day policy floor | Open | Storage | Planned | Target value depends on the unresolved Tier 1 / Tier 2 classification |
| INC0104631 | HIGH | protection group `aen-sql-25-c-pg` on sn1-x90r2-f06-33 | remote snapshot retention below the 14-day policy floor | Open | Storage | Planned | Target value depends on the unresolved Tier 1 / Tier 2 classification |
| INC0104632 | HIGH | aen-sql-25-d | snapshot cadence 6 hours against tier RPO, in a 255-volume shared pool | Open | Storage | Planned | Cadence target depends on the unresolved tier classification; sequence after INC0104612 restores a DR target |
| INC0104633 | HIGH | filesystem `aen-sqlbackups` on sn1-s200-c09-33 | database backup share is open to every host on the network | Open | Storage | Planned | Needs a brief coordination window with the DBA team to confirm backup job client addresses |
| INC0104634 | HIGH | filesystem `ayun-sqlbackups` on sn1-s200-c09-33 | database backup share is open to every host on the network | Open | Storage | Planned | Needs a brief coordination window with the DBA team to confirm backup job client addresses |
| INC0104635 | HIGH | filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33 | database backup share is open to every host on the network | Open | Storage | Planned | Needs a brief coordination window with the DBA team to confirm backup job client addresses |
| INC0104636 | HIGH | filesystem `aen-sqlbackups` on slc6-fbs200-n3-b35-12 | database backup share is open to every host on the network | Open | Storage | Planned | Needs a brief coordination window with the DBA team to confirm backup job client addresses |
| INC0104637 | HIGH | aen-sql-25-a | cluster pair does not span two production zones | Open | Storage | Planned | Requires an App team maintenance window; destination array choice depends on INC0104639 / INC0104640 |
| INC0104638 | HIGH | aen-sql-25-c | cluster pair does not span two production zones | Open | Storage | Planned | Requires an App team maintenance window; destination array choice depends on INC0104639 / INC0104640 |
| INC0104639 | HIGH | sn1-x90r2-f05-27 | configured array is not a fleet member - no fleet-wide alerting or reporting | Open | Storage | Planned | May be gated on the Purity upgrade in TASK0092210 if fleet membership has a minimum version |
| INC0104640 | HIGH | sn1-x90r2-f05-33 | configured array is not a fleet member - no fleet-wide alerting or reporting | Open | Storage | Planned | May be gated on the Purity upgrade in TASK0092210 if fleet membership has a minimum version |
| INC0104641 | HIGH | sn1-x90r2-f06-33 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104642 | HIGH | sn1-x90r2-f06-27 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104643 | HIGH | sn1-x90r2-f07-27 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104644 | HIGH | sn1-c60-e12-16 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104645 | HIGH | sn1-s200-c09-33 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104646 | HIGH | slc6-fbs200-n3-b35-12 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Emergency | Not blocked - newly raised |
| INC0104647 | HIGH | sn1-x90r2-f05-27 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Planned | Not blocked - newly raised |
| INC0104648 | HIGH | sn1-x90r2-f05-33 | SafeMode disabled - manual eradication permitted array-wide | Open | Storage | Planned | Not blocked - newly raised |

### Ticket Detail — tickets filed 2026-08-24

### INC0104611 — CRITICAL: slc6-fbs200-n3-b35-12 — default `pureuser` password on the DR FlashBlade

- **Affected Resource:** slc6-fbs200-n3-b35-12
- **Finding:** Observed - the DR FlashBlade is running with the factory default `pureuser` password, and its `default-network-access-policy` permits password login to the elevated `ir` support account from any IP address on the network. Required - no default credentials, and superuser password access restricted to management subnets. This array holds the DR copy of SQL Server backups and has SafeMode off on every object, so a single credential is sufficient to eradicate the DR data.
- **Evidence:** `get_fleet_overview(brief=false, include_alerts=true)` - alert code 1123 "Insecure Default pureuser Password" (severity warning, state open) and alert code 1140 on `default-network-access-policy`, which reports `ir` login "currently permitted from any IP address on the network". Compare `sn1-s200-c09-33`, where the same policy is scoped to 10.21.0.0/16.
- **Recommended Action:** Rotate the `pureuser` credential. Edit `default-network-access-policy` to remove the rule allowing `local-network-superuser-password-access` from any source, replacing it with the management subnet range. Re-run the array's alert list to confirm 1123 and 1140 clear.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 1
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Escalated from HIGH to CRITICAL. In isolation this is a credential-hygiene finding; combined with SafeMode being off on 20 of 20 fleet objects (see INC0104641-INC0104648) it is a single-step path to destroying the DR copy, which meets the CRITICAL definition of a DR database being unrecoverable.

### INC0104612 — CRITICAL: aen-sql-25-d — no DR copy - protection group replicates to zero targets

- **Affected Resource:** aen-sql-25-d
- **Finding:** Observed - aen-sql-25-d's six data volumes belong to the shared protection group `pgroup-auto` on `sn1-x90r2-f06-27`. That PG reports `replication_schedule.enabled: true` with `target_count: 0` - snapshots are scheduled to replicate nowhere. Required - PG with active replication to at least one remote array resolving to the DR site. There is no off-array copy of this instance's data.
- **Evidence:** `GET /protection-groups?names=pgroup-auto` on `sn1-x90r2-f06-27`: `replication_schedule.enabled: true`, `replication_schedule.frequency: 21600000`, `target_count: 0`, `volume_count: 255`. `GET /protection-groups/volumes?group_names=pgroup-auto` confirms six `vvol-aen-sql-25-d-a9ecd10d-vg/*` members.
- **Recommended Action:** Add `sn1-c60-e12-16` (DR-AZ1) as a replication target on the instance's protection group and verify the first transfer completes with a non-zero recovery point. See INC0104632 for the separate dedicated-PG and cadence work.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 2
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** An enabled replication schedule with zero targets passes any check that reads the schedule flag alone. This is what a spreadsheet audit records as "replication: enabled".

### INC0104613 — CRITICAL: bucket `aen-sql-backups` on sn1-s200-c09-33 — no object immutability on a database backup bucket

- **Affected Resource:** bucket `aen-sql-backups` on sn1-s200-c09-33
- **Finding:** Observed - bucket `aen-sql-backups` (object-store account `aen-sql-backups`) holds 7.49 TiB of SQL Server backup data across 166 objects with `versioning: none` and `object_lock_config.enabled: false`. Required - versioning enabled, Object Lock enabled, and `retention_lock` ratcheted. Nothing prevents an overwrite or delete from destroying the only copy, so no retention requirement can be satisfied.
- **Evidence:** `GET /buckets?filter=contains(name,'aen-sql-backups')` on `sn1-s200-c09-33`: `versioning: "none"`, `object_lock_config.enabled: false`, `retention_lock: "unlocked"`, `eradication_config.manual_eradication: "enabled"`, `space.total_used` 7.49 TiB.
- **Recommended Action:** Enable versioning via `PutBucketVersioning`, then enable `object_lock_config` and ratchet `retention_lock`. Versioning must be enabled before the DR replica link in INC0104620 can be established.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 5
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Rated CRITICAL rather than HIGH: for a database backup bucket this is the object-store equivalent of a production volume with no protection group.

### INC0104614 — CRITICAL: bucket `aen-sql-datavirt` on sn1-s200-c09-33 — no object immutability on a database backup bucket

- **Affected Resource:** bucket `aen-sql-datavirt` on sn1-s200-c09-33
- **Finding:** Observed - bucket `aen-sql-datavirt` (object-store account `aen-sql-datavirt`) holds 13.80 GiB of SQL Server backup data across 140 objects with `versioning: none` and `object_lock_config.enabled: false`. Required - versioning enabled, Object Lock enabled, and `retention_lock` ratcheted. Nothing prevents an overwrite or delete from destroying the only copy, so no retention requirement can be satisfied.
- **Evidence:** `GET /buckets?filter=contains(name,'aen-sql-datavirt')` on `sn1-s200-c09-33`: `versioning: "none"`, `object_lock_config.enabled: false`, `retention_lock: "unlocked"`, `eradication_config.manual_eradication: "enabled"`, `space.total_used` 13.80 GiB.
- **Recommended Action:** Enable versioning via `PutBucketVersioning`, then enable `object_lock_config` and ratchet `retention_lock`. Versioning must be enabled before the DR replica link in INC0104621 can be established.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 5
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Rated CRITICAL rather than HIGH: for a database backup bucket this is the object-store equivalent of a production volume with no protection group.

### INC0104615 — CRITICAL: bucket `backups` on sn1-s200-c09-33 — no object immutability on a database backup bucket

- **Affected Resource:** bucket `backups` on sn1-s200-c09-33
- **Finding:** Observed - bucket `backups` (object-store account `ayun-sql-backups`) holds 500.00 GiB of SQL Server backup data across 19 objects with `versioning: none` and `object_lock_config.enabled: false`. Required - versioning enabled, Object Lock enabled, and `retention_lock` ratcheted. Nothing prevents an overwrite or delete from destroying the only copy, so no retention requirement can be satisfied.
- **Evidence:** `GET /buckets?filter=contains(name,'backups')` on `sn1-s200-c09-33`: `versioning: "none"`, `object_lock_config.enabled: false`, `retention_lock: "unlocked"`, `eradication_config.manual_eradication: "enabled"`, `space.total_used` 500.00 GiB.
- **Recommended Action:** Enable versioning via `PutBucketVersioning`, then enable `object_lock_config` and ratchet `retention_lock`. Versioning must be enabled before the DR replica link in INC0104622 can be established.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 5
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Rated CRITICAL rather than HIGH: for a database backup bucket this is the object-store equivalent of a production volume with no protection group.

### INC0104616 — CRITICAL: bucket `backup` on sn1-s200-c09-33 — no object immutability on a database backup bucket

- **Affected Resource:** bucket `backup` on sn1-s200-c09-33
- **Finding:** Observed - bucket `backup` (object-store account `uab`, 313.23 KiB across 5 objects) has `versioning: enabled` but `object_lock_config.enabled: false` and `retention_lock: unlocked`. Required - Object Lock enabled and retention lock ratcheted. Versioning alone preserves prior versions but does not prevent their deletion, so the immutability requirement is unmet.
- **Evidence:** `GET /buckets?filter=contains(name,'backup')` on `sn1-s200-c09-33`: `versioning: "enabled"`, `object_lock_config.enabled: false`, `retention_lock: "unlocked"`, `eradication_config.manual_eradication: "enabled"`, `space.total_used` 313.23 KiB.
- **Recommended Action:** Enable `object_lock_config` and ratchet `retention_lock`. Confirm bucket ownership first - see the LOW-severity scoping question on this bucket's account (`uab`), which is not a SQL owner.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 5
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Rated CRITICAL rather than HIGH: for a database backup bucket this is the object-store equivalent of a production volume with no protection group.

### INC0104617 — CRITICAL: filesystem `aen-sqlbackups` on sn1-s200-c09-33 — backup landing filesystem has no snapshot policy and no snapshots

- **Affected Resource:** filesystem `aen-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `aen-sqlbackups` receives SQL Server backups and holds 624.02 MiB, with `space.snapshots: 0` and no `file-system-snapshots` policy attached. The policies that are attached are NFS export, SMB share and SMB client policies only - none of them is a protection policy. Required - at least one snapshot policy attached, with snapshots present at the tier cadence.
- **Evidence:** `get_filesystems_multi_tool` on `sn1-s200-c09-33`: `space.snapshots: 0`. `GET /file-systems/policies-all?member_names=aen-sqlbackups` returns only `resource_type` values of `nfs-export-policies`, `smb-share-policies` and `smb-client-policies` - zero `file-system-snapshots` members.
- **Recommended Action:** Attach a `file-system-snapshots` policy at the tier cadence for the databases this share protects (15 min if Tier 1 is confirmed, 1 hour if Tier 2), then confirm `space.snapshots` becomes non-zero on the next scheduled run.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 6
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** A filesystem can show three attached policies and still have zero protection. Filter `/file-systems/policies-all` by `resource_type` before concluding anything.

### INC0104618 — CRITICAL: filesystem `ayun-sqlbackups` on sn1-s200-c09-33 — backup landing filesystem has no snapshot policy and no snapshots

- **Affected Resource:** filesystem `ayun-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `ayun-sqlbackups` receives SQL Server backups and holds 643.13 GiB, with `space.snapshots: 0` and no `file-system-snapshots` policy attached. The policies that are attached are NFS export, SMB share and SMB client policies only - none of them is a protection policy. Required - at least one snapshot policy attached, with snapshots present at the tier cadence.
- **Evidence:** `get_filesystems_multi_tool` on `sn1-s200-c09-33`: `space.snapshots: 0`. `GET /file-systems/policies-all?member_names=ayun-sqlbackups` returns only `resource_type` values of `nfs-export-policies`, `smb-share-policies` and `smb-client-policies` - zero `file-system-snapshots` members.
- **Recommended Action:** Attach a `file-system-snapshots` policy at the tier cadence for the databases this share protects (15 min if Tier 1 is confirmed, 1 hour if Tier 2), then confirm `space.snapshots` becomes non-zero on the next scheduled run.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 6
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** A filesystem can show three attached policies and still have zero protection. Filter `/file-systems/policies-all` by `resource_type` before concluding anything.

### INC0104619 — CRITICAL: filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33 — backup landing filesystem has no snapshot policy and no snapshots

- **Affected Resource:** filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `joe-demo-sqlbackups` receives SQL Server backups and holds 0 B, with `space.snapshots: 0` and no `file-system-snapshots` policy attached. The policies that are attached are NFS export, SMB share and SMB client policies only - none of them is a protection policy. Required - at least one snapshot policy attached, with snapshots present at the tier cadence.
- **Evidence:** `get_filesystems_multi_tool` on `sn1-s200-c09-33`: `space.snapshots: 0`. `GET /file-systems/policies-all?member_names=joe-demo-sqlbackups` returns only `resource_type` values of `nfs-export-policies`, `smb-share-policies` and `smb-client-policies` - zero `file-system-snapshots` members.
- **Recommended Action:** Attach a `file-system-snapshots` policy at the tier cadence for the databases this share protects (15 min if Tier 1 is confirmed, 1 hour if Tier 2), then confirm `space.snapshots` becomes non-zero on the next scheduled run.
- **Severity:** CRITICAL · **Effort:** Low · **Risk:** None · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 6
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** A filesystem can show three attached policies and still have zero protection. Filter `/file-systems/policies-all` by `resource_type` before concluding anything.

### INC0104620 — CRITICAL: bucket `aen-sql-backups` on sn1-s200-c09-33 — no DR replica link on a database backup bucket

- **Affected Resource:** bucket `aen-sql-backups` on sn1-s200-c09-33
- **Finding:** Observed - bucket `aen-sql-backups` (7.49 TiB) receives SQL Server backup or data-virtualization data and has no `bucket-replica-link` of any kind. Required - a bucket replica link whose target resolves to the DR site in the Fleet topology table (`slc6-fbs200-n3-b35-12`, DR-AZ1), replicating within the tier lag budget. There is no DR copy of this data.
- **Evidence:** `GET /bucket-replica-links` on `sn1-s200-c09-33` returns 5 links, for local buckets `abucket`, `webex`, `test`, `ehsu-test3` and `newbuck`. `aen-sql-backups` is absent from the list. `GET /buckets` on `slc6-fbs200-n3-b35-12` returns `total_item_count: 3` and no bucket matching this name.
- **Recommended Action:** Create an outbound `bucket-replica-link` from `aen-sql-backups` to a target bucket on `slc6-fbs200-n3-b35-12`. Versioning must be enabled on both source and target first - the existing `abucket` link is currently `unhealthy` with exactly this error.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 7
- **Status:** Open · **Blocked By:** Blocked by INC0104613 - target and source versioning must be enabled before a replica link will establish

### INC0104621 — CRITICAL: bucket `aen-sql-datavirt` on sn1-s200-c09-33 — no DR replica link on a database backup bucket

- **Affected Resource:** bucket `aen-sql-datavirt` on sn1-s200-c09-33
- **Finding:** Observed - bucket `aen-sql-datavirt` (13.80 GiB) receives SQL Server backup or data-virtualization data and has no `bucket-replica-link` of any kind. Required - a bucket replica link whose target resolves to the DR site in the Fleet topology table (`slc6-fbs200-n3-b35-12`, DR-AZ1), replicating within the tier lag budget. There is no DR copy of this data.
- **Evidence:** `GET /bucket-replica-links` on `sn1-s200-c09-33` returns 5 links, for local buckets `abucket`, `webex`, `test`, `ehsu-test3` and `newbuck`. `aen-sql-datavirt` is absent from the list. `GET /buckets` on `slc6-fbs200-n3-b35-12` returns `total_item_count: 3` and no bucket matching this name.
- **Recommended Action:** Create an outbound `bucket-replica-link` from `aen-sql-datavirt` to a target bucket on `slc6-fbs200-n3-b35-12`. Versioning must be enabled on both source and target first - the existing `abucket` link is currently `unhealthy` with exactly this error.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 7
- **Status:** Open · **Blocked By:** Blocked by INC0104614 - target and source versioning must be enabled before a replica link will establish

### INC0104622 — CRITICAL: bucket `backups` on sn1-s200-c09-33 — no DR replica link on a database backup bucket

- **Affected Resource:** bucket `backups` on sn1-s200-c09-33
- **Finding:** Observed - bucket `backups` (500.00 GiB) receives SQL Server backup or data-virtualization data and has no `bucket-replica-link` of any kind. Required - a bucket replica link whose target resolves to the DR site in the Fleet topology table (`slc6-fbs200-n3-b35-12`, DR-AZ1), replicating within the tier lag budget. There is no DR copy of this data.
- **Evidence:** `GET /bucket-replica-links` on `sn1-s200-c09-33` returns 5 links, for local buckets `abucket`, `webex`, `test`, `ehsu-test3` and `newbuck`. `backups` is absent from the list. `GET /buckets` on `slc6-fbs200-n3-b35-12` returns `total_item_count: 3` and no bucket matching this name.
- **Recommended Action:** Create an outbound `bucket-replica-link` from `backups` to a target bucket on `slc6-fbs200-n3-b35-12`. Versioning must be enabled on both source and target first - the existing `abucket` link is currently `unhealthy` with exactly this error.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 7
- **Status:** Open · **Blocked By:** Blocked by INC0104615 - target and source versioning must be enabled before a replica link will establish

### INC0104623 — CRITICAL: bucket `backup` on sn1-s200-c09-33 — no DR replica link on a database backup bucket

- **Affected Resource:** bucket `backup` on sn1-s200-c09-33
- **Finding:** Observed - bucket `backup` (313.23 KiB) receives SQL Server backup or data-virtualization data and has no `bucket-replica-link` of any kind. Required - a bucket replica link whose target resolves to the DR site in the Fleet topology table (`slc6-fbs200-n3-b35-12`, DR-AZ1), replicating within the tier lag budget. There is no DR copy of this data.
- **Evidence:** `GET /bucket-replica-links` on `sn1-s200-c09-33` returns 5 links, for local buckets `abucket`, `webex`, `test`, `ehsu-test3` and `newbuck`. `backup` is absent from the list. `GET /buckets` on `slc6-fbs200-n3-b35-12` returns `total_item_count: 3` and no bucket matching this name.
- **Recommended Action:** Create an outbound `bucket-replica-link` from `backup` to a target bucket on `slc6-fbs200-n3-b35-12`. Versioning must be enabled on both source and target first - the existing `abucket` link is currently `unhealthy` with exactly this error.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 7
- **Status:** Open · **Blocked By:** Blocked by INC0104616 - target and source versioning must be enabled before a replica link will establish

### INC0104624 — CRITICAL: filesystem `ayun-sqlbackups` on sn1-s200-c09-33 — no DR replica link on a backup landing filesystem

- **Affected Resource:** filesystem `ayun-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `ayun-sqlbackups` receives SQL Server backups (643.13 GiB) and has no `file-system-replica-link`. Required - an outbound replica link whose target resolves to the DR site (`slc6-fbs200-n3-b35-12`, DR-AZ1) with a replication policy attached and lag inside the tier budget. There is no DR copy of these backups.
- **Evidence:** `GET /file-system-replica-links` on `sn1-s200-c09-33` returns 8 links; local filesystems covered are `images`, `rp-dr-filesystem`, `fsa-lab-files`, `aen-sqlbackups`, `kehui-fb-fs-02`, `petetest`, `ehsu-Mistral-Large-Instruct-2411` and `rpope`. `ayun-sqlbackups` is absent.
- **Recommended Action:** Create an outbound `file-system-replica-link` from `ayun-sqlbackups` to `slc6-fbs200-n3-b35-12` and attach a replication policy at the tier cadence. Do not repeat the INC0104610 defect - a link with `policies: []` never transfers.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 8
- **Status:** Open · **Blocked By:** Not blocked - newly raised

### INC0104625 — CRITICAL: filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33 — no DR replica link on a backup landing filesystem

- **Affected Resource:** filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `joe-demo-sqlbackups` receives SQL Server backups (0 B) and has no `file-system-replica-link`. Required - an outbound replica link whose target resolves to the DR site (`slc6-fbs200-n3-b35-12`, DR-AZ1) with a replication policy attached and lag inside the tier budget. There is no DR copy of these backups.
- **Evidence:** `GET /file-system-replica-links` on `sn1-s200-c09-33` returns 8 links; local filesystems covered are `images`, `rp-dr-filesystem`, `fsa-lab-files`, `aen-sqlbackups`, `kehui-fb-fs-02`, `petetest`, `ehsu-Mistral-Large-Instruct-2411` and `rpope`. `joe-demo-sqlbackups` is absent.
- **Recommended Action:** Create an outbound `file-system-replica-link` from `joe-demo-sqlbackups` to `slc6-fbs200-n3-b35-12` and attach a replication policy at the tier cadence. Do not repeat the INC0104610 defect - a link with `policies: []` never transfers.
- **Severity:** CRITICAL · **Effort:** Medium · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 8
- **Status:** Open · **Blocked By:** Not blocked - newly raised

### INC0104626 — HIGH: sn1-x90r2-f05-33 — failed drive on the sync-replication target of production Pair 1

- **Affected Resource:** sn1-x90r2-f05-33
- **Finding:** Observed - drive `ch0.nvb0` reports `failure`, expected `healthy`, actual `failed`, open since 2026-08-17 and last updated 2026-08-22. This array is the sync-replication target of `sn1-x90r2-f07-27`, which hosts production cluster Pair 1 (aen-sql-25-a and aen-sql-25-b). It is also not a fleet member, so this alert appears in no fleet-wide report and fires into no fleet-wide alerting path. Required - healthy hardware on any array holding a synchronous copy of production data, with alert visibility.
- **Evidence:** `GET /alerts?filter=state='open'` queried **directly** against `sn1-x90r2-f05-33` (the array is absent from `get_fleet_overview`, so the gateway cannot report it): alert code 60, `component_type: drive`, `component_name: ch0.nvb0`, `severity: warning`, `flagged: true`, `created: 1787106573545`, `updated: 1787538589452`. `GET /array-connections` on the same array shows `sn1-x90r2-f07-27`, `type: sync-replication`, `status: connected`.
- **Recommended Action:** Raise a hardware replacement with Pure Support for `ch0.nvb0`. Verify sync-replication health to `sn1-x90r2-f07-27` before and after the swap. Do not schedule the Purity upgrade in TASK0092210 until this is closed - upgrading an array with a failed drive is the wrong order of operations.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 11
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Four risk factors stack on this one array: failed drive, oldest Purity in the fleet (6.9.5), three releases behind its sync partner, and no fleet-wide monitoring. Only a direct query surfaced it.

### INC0104627 — HIGH: protection group `aen-sql-25-a-pg` on sn1-x90r2-f07-27 — local snapshot retention below the 7-day policy floor

- **Affected Resource:** protection group `aen-sql-25-a-pg` on sn1-x90r2-f07-27
- **Finding:** Observed - effective local retention on `aen-sql-25-a-pg` (instance aen-sql-25-a) is **3 days**. Required - 7-day local minimum, which is a binding policy floor, and 14 days if the Tier 1 target applies. Derivation: `all_for_sec: 259200` alone = 3 days; `days: 7` is inert because `per_day: 0`.
- **Evidence:** `GET /protection-groups?names=aen-sql-25-a-pg` on sn1-x90r2-f07-27: `source_retention.all_for_sec: 259200`, `source_retention.days: 7`, `source_retention.per_day: 0`. Note the raw `days` value reads as compliant on its own - the derived figure is what fails.
- **Recommended Action:** Raise `source_retention.all_for_sec` to at least 604800 (7 days), or 1209600 (14 days) if the Tier 1 classification is confirmed. Re-read the PG afterwards and re-derive the effective value rather than checking `days`.
- **Severity:** HIGH · **Effort:** Low · **Risk:** None · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 12
- **Status:** Open · **Blocked By:** Target value depends on the unresolved Tier 1 / Tier 2 classification - see Notes
- **Notes:** Tier is currently inferred, not tagged. The `databases` tag on this instance's volumes names TPC-C workloads, which would make it Tier 1 (14-day local target) rather than Tier 2. Confirm with DBA before setting the value; the 7-day floor applies either way.

### INC0104628 — HIGH: protection group `aen-sql-25-b-pg` on sn1-x90r2-f07-27 — local snapshot retention below the 7-day policy floor

- **Affected Resource:** protection group `aen-sql-25-b-pg` on sn1-x90r2-f07-27
- **Finding:** Observed - effective local retention on `aen-sql-25-b-pg` (instance aen-sql-25-b) is **3 days**. Required - 7-day local minimum, which is a binding policy floor, and 14 days if the Tier 1 target applies. Derivation: `all_for_sec: 259200` alone = 3 days; `days: 7` is inert because `per_day: 0`.
- **Evidence:** `GET /protection-groups?names=aen-sql-25-b-pg` on sn1-x90r2-f07-27: `source_retention.all_for_sec: 259200`, `source_retention.days: 7`, `source_retention.per_day: 0`. Note the raw `days` value reads as compliant on its own - the derived figure is what fails.
- **Recommended Action:** Raise `source_retention.all_for_sec` to at least 604800 (7 days), or 1209600 (14 days) if the Tier 1 classification is confirmed. Re-read the PG afterwards and re-derive the effective value rather than checking `days`.
- **Severity:** HIGH · **Effort:** Low · **Risk:** None · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 12
- **Status:** Open · **Blocked By:** Target value depends on the unresolved Tier 1 / Tier 2 classification - see Notes
- **Notes:** Tier is currently inferred, not tagged. The `databases` tag on this instance's volumes names TPC-C workloads, which would make it Tier 1 (14-day local target) rather than Tier 2. Confirm with DBA before setting the value; the 7-day floor applies either way.

### INC0104629 — HIGH: protection group `aen-sql-25-c-pg` on sn1-x90r2-f06-33 — local snapshot retention below the 7-day policy floor

- **Affected Resource:** protection group `aen-sql-25-c-pg` on sn1-x90r2-f06-33
- **Finding:** Observed - effective local retention on `aen-sql-25-c-pg` (instance aen-sql-25-c) is **4 days**. Required - 7-day local minimum, which is a binding policy floor, and 14 days if the Tier 1 target applies. Derivation: `all_for_sec: 86400` + (`days: 3` x 86400 because `per_day: 4` > 0) = 4 days.
- **Evidence:** `GET /protection-groups?names=aen-sql-25-c-pg` on sn1-x90r2-f06-33: `source_retention.all_for_sec: 86400`, `source_retention.days: 3`, `source_retention.per_day: 4`. Note the raw `days` value reads as compliant on its own - the derived figure is what fails.
- **Recommended Action:** Raise `source_retention.all_for_sec` to at least 604800 (7 days), or 1209600 (14 days) if the Tier 1 classification is confirmed. Re-read the PG afterwards and re-derive the effective value rather than checking `days`.
- **Severity:** HIGH · **Effort:** Low · **Risk:** None · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 12
- **Status:** Open · **Blocked By:** Target value depends on the unresolved Tier 1 / Tier 2 classification - see Notes
- **Notes:** Tier is currently inferred, not tagged. The `databases` tag on this instance's volumes names TPC-C workloads, which would make it Tier 1 (14-day local target) rather than Tier 2. Confirm with DBA before setting the value; the 7-day floor applies either way.

### INC0104630 — HIGH: protection group `aen-sql-25-a-pg` on sn1-x90r2-f07-27 — remote snapshot retention below the 14-day policy floor

- **Affected Resource:** protection group `aen-sql-25-a-pg` on sn1-x90r2-f07-27
- **Finding:** Observed - effective remote retention on `aen-sql-25-a-pg` (instance aen-sql-25-a) is **7 days**. Required - 14-day remote minimum as a binding policy floor, and 30 days if the Tier 1 target applies. Derivation: `all_for_sec: 604800` alone = 7 days; `days: 7` is inert because `per_day: 0`.
- **Evidence:** `GET /protection-groups?names=aen-sql-25-a-pg` on sn1-x90r2-f07-27: `target_retention.all_for_sec: 604800`, `target_retention.days: 7`, `target_retention.per_day: 0`.
- **Recommended Action:** Raise `target_retention.all_for_sec` to at least 1209600 (14 days), or 2592000 (30 days) if Tier 1 is confirmed. Re-derive after the change.
- **Severity:** HIGH · **Effort:** Low · **Risk:** None · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 13
- **Status:** Open · **Blocked By:** Target value depends on the unresolved Tier 1 / Tier 2 classification
- **Notes:** For comparison, `aen-sql-25-b-pg` already meets the remote floor at 14 days - the same change applied there is the reference.

### INC0104631 — HIGH: protection group `aen-sql-25-c-pg` on sn1-x90r2-f06-33 — remote snapshot retention below the 14-day policy floor

- **Affected Resource:** protection group `aen-sql-25-c-pg` on sn1-x90r2-f06-33
- **Finding:** Observed - effective remote retention on `aen-sql-25-c-pg` (instance aen-sql-25-c) is **4 days**. Required - 14-day remote minimum as a binding policy floor, and 30 days if the Tier 1 target applies. Derivation: `all_for_sec: 86400` + (`days: 3` x 86400 because `per_day: 4` > 0) = 4 days.
- **Evidence:** `GET /protection-groups?names=aen-sql-25-c-pg` on sn1-x90r2-f06-33: `target_retention.all_for_sec: 86400`, `target_retention.days: 3`, `target_retention.per_day: 4`.
- **Recommended Action:** Raise `target_retention.all_for_sec` to at least 1209600 (14 days), or 2592000 (30 days) if Tier 1 is confirmed. Re-derive after the change.
- **Severity:** HIGH · **Effort:** Low · **Risk:** None · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 13
- **Status:** Open · **Blocked By:** Target value depends on the unresolved Tier 1 / Tier 2 classification
- **Notes:** For comparison, `aen-sql-25-b-pg` already meets the remote floor at 14 days - the same change applied there is the reference.

### INC0104632 — HIGH: aen-sql-25-d — snapshot cadence 6 hours against tier RPO, in a 255-volume shared pool

- **Affected Resource:** aen-sql-25-d
- **Finding:** Observed - aen-sql-25-d has no dedicated protection group. Its volumes sit in `pgroup-auto`, a shared PG holding 255 volumes belonging to other workloads, snapshotting every 6 hours (`frequency: 21600000`). Latest snapshot at time of audit was 196 minutes old. Required - a dedicated protection group per SQL instance, with cadence matching the tier RPO (1 hour for Tier 2, 15 minutes for Tier 1). The instance also carries no `sql_instance` tag on its PG.
- **Evidence:** `GET /protection-groups?names=pgroup-auto` on `sn1-x90r2-f06-27`: `volume_count: 255`, `snapshot_schedule.frequency: 21600000`. `GET /protection-group-snapshots?source_names=pgroup-auto&sort=created-&limit=3`: latest `created: 1787587920113`. `GET /protection-groups/tags?resource_names=pgroup-auto` returns an empty item list.
- **Recommended Action:** Create a dedicated `aen-sql-25-d-pg` on `sn1-x90r2-f06-27`, move the instance's six data volumes into it, set the snapshot and replication schedules to the tier cadence, tag the PG with `sql_instance=aen-sql-25-d`, and configure replication to `sn1-c60-e12-16`. Then remove the volumes from `pgroup-auto`.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 14
- **Status:** Open · **Blocked By:** Cadence target depends on the unresolved tier classification; sequence after INC0104612 restores a DR target
- **Notes:** `pgroup-auto` is recorded in the expected-placement table as known non-compliance. It is not the standard - it is what this ticket exists to fix.

### INC0104633 — HIGH: filesystem `aen-sqlbackups` on sn1-s200-c09-33 — database backup share is open to every host on the network

- **Affected Resource:** filesystem `aen-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `aen-sqlbackups` holds SQL Server backups and is exported with SMB share policy `_smb_share_allow_everyone`, which grants any host on the network read and delete access to the backups. Required - export and share policies scoped to the hosts that legitimately write or read these backups. This is an access-control finding against the backup chain, not a general hygiene note.
- **Evidence:** `get_filesystems_multi_tool` on sn1-s200-c09-33: `smb.share_policy.name: "_smb_share_allow_everyone"`. Confirmed against `GET /file-systems/policies-all?member_names=aen-sqlbackups`.
- **Recommended Action:** Replace the world-open policy with a scoped one naming the SQL Server hosts and backup infrastructure. For NFS, replace `*(rw,no_root_squash)` with an explicit client list and `root-squash`. Validate backup jobs still complete after the change.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Medium · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 16
- **Status:** Open · **Blocked By:** Needs a brief coordination window with the DBA team to confirm backup job client addresses
- **Notes:** These values are platform defaults, not decisions - which is why they are easy to miss.

### INC0104634 — HIGH: filesystem `ayun-sqlbackups` on sn1-s200-c09-33 — database backup share is open to every host on the network

- **Affected Resource:** filesystem `ayun-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `ayun-sqlbackups` holds SQL Server backups and is exported with NFS rule `*(rw,no_root_squash)`, which grants any host on the network read and delete access to the backups. Required - export and share policies scoped to the hosts that legitimately write or read these backups. This is an access-control finding against the backup chain, not a general hygiene note.
- **Evidence:** `get_filesystems_multi_tool` on sn1-s200-c09-33: `nfs.rules: "*(rw,no_root_squash)"`. Confirmed against `GET /file-systems/policies-all?member_names=ayun-sqlbackups`.
- **Recommended Action:** Replace the world-open policy with a scoped one naming the SQL Server hosts and backup infrastructure. For NFS, replace `*(rw,no_root_squash)` with an explicit client list and `root-squash`. Validate backup jobs still complete after the change.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Medium · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 16
- **Status:** Open · **Blocked By:** Needs a brief coordination window with the DBA team to confirm backup job client addresses
- **Notes:** These values are platform defaults, not decisions - which is why they are easy to miss.

### INC0104635 — HIGH: filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33 — database backup share is open to every host on the network

- **Affected Resource:** filesystem `joe-demo-sqlbackups` on sn1-s200-c09-33
- **Finding:** Observed - filesystem `joe-demo-sqlbackups` holds SQL Server backups and is exported with SMB share policy `_smb_share_allow_everyone`, which grants any host on the network read and delete access to the backups. Required - export and share policies scoped to the hosts that legitimately write or read these backups. This is an access-control finding against the backup chain, not a general hygiene note.
- **Evidence:** `get_filesystems_multi_tool` on sn1-s200-c09-33: `smb.share_policy.name: "_smb_share_allow_everyone"`. Confirmed against `GET /file-systems/policies-all?member_names=joe-demo-sqlbackups`.
- **Recommended Action:** Replace the world-open policy with a scoped one naming the SQL Server hosts and backup infrastructure. For NFS, replace `*(rw,no_root_squash)` with an explicit client list and `root-squash`. Validate backup jobs still complete after the change.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Medium · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 16
- **Status:** Open · **Blocked By:** Needs a brief coordination window with the DBA team to confirm backup job client addresses
- **Notes:** These values are platform defaults, not decisions - which is why they are easy to miss.

### INC0104636 — HIGH: filesystem `aen-sqlbackups` on slc6-fbs200-n3-b35-12 — database backup share is open to every host on the network

- **Affected Resource:** filesystem `aen-sqlbackups` on slc6-fbs200-n3-b35-12
- **Finding:** Observed - filesystem `aen-sqlbackups` holds SQL Server backups and is exported with NFS rule `*(rw,no_root_squash)`, which grants any host on the network read and delete access to the backups. Required - export and share policies scoped to the hosts that legitimately write or read these backups. This is an access-control finding against the backup chain, not a general hygiene note.
- **Evidence:** `get_filesystems_multi_tool` on slc6-fbs200-n3-b35-12: `nfs.rules: "*(rw,no_root_squash)"`. Confirmed against `GET /file-systems/policies-all?member_names=aen-sqlbackups`.
- **Recommended Action:** Replace the world-open policy with a scoped one naming the SQL Server hosts and backup infrastructure. For NFS, replace `*(rw,no_root_squash)` with an explicit client list and `root-squash`. Validate backup jobs still complete after the change.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Medium · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 16
- **Status:** Open · **Blocked By:** Needs a brief coordination window with the DBA team to confirm backup job client addresses
- **Notes:** These values are platform defaults, not decisions - which is why they are easy to miss.

### INC0104637 — HIGH: aen-sql-25-a — cluster pair does not span two production zones

- **Affected Resource:** aen-sql-25-a
- **Finding:** Observed - aen-sql-25-a and aen-sql-25-b form Pair 1, and both resolve to **PROD-AZ3** (sn1-x90r2-f07-27: both members are on the same array). Required - both members of a cluster pair must resolve to different production zones. A single zone failure takes out both members, so the HA pairing provides no protection against it.
- **Evidence:** Volume-to-array mapping via `get_volumes_multi_tool` with `filter=contains(name,'aen-sql')`, then array-to-zone resolution through the Fleet topology table in [`skills/00-reference.md`](../../skills/00-reference.md). aen-sql-25-a -> sn1-x90r2-f07-27 -> PROD-AZ3.
- **Recommended Action:** Relocate one member of Pair 1 to a different PROD zone. Candidate destinations with headroom: `sn1-x90r2-f05-27` or `sn1-x90r2-f05-33` (PROD-AZ2, but see INC0104639 regarding their fleet membership), or the other PROD-AZ1/AZ3 arrays. Requires a coordinated migration and an application maintenance window.
- **Severity:** HIGH · **Effort:** High · **Risk:** High · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 18
- **Status:** Open · **Blocked By:** Requires an App team maintenance window; destination array choice depends on INC0104639 / INC0104640
- **Notes:** Zone must be resolved at the zone level, not the array level. Pair 2 is the instructive case - two different arrays still violate the requirement because both are PROD-AZ1.

### INC0104638 — HIGH: aen-sql-25-c — cluster pair does not span two production zones

- **Affected Resource:** aen-sql-25-c
- **Finding:** Observed - aen-sql-25-c and aen-sql-25-d form Pair 2, and both resolve to **PROD-AZ1** (sn1-x90r2-f06-33 and sn1-x90r2-f06-27: the members are on two different arrays that share a zone). Required - both members of a cluster pair must resolve to different production zones. A single zone failure takes out both members, so the HA pairing provides no protection against it.
- **Evidence:** Volume-to-array mapping via `get_volumes_multi_tool` with `filter=contains(name,'aen-sql')`, then array-to-zone resolution through the Fleet topology table in [`skills/00-reference.md`](../../skills/00-reference.md). aen-sql-25-c -> sn1-x90r2-f06-33 -> PROD-AZ1.
- **Recommended Action:** Relocate one member of Pair 2 to a different PROD zone. Candidate destinations with headroom: `sn1-x90r2-f05-27` or `sn1-x90r2-f05-33` (PROD-AZ2, but see INC0104639 regarding their fleet membership), or the other PROD-AZ1/AZ3 arrays. Requires a coordinated migration and an application maintenance window.
- **Severity:** HIGH · **Effort:** High · **Risk:** High · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 19
- **Status:** Open · **Blocked By:** Requires an App team maintenance window; destination array choice depends on INC0104639 / INC0104640
- **Notes:** Zone must be resolved at the zone level, not the array level. Pair 2 is the instructive case - two different arrays still violate the requirement because both are PROD-AZ1.

### INC0104639 — HIGH: sn1-x90r2-f05-27 — configured array is not a fleet member - no fleet-wide alerting or reporting

- **Affected Resource:** sn1-x90r2-f05-27
- **Finding:** Observed - sn1-x90r2-f05-27 (PROD-AZ2, Purity 6.9.5) answers direct API calls and appears in `list_arrays`, but is absent from `get_fleet_overview` and holds no fleet-management links. It carries production replication traffic (async-replication from sn1-c60-e12-16 and sync-replication with sn1-x90r2-f05-33). Required - either fleet membership, so the array appears in fleet-wide alerting and compliance reporting, or a documented exception with a named owner and an alternative monitoring path.
- **Evidence:** `list_arrays` includes `sn1-x90r2-f05-27`; `get_fleet_overview(brief=false)` returns 6 members and does not. `GET /array-connections` on the array returns only async/sync replication entries and no `type: fleet-management` link. Direct `GET /arrays` returns `version: "6.9.5"`.
- **Recommended Action:** Join `sn1-x90r2-f05-27` to fleet `fsa-lab-fleet1`, or record a formal monitoring exception. Note the array is two Purity trains behind the fleet, which may gate joining - confirm the minimum fleet version before scheduling.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 17
- **Status:** Open · **Blocked By:** May be gated on the Purity upgrade in TASK0092210 if fleet membership has a minimum version
- **Notes:** This gap is why INC0104626 (a failed drive on f05-33) never surfaced in a fleet-wide report.

### INC0104640 — HIGH: sn1-x90r2-f05-33 — configured array is not a fleet member - no fleet-wide alerting or reporting

- **Affected Resource:** sn1-x90r2-f05-33
- **Finding:** Observed - sn1-x90r2-f05-33 (PROD-AZ2, Purity 6.9.5) answers direct API calls and appears in `list_arrays`, but is absent from `get_fleet_overview` and holds no fleet-management links. It carries production replication traffic (sync-replication from sn1-x90r2-f07-27, which hosts production Pair 1). Required - either fleet membership, so the array appears in fleet-wide alerting and compliance reporting, or a documented exception with a named owner and an alternative monitoring path.
- **Evidence:** `list_arrays` includes `sn1-x90r2-f05-33`; `get_fleet_overview(brief=false)` returns 6 members and does not. `GET /array-connections` on the array returns only async/sync replication entries and no `type: fleet-management` link. Direct `GET /arrays` returns `version: "6.9.5"`.
- **Recommended Action:** Join `sn1-x90r2-f05-33` to fleet `fsa-lab-fleet1`, or record a formal monitoring exception. Note the array is two Purity trains behind the fleet, which may gate joining - confirm the minimum fleet version before scheduling.
- **Severity:** HIGH · **Effort:** Medium · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 17
- **Status:** Open · **Blocked By:** May be gated on the Purity upgrade in TASK0092210 if fleet membership has a minimum version
- **Notes:** This gap is why INC0104626 (a failed drive on f05-33) never surfaced in a fleet-wide report.

### INC0104641 — HIGH: sn1-x90r2-f06-33 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-x90r2-f06-33
- **Finding:** Observed - sn1-x90r2-f06-33 (FA, PROD-AZ1) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds protection group `aen-sql-25-c-pg`. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-x90r2-f06-33`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-x90r2-f06-33` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.

### INC0104642 — HIGH: sn1-x90r2-f06-27 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-x90r2-f06-27
- **Finding:** Observed - sn1-x90r2-f06-27 (FA, PROD-AZ1) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds protection group `pgroup-auto` (holding aen-sql-25-d). Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-x90r2-f06-27`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-x90r2-f06-27` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.

### INC0104643 — HIGH: sn1-x90r2-f07-27 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-x90r2-f07-27
- **Finding:** Observed - sn1-x90r2-f07-27 (FA, PROD-AZ3) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds protection groups `aen-sql-25-a-pg` and `aen-sql-25-b-pg`. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-x90r2-f07-27`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-x90r2-f07-27` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.

### INC0104644 — HIGH: sn1-c60-e12-16 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-c60-e12-16
- **Finding:** Observed - sn1-c60-e12-16 (FA, DR-AZ1) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds the replicated DR copies of aen-sql-25-a-pg and aen-sql-25-b-pg. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-c60-e12-16`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-c60-e12-16` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.

### INC0104645 — HIGH: sn1-s200-c09-33 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-s200-c09-33
- **Finding:** Observed - sn1-s200-c09-33 (FB, PROD-AZ1) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds 3 backup landing filesystems and 4 database backup buckets. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-s200-c09-33`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-s200-c09-33` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.

### INC0104646 — HIGH: slc6-fbs200-n3-b35-12 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** slc6-fbs200-n3-b35-12
- **Finding:** Observed - slc6-fbs200-n3-b35-12 (FB, DR-AZ1) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds the DR replica of filesystem `aen-sqlbackups`. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `slc6-fbs200-n3-b35-12`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `slc6-fbs200-n3-b35-12` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Emergency
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array. On this array it is also the mitigation that limits the blast radius of INC0104611.

### INC0104647 — HIGH: sn1-x90r2-f05-27 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-x90r2-f05-27
- **Finding:** Observed - sn1-x90r2-f05-27 (FA, PROD-AZ2) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds no SQL estate objects. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-x90r2-f05-27`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-x90r2-f05-27` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.

### INC0104648 — HIGH: sn1-x90r2-f05-33 — SafeMode disabled - manual eradication permitted array-wide

- **Affected Resource:** sn1-x90r2-f05-33
- **Finding:** Observed - sn1-x90r2-f05-33 (FA, PROD-AZ2) reports `eradication_config.manual_eradication: "all-enabled"` at array level, and every protection group, filesystem and bucket assessed on it also reports `manual_eradication: "enabled"` with `retention_lock: "unlocked"`. This array holds no SQL estate objects, but a sync copy of production Pair 1. Required - `manual_eradication` set to `disabled` and `retention_lock` ratcheted, so a compromised or mistaken administrator cannot eradicate data inside the delay window. The field describes whether eradication is *permitted*, so these values are the unprotected state.
- **Evidence:** Direct `GET /arrays` on `sn1-x90r2-f05-33`: `eradication_config.manual_eradication: "all-enabled"`. Object-level confirmation via `GET /protection-groups`, `get_filesystems_multi_tool` and `GET /buckets` as applicable - all assessed objects return `manual_eradication: "enabled"`. Fleet-wide the count is 20 of 20 objects unprotected.
- **Recommended Action:** Set `manual_eradication` to `disabled` at array level and on each protection group, filesystem and bucket on this array. Ratchet `retention_lock` where the field exists. Closure for this ticket is SafeMode fully enabled on `sn1-x90r2-f05-33` and all its objects.
- **Severity:** HIGH · **Effort:** Low · **Risk:** Low · **Change Type:** Planned
- **Owning Team:** Storage
- **Source:** Consolidated Remediation Plan 2026-08-24, priority 10
- **Status:** Open · **Blocked By:** Not blocked - newly raised
- **Notes:** Scoped per array so it closes cleanly; the fleet-wide finding is one posture gap, but the remediation is executed array by array.
