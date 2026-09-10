---
applyTo: "**"
description: "Fleet Awareness SOP: session-start fleet topology check, coverage-gap detection, and query scoping for a shared Pure Storage fleet"
---

# Skill: Fleet Awareness

**When this applies**: before executing any other workflow in this file set. Fleet topology is the foundation every other skill queries against — never skip it to save a call.

## Procedure
0. Call `get_documentation` once per session before other tools, to pick up concept and endpoint context.
1. Call `list_arrays` to identify arrays with direct API access (configured arrays).
2. Call `get_fleet_overview` with **`brief=false` and `include_alerts=true`** to identify all fleet members and their alerts.
3. Cross-reference the two lists **in both directions**:
   - In the fleet but not configured → cannot be queried for performance, capacity, or (for FlashBlades) alerts. Flag as a **visibility gap**.
   - Configured but not a fleet member → queryable directly, but outside fleet management; it will not appear in fleet-wide reports. Flag as a **fleet-management gap**.

## Decision rules
- `get_fleet_overview` defaults to `brief=true`, and `include_alerts` is *only honored when `brief=false`*. Passing `include_alerts=true` alone returns no alerts and will read as a clean fleet. Always pass both.
- `brief=false` responses grow large on wide fleets because they include every array's connections. Use `arrayNames` to scope when only a subset is in question.
- Performance endpoints (`get_arrays_performance_multi_tool`) do not support remote execution. Each configured array must be queried individually. Arrays not in `list_arrays` cannot provide performance data.
- **Never let a failed query read as a pass.** `get_fleet_overview` reports per-array `alerts_status` / `alerts_error` and `array_connections_status` / `array_connections_error`. Inspect these on every array. Any value other than `success` must be rendered as **Unknown — query failed**, never as a pass, a zero, or an empty alert list. List every affected array as an explicit coverage caveat on the report. Remote execution commonly fails two ways:
  - A gateway array cannot reach a remote target (HTTP 503 `Failed to connect to remote target`), which usually means a degraded fleet-management link rather than a down array — the array may still answer direct queries.
  - FlashBlade alerts cannot be retrieved via remote execution at all. Each FlashBlade needs its own configured token for alert visibility.

**Hint**: Users can add API tokens for additional arrays in their MCP auth config file at `~/Library/Application Support/mcp-servers/fusion-mcp/auth-config.json`.

## Query Scoping — keep responses small

**This fleet is shared.** `pgroup-auto` on `sn1-x90r2-f06-27` holds 254 volumes; `sn1-c60-e12-16` carries 50+ protection groups belonging to other workloads; `sn1-s200-c09-33` has 174 filesystems and 83 buckets. An unscoped list query returns other tenants' resources, overflows the response budget, forces a second round trip to parse from disk, and puts names on screen that do not belong to this audit.

Scope every query on the way out, not by filtering the answer afterwards:

- **Filter to the estate.** Use `filter=contains(name,'aen-sql')` on volumes, or query the expected array from the [placement table](00-reference.md#availability-zone-requirements). Never list a whole array's volumes to find one instance's.
- **Name the resource when you know it.** Fetch protection groups with `names=aen-sql-25-a-pg,aen-sql-25-b-pg`, not by listing all PGs and filtering. The placement table gives you the names.
- **Filter on the identifying field, not a substring.** `source.name='pgroup-auto'` rather than `contains(name,'pgroup-auto')` — see the filter trap in [Field Traps](00-reference.md#field-traps--these-produce-false-passes).
- **Set `limit` deliberately** and page with `continuationToken` when a full set is genuinely needed. A large `limit` is the right choice only when you intend to rank or total the whole set locally.
- **Report what you scoped out.** When a query was narrowed, say so — *"scoped to `aen-*`; 168 other filesystems on this array were not assessed."* A narrowed report that does not admit its narrowing reads as a fleet-wide pass.

A fleet-wide sweep is still correct when the question is fleet-wide — topology, drift, encryption posture. Scope tightly for instance-level and estate-level work; sweep deliberately and say so when the question demands it.
