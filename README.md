# Maintenance-
Scripts and such used for performing maintenance tasks. 
This will evolve over time and will be improved upon as needed.

Scripts and notes used for Windows systems maintenance tasks. This repository is a practical, growing collection of PowerShell-style scripts for common administrator workflows such as Active Directory group management, TLS registry configuration, printer inventory, connectivity checks, scheduled reboots, and email notifications.

> [!CAUTION]
> Several scripts make machine-wide changes, such as editing `HKLM:` registry keys, creating Active Directory objects, or scheduling reboots. Review and test scripts in a lab before running them in production.

## Repository layout

This repository is intentionally simple: most files live at the repository root and are standalone scripts rather than part of a packaged application.

| File | Purpose |
| --- | --- |
| `UserGroup` | Interactive Active Directory group creation script. It creates or finds an owner group, creates a main group, sets the main group's `ManagedBy` attribute, and can add users to the owner group. |
| `Disable TLS 1.0 and 1.1  Client & Server` | Disables TLS 1.0 and TLS 1.1 for both client and server roles by writing SCHANNEL registry keys. |
| `Enable TLS 1.2 on Client and Server` | Enables TLS 1.2 client and server registry settings. |
| `Enable TLS 1.3 on Client and Server` | Enables TLS 1.3 client and server registry settings and updates .NET strong crypto registry values where present. |
| `Print Server List Printers` | Builds an Excel-based printer inventory from one or more print servers using WMI and Excel COM automation. |
| `PingIt` | Reads a local `servers.txt` file and checks whether each server responds to `Test-Connection`. |
| `Sendmail.ps1` | Sends a maintenance notification email through an SMTP server. Intended for use with Windows Task Scheduler or other automation. |
| `SystemRebootTask_and_Email` | Creates a scheduled task intended to send an email and reboot a system at a scheduled time. |

## General structure

There is no compiled application, package manifest, or formal test suite. Each script should be reviewed as an independent maintenance tool with its own requirements and risks.

Common patterns across the repository include:

- Windows PowerShell commands and syntax.
- Windows registry edits through the `HKLM:` provider.
- Active Directory PowerShell cmdlets.
- WMI queries for printer and driver data.
- Windows Task Scheduler cmdlets.
- Environment-specific placeholders that must be changed before use.

## Important things to know before running scripts

### Run from an appropriate Windows environment

These scripts are written for Windows administration. Many of them will not run correctly from Linux, macOS, or non-Windows PowerShell sessions because they depend on Windows-only providers, modules, COM objects, WMI classes, or system tools.

### Use administrative privileges where required

Scripts that write to `HKLM:` registry paths, create scheduled tasks, or perform server maintenance usually need to be run from an elevated PowerShell session.

### Replace placeholders first

Several scripts contain placeholder values that should be updated for your environment before execution:

- Active Directory paths such as `OU=Groups,DC=domain,DC=com`.
- Print server names such as `printservernamehere1`.
- SMTP server names, sender addresses, and recipient addresses.
- Domain user values such as `DOMAIN\user`.
- Script paths such as `C:\scripts\sendmail.ps1`.

### Test in a lab first

Before running a script against production servers, test with a disposable VM, test OU, test print server, or non-production maintenance window. This is especially important for scripts that:

- Disable or enable TLS protocols.
- Create or modify Active Directory groups.
- Reboot a machine.
- Query many remote servers.
- Send email notifications to real users.

### Quote filenames with spaces

Several script filenames contain spaces. When running them directly, quote the path:

```powershell
& ".\Enable TLS 1.2 on Client and Server"
```


## Quick start

1. Clone or download this repository on a Windows administration workstation.
2. Open PowerShell as Administrator when the script changes registry settings, scheduled tasks, or server configuration.
3. Read the script comments and the matching notes in this README before running anything.
4. Replace every placeholder value with values from your own environment.
5. Run the script in a lab or against a test target first.
6. Record what was changed, when it was changed, and whether a restart is required.

## Before you run a script

Use this checklist for each maintenance script:

- Confirm the script matches the operating system and PowerShell version on the target machine.
- Confirm you have the required permissions for the target system, domain, registry path, or print server.
- Back up or document current settings before making changes.
- Review all hard-coded paths, server names, email addresses, domain names, and OU paths.
- Schedule production-impacting work during an approved maintenance window.
- Keep a rollback plan, especially for registry, TLS, scheduled task, and reboot changes.

## Script notes

### `UserGroup`

Use this script when you need to create a security group, associate it with an owner group, and optionally add users to that owner group.

Before use:

- Confirm the Active Directory PowerShell module is installed.
- Update the target OU path.
- Run with an account that has permission to create groups and modify group membership.
- Consider adding validation and better error output before broad production use.

### TLS scripts

The TLS scripts change Windows SCHANNEL and related registry settings. These changes can affect application compatibility and may require a restart.

Before use:

- Confirm the target Windows Server or Windows client version supports the TLS version being configured.
- Confirm application dependencies are compatible with the enabled or disabled protocols.
- Export or document the existing registry values before changing them.
- Test on non-production systems first.

### `Print Server List Printers`

This script uses Excel automation and WMI to create a printer inventory workbook.

Before use:

- Run from a Windows machine with Microsoft Excel installed.
- Use an account with access to query the target print servers.
- Replace the default print server list.
- Expect the script to open Excel visibly while it runs.

### `PingIt`

This is a simple connectivity helper. Create a `servers.txt` file in the same directory as the script, then add one server name per line.

Example `servers.txt`:

```text
server01
server02
server03
```

### `Sendmail.ps1` and `SystemRebootTask_and_Email`

These scripts are intended to work together: one sends an email notification, and the other schedules a reboot workflow.

Before use:

- Update SMTP settings and email addresses.
- Update the scheduled task user.
- Update the path to `sendmail.ps1`.
- Validate the scheduled task trigger syntax in a test environment.
- Confirm the reboot window with stakeholders before registering or running the task.

## Suggested learning path for newcomers

1. **PowerShell basics**
   - Variables, arrays, loops, conditionals, and pipelines.
   - `param()` blocks and script parameters.
   - `try` / `catch` error handling.
   - Running scripts with execution policy considerations.

2. **Windows administration with PowerShell**
   - Registry management with `New-Item`, `New-ItemProperty`, and `Set-ItemProperty`.
   - Active Directory automation with `Get-ADGroup`, `New-ADGroup`, `Set-ADGroup`, and `Add-ADGroupMember`.
   - Scheduled task automation with `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, and `Register-ScheduledTask`.

3. **Remote inventory and reporting**
   - WMI and CIM concepts.
   - Printer-related classes such as `Win32_Printer`, `Win32_TcpIpPrinterPort`, and `Win32_PrinterDriver`.
   - Exporting results to CSV or Excel.

4. **Script hardening**
   - Add `.ps1` extensions for consistency.
   - Convert hard-coded values into parameters.
   - Add input validation.
   - Add `-WhatIf` and `-Confirm` support for risky operations.
   - Add logging and clearer error messages.
   - Document required permissions for each script.

## Future improvement ideas

- Rename extensionless PowerShell scripts to `.ps1`.
- Add per-script usage examples.
- Add a `docs/` folder for operational runbooks.
- Add a `servers.txt.example` file for `PingIt`.
- Add parameterized versions of scripts that currently rely on hard-coded values.
- Add PowerShell Script Analyzer checks once script names and extensions are standardized.
- Add safer dry-run behavior for scripts that modify registry, Active Directory, or scheduled tasks.

## Adding new maintenance scripts

When adding a new script to this repository, include enough information for another administrator to run it safely:

- Use a `.ps1` extension when possible.
- Add a short header with the purpose, author or owner, date, version, and required permissions.
- Prefer parameters over hard-coded values.
- Include examples for common use cases.
- Document required modules, Windows roles, external applications, or network access.
- Add safety controls such as `-WhatIf`, `-Confirm`, validation, and clear error messages for risky operations.
- Update this README with the new script name, purpose, prerequisites, and any production-impact notes.
