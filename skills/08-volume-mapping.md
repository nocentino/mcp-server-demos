---
applyTo: "**"
description: "SQL Server + FlashArray Volume Mapping: correlate a database's data file to its FlashArray volume across Windows, vCenter, and FlashArray layers"
---

# Skill: SQL Server + FlashArray Volume Mapping

**When this applies**: the user asks *"which FlashArray volume contains this database's data file?"* for a SQL Server database running as a VMware vVol-based VM.

## Procedure

A three-layer correlation maps database files to FlashArray volumes:
1. **Windows layer**: Use `Get-Disk` and `Get-Partition` (PowerShell remoting over SSH) to collect mount locations and disk UUIDs from `UniqueId`.
2. **vCenter layer**: Connect to vCenter, enumerate VM virtual disks, extract `ExtensionData.Backing.Uuid` (remove hyphens) and `ExtensionData.Backing.BackingObjectId` (the vVol ID).
3. **FlashArray layer**: Query volume tags in the namespace `vasa-integration.purestorage.com` for key `PURE_VVOL_ID` to match vVol IDs to FlashArray volume names.

**Correlation chain**: Windows UUID → VMware backing UUID → VMware vVol ID → FlashArray volume name.
