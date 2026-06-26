# Admin Hub

An administrative PowerShell profile for Windows Servers. When deployed to the
**AllUsersAllHosts** profile location, every user who opens PowerShell on the
server is greeted with a banner and an interactive menu of common
administrative tasks — with the option to drop to a normal shell at any time.

```
    _    ____  __  __ ___ _   _
   / \  |  _ \|  \/  |_ _| \ | |
  / _ \ | | | | |\/| || ||  \| |
 / ___ \| |_| || |  | || || |\  |
/_/   \_\____/|_|  |_|___|_| \_|
 _   _ _   _ ____
| | | | | | | __ )
| |_| | | | |  _ \
|  _  | |_| | |_) |
|_| |_|\___/|____/
        Server Administration Console
```

## Menu options

| Key | Option                      | Type        |
|-----|-----------------------------|-------------|
| 1   | Disk Space                  | Read        |
| 2   | Top Processes (CPU)         | Read        |
| 3   | Restart a Service           | Action      |
| 4   | Pending Windows Updates     | Action      |
| 5   | Full System Health Check    | Read        |
| M   | Top 10 Memory Usage         | Read        |
| S   | Top 10 Swap / Page File     | Read        |
| A   | Active User Sessions        | Read        |
| C   | Disk Cleanup (C: drive)     | Destructive |
| E   | Export Health Report        | Action      |
| 0   | Exit to Shell               | —           |

After any task runs, you get a `[Enter] Return to menu / [X] Exit to shell`
prompt so output stays on screen. Exiting leaves all task functions loaded in
the session; type `Show-AdminMenu` to reopen the menu.

## Files

| File                       | Purpose                                                        |
|----------------------------|---------------------------------------------------------------|
| `AdminProfile.ps1`         | The profile itself — banner, menu, and all task functions.     |
| `Deploy-AdminProfile.ps1`  | Deploys the profile to all users on local or remote servers.   |
| `Remove-AdminProfile.ps1`  | Rolls back the profile, restoring any backup that was made.    |

## Deployment

Run from an elevated (Administrator) PowerShell prompt.

```powershell
# Local server
.\Deploy-AdminProfile.ps1

# One or more remote servers (uses the \\SERVER\Admin$ share)
.\Deploy-AdminProfile.ps1 -ComputerName SRV01,SRV02,SRV03 -Force
```

The profile is written to the **AllUsersAllHosts** path:

- Windows PowerShell 5.x: `%SystemRoot%\System32\WindowsPowerShell\v1.0\profile.ps1`
- PowerShell 7+: `%ProgramFiles%\PowerShell\7\profile.ps1`

Existing profiles are backed up with a timestamped `.bak_` suffix before being
overwritten.

## Rollback

```powershell
.\Remove-AdminProfile.ps1 -ComputerName SRV01
```

Restores the most recent backup if one exists; otherwise removes the deployed
profile.

## Rebranding

The banner is configurable at the top of `AdminProfile.ps1`. Replace
`$BannerLines` / `$BannerSubtitle` and set `$BannerColor`. Generate new ASCII
art with the "Standard" figlet font at <https://patorjk.com>.

## Requirements

- Windows Server (or Windows client) with PowerShell 5.1+ or PowerShell 7+
- Administrator rights to deploy and to run the administrative tasks
- Optional: the `PSWindowsUpdate` module for the "Pending Windows Updates" option
  (`Install-Module PSWindowsUpdate`)
