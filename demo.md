# Database SRE Agent Demo
## Claude Code + Pure Storage Fusion MCP Server

This demo walks through using Claude Code as a Database SRE agent against a live Pure Storage fleet.
Prerequisites: Fusion MCP server configured with API tokens in `~/Library/Application Support/mcp-servers/fusion-mcp/auth-config.json`, and the `database-sre-agent.md` skills file in the project directory.

---

## Step 1 — Fleet Discovery

**What this does:** Establishes fleet topology by querying all configured arrays for their Purity versions and hardware model. This is the baseline before any operational workflow.

```
Using the Fusion MCP server, tell me what arrays are in this environment, including their Purity versions.
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
```

---

## Step 3 — SQL Server Volume Discovery on FlashArray

**What this does:** Correlates SQL Server instance names to FlashArray volumes. Since the SQL Servers are VMware VMs using vVols, the SQL instance name is embedded in the FlashArray volume name. The prompt instructs the agent to use array-side REST `contains` filtering instead of pulling all volumes locally — important for large fleets.

```
The SQL Servers that have aen-sql-25 contained in their name are on FlashArray. All of my SQL Servers are VMware VMs using vVols, so the name of the SQL instance is also contained in the FlashArray volume name. Then give me a listing of all of my SQL Server volumes in my fleet. Use array side REST filtering so that you don't have to pull a giant list of volumes locally, don't use wildcards use the contains parameter for the search.
```

---

## Step 4 — Real-Time Operational Visibility Report

**What this does:** Loads the Database SRE skills file, which gives the agent its financial services context: SLA tiers, capacity thresholds, alert priorities, and fleet topology (AZ assignments, HA rules). Then runs the Real-Time Operational Visibility workflow covering hardware health, active alerts, capacity utilization, and performance against tier SLA thresholds.

**Note:** The `#database-sre-agent.md` syntax references the skills file from the project directory using Claude Code's file reference feature.

```
You're a database SRE, load the #database-sre-agent.md skills file and produce the "Real-Time Operational Visibility" report.
```

---

## Step 5 — Compliance & Audit Report

**What this does:** Runs the Compliance & Audit workflow defined in the skills file. The agent checks every SQL Server instance for: Protection Group assignment, active replication, replication encryption, snapshot schedule frequency, retention policy compliance, volume tagging completeness, PG tagging, HA placement across availability zones, and configuration drift (Purity version skew, degraded replication links).

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
