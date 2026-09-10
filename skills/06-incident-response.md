---
applyTo: "**"
description: "Incident Response SOP: blast radius analysis, availability-zone HA verification, snapshot/recovery freeze safety, guided runbooks, and escalation"
---

# Skill: Incident Response

**When this applies**: an array is degraded or failing, a recovery is requested, a destructive operation needs to run, or a problem surfaces that the agent cannot remediate on its own.

## Blast Radius Analysis

**Procedure** — when an array is degraded or failing:
1. Identify all volumes hosted on the affected array.
2. Map volumes to their tagged SQL instances and databases (using volume tags: `sql_instance`, `databases`, `windows_drive`).
3. Map volumes to their VMware vVols and guest VMs.
4. Report the complete list of affected hosts, VMs, databases, and applications.
5. Evaluate HA placement against [Availability Zone Requirements](00-reference.md#availability-zone-requirements) — the SQL instance map, expected-placement table, and fleet topology table live there since Fleet Awareness's Query Scoping and Compliance & Audit's DR-target resolution also depend on them.

## Snapshot & Recovery

**Procedure** — for any recovery request:
1. Find the most recent restorable snapshot for the target database or volume.
2. Verify the snapshot was successfully replicated before declaring recovery readiness.
3. Check that the target (DR) array has sufficient free capacity to absorb a restore.
4. Confirm the snapshot's Protection Group tags: `DatabaseName`, `SQLInstanceName`, `BackupTimestamp`, `BackupType`, `BackupUrl`, `SnapshotMode`, `BackupSoftware`.

**Single database snapshot flow:**
1. Find volumes tagged with the target `DatabaseName`.
2. Confirm all volumes share a common Protection Group. If they do not, stop — a snapshot spanning Protection Groups is not crash-consistent.
3. Suspend the database: `ALTER DATABASE {db} SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON`.
4. Create a PG snapshot via `fetch_tool`: `POST /protection-group-snapshots?source_names={pg}[&replicate_now=true]`.
5. Run `BACKUP DATABASE {db} TO DISK='...' WITH METADATA_ONLY` on the SQL Server. **This is what releases the I/O freeze.**
6. Tag `BackupUrl` onto the resulting snapshot.

**Hard boundaries — freeze safety, mandatory.** Steps 3–5 hold database I/O frozen. `SUSPEND_FOR_SNAPSHOT_BACKUP` does not time out on its own; it holds until a `METADATA_ONLY` backup completes. A failure between steps 3 and 5 therefore leaves the database unavailable, which is an outage rather than a failed job.

- Treat steps 4–5 as a guarded block. On **any** failure, timeout, or interruption in step 4, immediately run step 5 (or `ALTER DATABASE {db} SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF`) to release the freeze **before** reporting the error.
- Never abandon the flow mid-freeze. Never ask the user a question while a freeze is held — release first, then report.
- Keep total freeze duration under 30 seconds. If step 4 has not returned by then, release the freeze and report the snapshot as failed.
- Report actual freeze duration in the result, so the change record shows the I/O impact window.
- Before starting, confirm no other suspend is already active on the target database.

**Multi-database / server snapshot flow:**
- Use `mode=group` (multiple databases) or `mode=server` (all databases on an instance).
- The `GROUP` and `SERVER` backup must run on the same SQL connection that issued `SUSPEND_FOR_SNAPSHOT_BACKUP`. Hold that single connection open across the entire sequence — losing it mid-flow is the primary failure mode, and it leaves every database in the group or instance frozen with no session able to release them.
- The same freeze safety rules apply, and the blast radius is larger: a `mode=server` freeze suspends every database on the instance.

## Guided Runbooks

**Procedure** — before any destructive operation (restore, delete, overwrite):
1. State clearly what action will be taken and what will be affected.
2. Require explicit user confirmation.
3. Perform pre-flight checks (capacity, replication status, existing snapshots).
4. Execute the action and report success or failure with evidence.

**Hard boundaries — confirmation-gated tools.** These MCP tools mutate state and require the sequence above before use: `workloads_deploy`, `presets_create`, `presets_update`, `create_placement_recommendation`. Any `fetch_tool` call using a method other than `GET` is also confirmation-gated. All other tools are read-only and may be called freely.

**Exception**: the freeze-release step of a snapshot flow is never gated — releasing a held I/O freeze is a safety action and must happen immediately without waiting for confirmation.

## Escalation

**Procedure** — when the agent identifies a problem it cannot remediate autonomously (e.g., hardware fault, replication link needing network team involvement, capacity requiring procurement):
1. Clearly label the finding as **Requires Human Action**.
2. State which team owns the remediation (Storage, DBA, Network, App, Procurement).
3. Provide the exact context needed to hand off: array name, volume name, error message, and recommended next step.
4. Do not mark the incident resolved until the user confirms the issue is addressed.
