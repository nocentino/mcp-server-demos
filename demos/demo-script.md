# Database SRE Agent Demo
## Claude Code + Pure Storage Fusion MCP Server

**Audience:** technical — you, a colleague, or a hands-on engineer at a whiteboard
**Covers:** fleet and SQL Server discovery, volume correlation, operational visibility, snapshots
**Companion:** [`customer-runbook.md`](customer-runbook.md) — the customer-facing 25-minute
run-of-show. It is a *different demo*, not a different numbering of this one: it covers config
drift, presets, dashboards, and ticketing, and adds talk tracks and time boxes. Only fleet discovery
and compliance & audit appear in both. Use this file to learn the workflows; use the run-book to
present them.

This demo walks through using Claude Code as a Database SRE agent against a live Pure Storage fleet.
Prerequisites: Fusion MCP server configured with API tokens in `~/Library/Application Support/mcp-servers/fusion-mcp/auth-config.json`, and the `skills/` directory in the repository root (see [`skills/00-global.md`](../skills/00-global.md) for the full routing table).

---

## Step 1 — Fleet Discovery

**Skill file:** [`skills/01-fleet-awareness.md`](../skills/01-fleet-awareness.md)

**What this does:** Establishes fleet topology by querying all configured arrays for their Purity versions and hardware model. This is the baseline before any operational workflow.

```
Tell me what arrays are in this environment, including their Purity versions.
```

**Output format instruction** (include with every subsequent prompt if needed):

```
Always give me output in a pleasing tabular format with a summary, and your analysis of the data.
```

---

## Step 2 — SQL Server Discovery via MSSQL Extension

**What this does:** Pulls the list of known SQL Server connections from the MSSQL VS Code extension connection store. This gives the agent a list of SQL instances to work with before it ever touches the storage layer.

```
Now give me a listing of the SQL Servers that you know about using the MSSQL VS Code extension.

Here is a listing of SQL Servers in my environment
aen-sql-25-a
aen-sql-25-b
aen-sql-25-c
aen-sql-25-d
aen-sql-25-dr
```

---

## Step 3 — SQL Server Volume Discovery on FlashArray

**Skill file:** [`skills/01-fleet-awareness.md`](../skills/01-fleet-awareness.md) — Query Scoping

**What this does:** Correlates SQL Server instance names to FlashArray volumes. Since the SQL Servers are VMware VMs using vVols, the SQL instance name is embedded in the FlashArray volume name. The prompt instructs the agent to use array-side REST `contains` filtering instead of pulling all volumes locally — important for large fleets.

```
The SQL Servers that have aen-sql-25 contained in their name are on FlashArray. All of my SQL Servers are VMware VMs using vVols, so the name of the SQL instance is also contained in the FlashArray volume name. Then give me a listing of all of my SQL Server volumes in my fleet. Use array side REST filtering so that you don't have to pull a giant list of volumes locally, don't use wildcards use the contains parameter for the search.
```

---

## Step 4 — Real-Time Operational Visibility Report

**Skill file:** [`skills/04-operational-visibility.md`](../skills/04-operational-visibility.md)

**What this does:** Runs the Real-Time Operational Visibility workflow covering hardware health, active alerts, capacity utilization, and performance against tier SLA thresholds.

**Note:** `CLAUDE.md` bootstraps the agent automatically at session start and points to `skills/00-global.md`. The prompt below names the specific skill file explicitly so the audience can see what's driving the agent's behavior.

```
You're a Database SRE agent. Your skills and workflows are defined in @skills/04-operational-visibility.md. Produce the "Real-Time Operational Visibility" report.
```

---

## Step 5 — Compliance & Audit Report

**Skill file:** [`skills/02-compliance-audit.md`](../skills/02-compliance-audit.md)

**What this does:** Runs the Compliance & Audit workflow defined in that skill file. The agent checks every SQL Server instance for: Protection Group assignment, active replication, replication encryption, snapshot schedule frequency, retention policy compliance, volume tagging completeness, PG tagging, HA placement across availability zones, and configuration drift (Purity version skew, degraded replication links).

```
Great, now do the "Compliance & Audit" report
```

---

## Step 6 — Application-Consistent Database Snapshot

**What this does:** A multi-step agentic workflow. The agent reads the `snapshotui` repo to learn the volume tagging scheme and REST snapshot API, then takes an application-consistent snapshot of a specific database, verifies replication, and reports the snapshot metadata.

**What the agent must do:**
1. Read the GitHub repo to understand the tagging scheme and REST API contract
2. Identify the FlashArray volumes associated with `TPCC-4T` on `aen-sql-25-a` using volume tags
3. Call the REST API at `http://aen-docker-01:8080` to trigger a database snapshot
4. Confirm the snapshot replicated successfully
5. Output the snapshot name, timestamp, and replication status

```
Look at this GitHub repo to learn my volume tagging scheme and how to "snapshot a database":
https://github.com/nocentino/snapshotui Then, use my REST API is at http://aen-docker-01:8080 Take a "database" snapshot of the TPCC-4T database on aen-sql-25-a, then output the snapshot information here. Also, ensure that the snapshot is replicated, and confirm that it was successfully replicated.
```

---

## Step 7 — Correction Prompt (use if needed)

**What this does:** If the agent infers the array model from the array name rather than reading it directly from the API, use this correction. The agent should always read hardware model from the live array, not derive it from naming conventions.

```
Don't assume the model based on the array's current name. Read it directly from the array.
```

---

## Step 8 — Agent-Driven Snapshot with Freeze Safety

**Skill file:** [`skills/06-incident-response.md`](../skills/06-incident-response.md) — Snapshot & Recovery, freeze safety

**What this does:** Step 6 snapshots a database through the external `snapshotui` REST API — the API
owns the sequence and the agent just calls it. This step is the opposite: **the agent itself drives
the I/O freeze**, bound by the freeze-safety rules in `skills/06-incident-response.md`. It is the only step
that demonstrates the agent handling an operation where *getting it wrong takes a database offline*.

That is the point of the step. Anything can call a REST endpoint. The interesting question is whether
the agent understands that `SUSPEND_FOR_SNAPSHOT_BACKUP` never times out on its own, and that a
failure between suspend and release is an outage rather than a failed job.

> **This mutates state and freezes database I/O.** Rehearse it before showing it. See
> *Safety and abort* below and know the manual release command before you type the prompt.

### Prerequisites

- A T-SQL path from this machine. `sqlcmd` and `pwsh` + the `SqlServer` module both work.
  Authenticate however your environment does — never inline a password in the prompt, and see
  **Credential Handling** in [`skills/00-global.md`](../skills/00-global.md).
- The target database's volumes must all share **one** Protection Group. `aen-sql-25-a` satisfies
  this: all 9 volumes are in `aen-sql-25-a-pg`. If they span PGs the agent must refuse — a snapshot
  spanning Protection Groups is not crash-consistent.
- `fetch_tool` with a non-`GET` method is confirmation-gated, so you will get a permission prompt on
  the `POST`. That prompt *is* part of the demo — do not pre-approve it away.

### Prompt

```
You're a Database SRE agent. Your skills and workflows are defined in @skills/00-global.md and
@skills/06-incident-response.md.

Take an application-consistent snapshot of the TPCC-4T database on aen-sql-25-a using the single
database snapshot flow. Use sqlcmd for the T-SQL steps. Replicate the snapshot immediately, report
the actual freeze duration, and confirm the replicated copy landed on the DR array.
```

Note what the prompt does **not** say. It does not mention the 30-second cap, the guarded block, or
releasing the freeze on failure. Those are policy, not instruction — they come from the skills file.
If you have to tell the agent how to be safe in the prompt, the policy file isn't doing its job.

### What the agent should do, in order

1. Resolve the volumes carrying `TPCC-4T` from the `databases` volume tag
2. Confirm every one of them is in a single Protection Group — **stop here if not**
3. Confirm no other suspend is already active on the database
4. `ALTER DATABASE TPCC-4T SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON`
5. `POST /protection-group-snapshots?source_names=aen-sql-25-a-pg&replicate_now=true`
6. `BACKUP DATABASE TPCC-4T TO DISK='...' WITH METADATA_ONLY` — **this is what releases the freeze**
7. Tag `BackupUrl` onto the resulting snapshot
8. Report the snapshot name, timestamp, freeze duration, and replication status

Steps 5 and 6 are a **guarded block**. On any failure, timeout, or interruption in step 5, the agent
must run step 6 — or `SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF` — to release the freeze *before* it
reports the error.

### What to point at

- **The crash-consistency gate at step 2.** The agent verifies single-PG membership before it touches
  the database. A script would have snapshotted first and discovered the problem at restore time.
- **The permission prompt on the `POST`.** Read-only work has run unprompted all demo; the first
  state-changing call stops and asks. This is the supervised-action model actually working, not
  asserted on a slide.
- **The reported freeze duration.** Say: *"that number is the I/O impact window, and it belongs in the
  change record."* Storage teams rarely get asked for it; auditors increasingly do.
- **The order of operations on failure.** This is the line that lands:
  > "If the snapshot call fails, the agent releases the freeze *before* it tells me it failed.
  > A script that dies between those two steps leaves the database suspended until someone notices."

### Optional — the failure beat

Only if you have rehearsed it and have time. Interrupt the agent between the suspend and the snapshot
(Esc), or point it at a non-existent Protection Group so the `POST` 404s. The agent should release the
freeze first, then report. **Verify the database is writable afterwards before moving on.**

This is the most persuasive thirty seconds in the whole demo for a regulated audience, and the most
likely to go wrong live. Recording it beforehand is a legitimate choice — say plainly that it is a
recording if you show one.

### Safety and abort

If a freeze is ever left held, release it directly:

```sql
ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF;
```

Check for a held freeze before and after:

```sql
SELECT database_id, DB_NAME(database_id) AS db, is_suspended_for_snapshot_backup
FROM   sys.databases WHERE DB_NAME(database_id) = 'TPCC-4T';
```

Have that release command in a scratch buffer before you start. The multi-database (`mode=group`) and
whole-instance (`mode=server`) flows raise the stakes: a `mode=server` freeze suspends **every**
database on the instance, and the `GROUP`/`SERVER` backup must run on the same connection that issued
the suspend. Do not demo those live.
