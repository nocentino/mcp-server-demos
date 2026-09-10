---
applyTo: "**"
description: "Shared reference for the Database SRE Agent: fleet/zone topology, field traps that produce false passes, key formulas, and API notes — load alongside any skill file that links here"
---

# Reference

Cross-cutting material shared by every skill file — not a workflow of its own, but load-bearing for all of them.

## Availability Zone Requirements

**Zone assignment must be resolved at the zone level, not the array level.** Two arrays being different does not satisfy a zone requirement — `sn1-x90r2-f06-33` and `sn1-x90r2-f06-27` are both in `PROD-AZ1`, so a pair split across them still violates HA. Always resolve volume → array → zone using the topology table, then compare zones.

**SQL Server instance map:**

| Instance | Role | Cluster pair | Required zone | Partner |
|---|:---:|:---:|---|---|
| aen-sql-25-a | Production | Pair 1 | any PROD zone ≠ partner's | aen-sql-25-b |
| aen-sql-25-b | Production | Pair 1 | any PROD zone ≠ partner's | aen-sql-25-a |
| aen-sql-25-c | Production | Pair 2 | any PROD zone ≠ partner's | aen-sql-25-d |
| aen-sql-25-d | Production | Pair 2 | any PROD zone ≠ partner's | aen-sql-25-c |
| aen-sql-25-dr | Disaster recovery | — | DR-AZ1 | — |

**Requirements:**
- Both members of a cluster pair must resolve to different production zones. Pair 1 is `aen-sql-25-a` / `aen-sql-25-b`; Pair 2 is `aen-sql-25-c` / `aen-sql-25-d`.
- Instances whose names end in `DR` must be in a DR zone, never a production zone.
- Production instances must not be placed in a DR zone.
- An instance not listed above is **unmapped** — report it rather than assuming its role or pair.

**Expected placement — verify, do not search.**

| Instance | Expected array | Expected volume group | Expected PG |
|---|---|---|---|
| aen-sql-25-a | sn1-x90r2-f07-27 | `vvol-aen-sql-25-a-*-vg` | `aen-sql-25-a-pg` |
| aen-sql-25-b | sn1-x90r2-f07-27 | `vvol-aen-sql-25-b-*-vg` | `aen-sql-25-b-pg` |
| aen-sql-25-c | sn1-x90r2-f06-33 | `vvol-aen-sql-25-c-*-vg` | `aen-sql-25-c-pg` |
| aen-sql-25-d | sn1-x90r2-f06-27 | `vvol-aen-sql-25-d-*-vg` | **none — non-compliant, currently pooled in `pgroup-auto`** |
| aen-sql-25-dr | sn1-c60-e12-16 | `vvol-aen-sql-25-dr-*-vg` | **none — non-compliant, no PG exists** |

These are the **expected** locations, maintained by hand alongside the topology table. Start every instance-scoped workflow by querying the expected array directly, and treat the result as a verification rather than a discovery:

- **Match** → proceed. One targeted call, no fleet sweep.
- **Mismatch or not found** → that is a **finding in its own right** (an instance moved, or the map is stale). Report it, then fall back to a fleet-wide sweep to locate the instance, and say in the report that you did so.
- The last two rows record known non-compliance deliberately. Do **not** read `pgroup-auto` or "no PG" as the standard — the standard is in [Provisioning Standards](03-provisioning.md#provisioning-standards), and these two rows are what the Remediation Plan exists to fix.

**Do not discover placement by sweeping `sql_instance` tags.** Two of the five instances (`aen-sql-25-c`, `aen-sql-25-dr`) carry no `sql_instance` tag at all, so a tag sweep silently misses them while costing a call per array. The tag is for confirming ownership once you are on the right array, not for finding the array.

Resolve each instance's actual zone by mapping its volumes to their host array, then looking that array up in the topology table below. If a single instance's volumes span two zones, that is itself a finding — report it.

**Fleet topology:**

| Array | Type | Site | Zone |
|---|:---:|---|---|
| sn1-x90r2-f06-33 | FA | Main prod | PROD-AZ1 |
| sn1-x90r2-f06-27 | FA | Main prod | PROD-AZ1 |
| sn1-x90r2-f05-27 | FA | Main prod | PROD-AZ2 |
| sn1-x90r2-f05-33 | FA | Main prod | PROD-AZ2 |
| sn1-x90r2-f07-27 | FA | Main prod | PROD-AZ3 |
| sn1-c60-e12-16 | FA | DR | DR-AZ1 |
| sn1-s200-c09-33 | FB | Main prod | PROD-AZ1 |
| slc6-fbs200-n3-b35-12 | FB | DR | DR-AZ1 |

Zone labels are site-qualified deliberately: an unqualified "AZ1" is ambiguous across the prod and DR sites.

Every array in the table above now carries a site and zone. An array that appears in `list_arrays` or `get_fleet_overview` but **not** in this table cannot be placed by blast-radius analysis — flag any workload found on it as **unzoned**, report the gap, and do not infer a zone from the array's name prefix.

**FlashBlade zone placement.** The two FlashBlades are file and object platforms, so the cluster-pair rules in the SQL Server instance map do not apply to them. Their zone assignment exists so that blast-radius analysis can resolve file and object workloads to a failure domain, and so that `sn1-s200-c09-33` (PROD-AZ1) and `slc6-fbs200-n3-b35-12` (DR-AZ1) are correctly understood as a cross-site pair rather than two unplaced arrays. FlashBlade-to-FlashBlade replication between them therefore crosses sites and satisfies a DR requirement; replication that stays within either site does not.

---

## Field Traps — These Produce False Passes

Every entry here is a field whose plain reading yields a confident wrong answer. These are cross-cutting: a trap discovered in a capacity report applies to a compliance report, and vice versa. **Check this list before writing any pass, any zero, or any empty result.**

### Reading protection state

**Protection Group retention is not the `days` field.** Purity expresses retention as three fields together: keep *all* snapshots for `all_for_sec`, then keep `per_day` snapshots per day for a further `days` days. When `per_day` is `0` there is no per-day tier, so **effective retention is `all_for_sec` alone and the `days` value is inert.** Reading `.days` in isolation passes PGs that fail policy — one PG reported `source_retention.days: 7` against `all_for_sec: 259200` and `per_day: 0`, which is 3 days of real retention, not 7. Always derive:

```
effective_retention = all_for_sec + (days if per_day > 0 else 0)
```

Report the derived value and the raw fields side by side so a reviewer can check the arithmetic. Compare the derived value against the binding floors in [Data Protection Compliance](02-compliance-audit.md#data-protection-compliance), never the raw `days`.

**`manual_eradication: "enabled"` means SafeMode is OFF.** The field describes whether manual eradication is *permitted*, so `enabled` is the unprotected state and `disabled` is the protected one. This reads backwards from every other boolean on the platform. Never report `enabled` as a pass. Corroborate with `retention_lock` (`ratcheted` = protected, `unlocked` = not) and, on buckets, `object_lock_config.enabled`.

**A replica link with `status: "idle"` is not necessarily healthy.** `idle` means "no transfer in progress right now", not "up to date". Always read `lag` and `recovery_point` alongside it — a link can report `idle` while being months behind; one reported `idle` at 480 days of lag. Compute lag in human units and compare it against the tier budget; a link whose `recovery_point` is older than the RPO window is a **failed** link regardless of status. Only `unhealthy` and `paused` are self-announcing failures; a stale `idle` link is silent.

**`recovery_point: 0` with `lag: null` means the link has never transferred.** A replica link in this state exists, points at the right target, and reports `status: "idle"` — so an existence check passes it and a status check passes it, while there is no recovery point at any age. Check `policies: []` alongside it: a replica link with no replication policy attached has no schedule, so nothing will ever transfer. Treat a null lag as **infinite lag**, never as "no lag". This is the half-configured case, and it is more dangerous than no link at all because it appears on a report as configured.

**A replication schedule can be enabled with zero targets.** `replication_schedule.enabled: true` alongside `target_count: 0` means snapshots are scheduled to replicate nowhere. This passes any check that reads the schedule flag alone, and it is what a spreadsheet audit records as "replication: enabled".

**`space.snapshots: 0` means no snapshots exist.** It is not a rounding artifact and not "small". Combined with an attached snapshot *policy*, zero snapshots means the policy has no enabled rules or was attached after the fact — check both.

**An export policy is not a protection policy.** `/file-systems/policies-all` returns NFS export, SMB share, and SMB client policies in the same list as snapshot and replication policies. A filesystem with three policies attached can still have zero protection. Filter by `resource_type` before concluding anything.

**A replication target is not a DR target until you resolve its zone.** Replication that lands on an array in the *same* zone, or on an array absent from the Fleet topology table, does not satisfy a DR requirement. Resolve every target through the topology table before recording a pass.

### Reading performance and capacity

**A latency of `0` means no I/O of that type, not sub-millisecond performance.** An array serving no reads reports `usec_per_read_op: 0`. Render as `—`, never as a pass. An array reporting zero across every performance field is idle, not fast — say so explicitly.

**Latency has near-identical sibling fields.** Each op type exposes `usec_per_read_op`, `service_usec_per_read_op`, `san_usec_per_read_op`, `queue_usec_per_read_op`, plus `local_queue_usec_per_op`. They differ materially — one array reported `usec_per_read_op: 105` against `san_usec_per_read_op: 1990`. Use the total `usec_per_*_op` fields for SLA comparisons; the others decompose *where* latency originates once an outlier is found.

**`total_reduction` is not a data reduction ratio.** It folds in thin provisioning and produces meaningless figures — one array reported `6.50` for `data_reduction` and `13386.5` for `total_reduction`. Report `data_reduction` only.

**`space.thin_provisioning` is a 0–1 savings ratio, not an overcommit multiple.** Overcommit is `used_provisioned / capacity`.

**Platform field sets are not interchangeable.** FlashArray populates `arraysPerformanceFA` / `arraysSpaceFA`; FlashBlade populates `arraysPerformanceFB` / `arraysSpaceFB`. A FlashBlade queried through the FA field names looks empty, not idle. FlashBlade space has no `thin_provisioning` field, so overcommit does not apply there at all.

### Reading query results

**A failed query is not a pass.** See the full rule and its two common failure modes in [Fleet Awareness](01-fleet-awareness.md). Any `*_status` other than `success` renders as **Unknown — query failed**, and is severity-rated for the worst plausible state, not as `LOW`.

**An endpoint that does not exist is not a clean check.** If the tool exposes no endpoint for a control — certificate expiry, for example — report the control as **unverified** and name the missing endpoint. Never let an unaskable question read as a passing answer.

**`include_alerts` is only honored when `brief=false`.** `get_fleet_overview` defaults to `brief=true`. Passing `include_alerts=true` alone returns no alerts and reads as a clean fleet. Always pass both.

**Fleet-routed metadata can be stale.** When an array's fleet-management link is not `connected`, treat every value the gateway reports for it as unverified and confirm directly against the array. One FlashBlade was reported as Purity 4.8.0 by `get_fleet_overview` while the array itself — and its own login banner — reported 4.8.4.

**`sort` is silently ignored on some nested fields.** `sort=space.total_used-` returned filesystems in alphabetical order with no error. When ranking matters, verify the first row really is the extreme, or fetch the full set and rank locally.

**The `total` block in a paginated response is per-page, not per-query.** The same `/file-systems` query reported 2.24 TiB of filesystem space at `limit=15` and 1.99 TiB at `limit=12`; the true array-wide total was 95.60 TiB. Never quote a `total` block as a fleet or array figure without confirming the query was unpaginated — this one understates by more than an order of magnitude.

**Filters match more than you intend.** `contains(name,'pgroup-auto')` also matched pod-scoped groups named `SRM-AC-Pod::pgroup-auto`. Filter on the exact field that identifies the resource — `source.name='pgroup-auto'` — when a substring could span namespaces.

**Buckets and filesystems share a namespace in conversation but not in the API.** A bucket named `aen-sql-backups` and a filesystem named `aen-sqlbackups` are different objects on different endpoints. Report both, and never let one satisfy the other's check.

### Reading access posture

**`_smb_share_allow_everyone` and `*(rw,no_root_squash)` are defaults, not decisions.** On a share holding database backups, either one means any host on the network can read or delete the backups. Report it as an access-control finding against the backup chain, not as a general hygiene note.

**An untagged workload is unclassified, not Tier 3.** A missing `workload_tier` tag must never silently excuse a trading or OLTP volume from Tier 1 checks. Where the `databases` tag names an OLTP workload but the tier heuristic keys only on the instance name, say that the tier is inferred and may be wrong.

---

## Key Formulas & Units

| Metric | Formula | Notes |
|--------|---------|-------|
| Capacity utilization | `(space.total_used / capacity) * 100` | Result in % |
| Read latency | `usec_per_read_op / 1000` | The SLA metric. Converts µs → ms |
| Write latency | `usec_per_write_op / 1000` | The SLA metric |
| Sync-replicated write latency | `usec_per_mirrored_write_op / 1000` | Use for sync-replicated volumes |
| Space | `bytes / 1024^4` | Converts bytes → TiB |
| Data reduction | `space.data_reduction` | Ratio (e.g., 10.94x). Report this one |
| Thin provisioning savings | `space.thin_provisioning` | A 0–1 savings ratio, **not** an overcommit multiple |
| Provisioning overcommit | `space.used_provisioned / capacity` | The actual overcommit multiple |
| Replica link lag | `lag / 1000` | FlashBlade lag is in **ms**. Convert to seconds, then to human units before comparing to an RPO |
| Recovery point age | `now - recovery_point` | `recovery_point` is an epoch **ms** timestamp. Age, not the raw value, is what the RPO test needs |

The formula is only half the answer — several of these fields have near-identical siblings that give a different number. See [Field Traps](#field-traps--these-produce-false-passes).

---

## API Notes

- Arbitrary REST calls against the arrays are issued with `fetch_tool`. Use `get_endpoint_documentation` to confirm an endpoint's shape before calling it, and `get_documentation` for concept-level context.
- URL-encode vVol names and PG names when constructing REST calls: use `urllib.parse.quote(..., safe='')`.
- Remote array tag writes may require direct array calls; gateway batch endpoints cannot route all remote tag operations.
- `insertMany()` in mongosh 2.x returns `{acknowledged, insertedIds}` — no `insertedCount`; use `Object.keys(r.insertedIds).length` to count.
