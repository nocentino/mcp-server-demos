# MCP Server Demos

Demo scripts and skills files for using [Claude Code](https://claude.ai/code) as a Database SRE agent with the Pure Storage Fusion MCP server.

## What's in This Repo

| File | Description |
|---|---|
| `CLAUDE.md` | Auto-loaded by Claude Code at session start: bootstraps the agent and points to `database-sre-agent.md` |
| `database-sre-agent.md` | Database SRE skills file: encodes SLA tiers, compliance policy, fleet topology, and operational workflows |
| `demo.md` | Step-by-step demo script: prompts with explanations for each workflow |
| `.claude/settings.json` | Claude Code project permissions: pre-approves the Fusion MCP tools needed for the demo |

## Prerequisites

**Pure Storage Fusion MCP server** configured and running with API tokens for each array in your fleet:

```
~/Library/Application Support/mcp-servers/fusion-mcp/auth-config.json
```

Each entry in `auth-config.json` needs a valid API token for the target array.

**Claude Code** installed and the Fusion MCP server registered in your MCP config.

## Running the Demo

1. Open this folder in VS Code with the Claude Code extension active.
2. The `.claude/settings.json` file pre-approves all required MCP tool calls so you won't be prompted for each one.
3. Work through the prompts in `demo.md` in order. Each prompt builds on the previous one.

## The Skills File

`database-sre-agent.md` is what turns Claude Code from a generic assistant into a Database SRE agent. `CLAUDE.md` is read automatically at session start and bootstraps the agent by pointing Claude Code to `database-sre-agent.md`. It encodes:

- **Fleet topology**: which arrays are in which availability zones, site assignments, HA placement rules for SQL Server pairs
- **Performance SLA tiers**: Tier 1 (OLTP) < 0.5ms, Tier 2 (general DB) < 2ms, Tier 3 (batch) < 10ms
- **Compliance policy**: Protection Group requirements, snapshot schedules, retention minimums, encryption requirements, volume tagging schema
- **Operational workflows**: Real-Time Operational Visibility, Compliance & Audit, Blast Radius Analysis, Snapshot & Recovery, DR Readiness Check

Once the session is open, just ask for a workflow directly:

```
Produce the "Compliance & Audit" report.
```

## Performance SLA Monitoring

![Performance SLA Monitoring report from the Real-Time Operational Visibility workflow](Screenshot%202026-05-22%20at%203.03.25%E2%80%AFPM.png)

## Demo Workflows Covered

1. **Fleet Discovery**: array inventory with Purity versions across the full fleet
2. **SQL Server Discovery**: pull known instances from the MSSQL VS Code extension
3. **Volume Discovery**: find SQL Server vVol volumes using array-side REST filtering
4. **Real-Time Operational Visibility**: health, alerts, capacity, and performance against SLA thresholds
5. **Compliance & Audit**: Protection Group coverage, tagging, replication topology, HA placement, configuration drift
6. **Application-Consistent Snapshot**: trigger a database snapshot via REST API, confirm replication

## Related Posts

- [Using Claude Code as a Database SRE Agent with the Pure Storage Fusion MCP Server](https://www.nocentino.com/posts/2026-05-22-database-sre-agent-claude-code-fusion-mcp/)
- [Managing Enterprise Storage with Pure Storage Fusion in PowerShell](https://www.nocentino.com/posts/2025-08-14-managing-storage-with-fusion-powershell/)
