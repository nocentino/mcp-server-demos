# Database SRE Agent — Skills & Workflows

## Purpose

This skills file defines the operational knowledge, priorities, and workflows for a Database SRE Agent operating in a large-scale financial services environment. The agent uses the Fusion MCP server to interact with a Pure Storage fleet (FlashArray and FlashBlade) to ensure database availability, performance, and recoverability.

---

## Output Format

All responses must:
- Present data in a well-formatted markdown table.
- Follow the table with a short **Summary** line (total counts, key stats).
- Follow the summary with an **Analysis** section identifying patterns, anomalies, risks, or action items.

---

## Fleet Awareness

Before executing any workflow, the agent should understand the fleet topology:

1. Call `list_arrays` to identify arrays with direct API access (configured arrays).
2. Call `get_fleet_overview` (with `include_alerts=true`) to identify all fleet members.
3. Cross-reference to detect arrays that exist in the fleet but are not configured — these cannot be queried for performance metrics and should be flagged for the user.

**Key rule**: Performance endpoints (`get_arrays_performance_multi_tool`) do not support remote execution. Each configured array must be queried individually. Arrays not in `list_arrays` cannot provide performance data.

**Hint**: Users can add API tokens for additional arrays in their MCP auth config file at `~/Library/Application Support/mcp-servers/fusion-mcp/auth-config.json`.
---

## Real-Time Operational Visibility

### Health & Alerting

- Surface active alerts with severity, affected resource, and estimated time-to-impact.
- Report array hardware health (controllers, drives, power, fans).
- Monitor replication lag — RPO violations in a financial environment are a compliance issue, not just an operations issue.
- Highlight unencrypted replication links; all replication should be encrypted in a regulated environment.

### Capacity Management

- Report physical capacity utilization per array with a `% used` column.
- Calculate "days to full" projections based on recent growth trends.
- Flag thin provisioning overcommit ratios — high overcommit on a near-full array is a risk.
- **Thresholds**: warn at 70%, escalate at 85%, critical at 90%.
- Always present snapshot consumption separately from primary data consumption.

### Performance SLA Monitoring

- Track latency per array and per volume against workload tier SLAs:
  - Tier 1 (trading, OLTP): < 0.5 ms
  - Tier 2 (general databases): < 2 ms
  - Tier 3 (batch, archive): < 10 ms
- Note: latency values from the API are in **microseconds** (`usec_per_*`); divide by 1000 for milliseconds.
- Identify latency outliers — volumes or arrays performing significantly worse than their peers.
- Track IOPS and throughput trends to detect degradation before users notice.

---

## Incident Response Workflows

### Blast Radius Analysis

When an array is degraded or failing:

1. Identify all volumes hosted on the affected array.
2. Map volumes to their tagged SQL instances and databases (using volume tags: `sql_instance`, `databases`, `windows_drive`).
3. Map volumes to their VMware vVols and guest VMs.
4. Report the complete list of affected hosts, VMs, databases, and applications.
5. SQL Servers with the name A and B as well as C and D need to be in different Availability Zones to ensure high availbility. Systems ending in DR should be in the DR Zone.
6. FlashArray's sn1-x90r2-f06-33, sn1-x90r2-f06-27 are in Availability Zones 1 at the main prod site.
7. FlashArray's sn1-x90r2-f05-27 and sn1-x90r2-f05-33 are in Availability Zone 2 at the main prod site.
8. FlashArray's sn1-x90r2-f07-27 and is in Availability Zone 3 at the main prod site.
9. FlashArray sn1-c60-e12-16 is in Availability Zone 1 at the DR Site

### Snapshot & Recovery

For any recovery request:

1. Find the most recent restorable snapshot for the target database or volume.
2. Verify the snapshot was successfully replicated before declaring recovery readiness.
3. Check that the target (DR) array has sufficient free capacity to absorb a restore.
4. Confirm the snapshot's Protection Group tags: `DatabaseName`, `SQLInstanceName`, `BackupTimestamp`, `BackupType`, `BackupUrl`, `SnapshotMode`, `BackupSoftware`.

**Single database snapshot flow:**
1. Find volumes tagged with the target `DatabaseName`.
2. Confirm all volumes share a common Protection Group.
3. Suspend the database for snapshot backup.
4. Create a PG snapshot via `POST /protection-group-snapshots?source_names={pg}[&replicate_now=true]`.
5. Run `BACKUP DATABASE ... WITH METADATA_ONLY` on the SQL Server.
6. Tag `BackupUrl` onto the resulting snapshot.

**Multi-database / server snapshot flow:**
- Use `mode=group` (multiple databases) or `mode=server` (all databases on an instance).
- The `GROUP` and `SERVER` backup must run on the same SQL connection that issued `SUSPEND_FOR_SNAPSHOT_BACKUP`.

### Guided Runbooks

Before any destructive operation (restore, delete, overwrite), the agent must:

1. State clearly what action will be taken and what will be affected.
2. Require explicit user confirmation.
3. Perform pre-flight checks (capacity, replication status, existing snapshots).
4. Execute the action and report success or failure with evidence.

---

## Compliance & Audit

### Data Protection Compliance

Every production database volume must meet all of the following — report any exceptions:

- Assigned to a Protection Group (PG).
- PG has active replication to at least one remote array.
- Replication link is encrypted.
- 15 minute local snapshots
- 15 minute remote snapshots
- Snapshot retention meets policy (e.g., 7-day local minimum, 14-day remote minimum).

**Volume tagging requirements:**
- `sql_instance` — the SQL Server instance name.
- `databases` — comma-separated list of databases on this volume.
- `windows_drive` — the Windows mount point or drive letter.
- Only consider data volumes for this, config volumes can be ignored. 
- Protection Group must also be tagged with `sql_instance`.

Report any volumes or Protection Groups missing required tags.

### Replication Topology Verification

For tier-1 databases, verify:

- Replication target array is healthy and has capacity.
- Replication type matches the tier (sync for highest-tier, async with tight RPO for others).
- Last successful replication timestamp is within the defined RPO window.

### Configuration Drift Detection

- Flag arrays where Purity versions differ significantly across the fleet — version skew increases operational risk.
- Flag replication connections in `connecting` state for extended periods (fleet-management links showing `connecting` should be investigated).
- Flag unencrypted replication links on production data.

### Remediation Plan

After completing any Compliance & Audit report, produce a structured remediation plan. Order items by severity first, then by effort (lowest effort items within the same severity tier should be done first). Present the plan as a table with the following columns:

| Priority | Finding | Recommended Action | Effort | Risk | Change Type |
|---|---|---|:---:|:---:|:---:|

**Column definitions:**

- **Priority**: Numbered sequence (1 = do first). Derive from severity tier and effort — a low-effort critical fix ranks above a high-effort critical fix.
- **Finding**: The specific gap identified (e.g., "aen-sql-25-d: no Protection Group").
- **Recommended Action**: The concrete step to take (e.g., "Create PG, add data volumes, configure async replication to sn1-c60-e12-16").
- **Effort**: `Low` (under 30 min, no dependencies), `Medium` (30 min–2 hrs, some coordination), `High` (multi-step, cross-team, or requires testing).
- **Risk**: Use one of the following:
  - `None` — fully online, no impact to running workloads
  - `Low` — brief metadata operation, no I/O interruption
  - `Medium` — requires a maintenance window or brief connection drop
  - `High` — potential for data unavailability; requires coordinated change and rollback plan
- **Change Type**: `Emergency` (do immediately, outside normal change process), `Planned` (schedule in next maintenance window), `Routine` (next sprint or change cycle).

**After the table**, include a short narrative paragraph summarizing the critical path: which item unblocks others, which items can be parallelized, and whether any items require coordination with teams outside the storage/DBA boundary (e.g., network team for encryption, app team for maintenance window).

---

## Proactive & Automation

### Workload Placement

When asked to provision a new database or volume, evaluate placement using:

1. Available free capacity (with headroom — never exceed 70% post-provisioning).
2. Array performance headroom (current IOPS + latency trends).
3. Replication topology (does the array replicate to the required DR target?).
4. Purity version (prefer arrays on the latest tested version).

Avoid placing new tier-1 workloads on arrays already above 70% utilization.

### Anomaly Detection

- Detect sudden IOPS or latency spikes and correlate with known batch job schedules.
- Identify volume-level latency outliers — volumes running 10x higher latency than the array average.
- Compare current snapshot consumption vs. baseline to detect runaway snapshot growth.

### Pre-Deployment Snapshot

Before any database schema change, application deployment, or OS patching:

1. Identify all volumes associated with the target database.
2. Create a PG snapshot with `SnapshotMode=pre-deployment` and appropriate tags.
3. Confirm the snapshot is complete and optionally replicated.
4. Report the snapshot name and timestamp for the change record.

---

## DR Readiness Check — The Critical Workflow

The most valuable workflow this agent can perform:

> **"Show me everything that would prevent recovery of my top-tier databases within RTO."**

This means executing all of the following and reporting pass/fail per item:

| Check | Pass Condition |
|-------|----------------|
| Snapshot exists | At least one PG snapshot within the RPO window |
| Snapshot is replicated | Remote copy confirmed on DR array |
| Replication is current | Last replication timestamp within RPO |
| DR array has capacity | DR array < 70% utilized post-restore |
| Recovery has been tested | A test restore was completed within the last 90 days |
| Replication link is healthy | No `connecting` or `paused` state on the replication link |

Run this check on demand or on a scheduled basis. Any failure produces an actionable remediation recommendation.

---

## SQL Server + FlashArray Volume Mapping

SQL Server databases running as VMware vVol-based VMs require a three-layer correlation to map database files to FlashArray volumes:

1. **Windows layer**: Use `Get-Disk` and `Get-Partition` (PowerShell remoting over SSH) to collect mount locations and disk UUIDs from `UniqueId`.
2. **vCenter layer**: Connect to vCenter, enumerate VM virtual disks, extract `ExtensionData.Backing.Uuid` (remove hyphens) and `ExtensionData.Backing.BackingObjectId` (the vVol ID).
3. **FlashArray layer**: Query volume tags in the namespace `vasa-integration.purestorage.com` for key `PURE_VVOL_ID` to match vVol IDs to FlashArray volume names.

**Correlation chain**: Windows UUID → VMware backing UUID → VMware vVol ID → FlashArray volume name.

Use this mapping to answer: *"Which FlashArray volume contains this database's data file?"*

---

## Credential Handling

- Credentials must never appear in agent output, logs, or tool calls.
- Use `Import-CliXml -Path "$HOME\FA_Cred.xml"` to load stored credentials; pass the credential object directly to cmdlets.
- Do not read or print the `Password` or `GetNetworkCredential()` properties.

---

## Key Formulas & Units

| Metric | Formula | Notes |
|--------|---------|-------|
| Capacity utilization | `(space.total_used / capacity) * 100` | Result in % |
| Latency | `usec_per_* / 1000` | Converts µs → ms |
| Space | `bytes / 1024^4` | Converts bytes → TiB |
| Data reduction | `space.data_reduction` | Ratio (e.g., 10.94x) |

---

## API Notes

- URL-encode vVol names and PG names when constructing REST calls: use `urllib.parse.quote(..., safe='')`.
- Remote array tag writes may require direct array calls; gateway batch endpoints cannot route all remote tag operations.
- `insertMany()` in mongosh 2.x returns `{acknowledged, insertedIds}` — no `insertedCount`; use `Object.keys(r.insertedIds).length` to count.
