#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Administrative PowerShell profile applied to all users on Windows Servers.
    Presents an interactive menu of common administrative tasks on shell startup.
#>

# ===========================================================================
#  CONFIG - Banner
#  Printed once at startup above the menu. To rebrand, replace $BannerLines /
#  $BannerSubtitle. Generate new ASCII art at https://patorjk.com (Standard).
# ===========================================================================
$BannerLines = @(
    '    _    ____  __  __ ___ _   _',
    '   / \  |  _ \|  \/  |_ _| \ | |',
    '  / _ \ | | | | |\/| || ||  \| |',
    ' / ___ \| |_| || |  | || || |\  |',
    '/_/   \_\____/|_|  |_|___|_| \_|',
    ' _   _ _   _ ____  ',
    '| | | | | | | __ ) ',
    '| |_| | | | |  _ \ ',
    '|  _  | |_| | |_) |',
    '|_| |_|\___/|____/ '
)
$BannerColor    = 'Cyan'
$BannerSubtitle = 'Server Administration Console'

function Show-Banner {
    Write-Host ""
    foreach ($line in $BannerLines) {
        Write-Host $line -ForegroundColor $BannerColor
    }
    Write-Host "  $BannerSubtitle" -ForegroundColor DarkGray
}

function prompt {
    $user   = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $host_  = $env:COMPUTERNAME
    $path   = (Get-Location).Path
    Write-Host "[ADMIN] " -ForegroundColor Red -NoNewline
    Write-Host "$user" -ForegroundColor Yellow -NoNewline
    Write-Host "@$host_" -ForegroundColor Cyan -NoNewline
    Write-Host " $path" -ForegroundColor White -NoNewline
    return "`n> "
}

function Write-Header {
    param([string]$Title)
    $line = "=" * 60
    Write-Host "`n$line" -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$line" -ForegroundColor DarkCyan
}

function Get-DiskSpace {
    Write-Header "Disk Space"
    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name,
            @{N='Used(GB)';  E={[math]::Round($_.Used/1GB,2)}},
            @{N='Free(GB)';  E={[math]::Round($_.Free/1GB,2)}},
            @{N='Total(GB)'; E={[math]::Round(($_.Used+$_.Free)/1GB,2)}} |
        Format-Table -AutoSize
}

function Get-TopProcesses {
    Write-Header "Top 15 Processes by CPU"
    Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First 15 Name, Id,
            @{N='CPU(s)'; E={[math]::Round($_.CPU,2)}},
            @{N='Mem(MB)';E={[math]::Round($_.WorkingSet/1MB,2)}} |
        Format-Table -AutoSize
}

function Restart-ServiceByName {
    $name = Read-Host "  Enter service name to restart"
    if ([string]::IsNullOrWhiteSpace($name)) { Write-Host "  Cancelled." -ForegroundColor Yellow; return }
    try {
        Restart-Service -Name $name -Force -ErrorAction Stop
        Write-Host "  '$name' restarted successfully." -ForegroundColor Green
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
}

function Test-PendingReboot {
    $reasons = @()

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons += 'Component-Based Servicing'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons += 'Windows Update'
    }
    $pfro = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
                -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pfro) { $reasons += 'Pending file rename' }

    $cn  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' `
                -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
    $pcn = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' `
                -Name ComputerName -ErrorAction SilentlyContinue).ComputerName
    if ($cn -and $pcn -and ($cn -ne $pcn)) { $reasons += 'Pending computer rename' }

    return $reasons
}

function Get-PendingUpdates {
    Write-Header "Pending Windows Updates"
    if (-not (Get-Module -ListAvailable PSWindowsUpdate)) {
        Write-Host "  PSWindowsUpdate module not found. Install with: Install-Module PSWindowsUpdate" -ForegroundColor Yellow
    } else {
        Import-Module PSWindowsUpdate
        Get-WindowsUpdate | Select-Object KB, Title, Size, MsrcSeverity | Format-Table -AutoSize
    }

    Write-Host ""
    $rebootReasons = Test-PendingReboot
    if ($rebootReasons.Count -gt 0) {
        Write-Host "  REBOOT PENDING - $($rebootReasons -join ', ')" -ForegroundColor Red
    } else {
        Write-Host "  No reboot pending." -ForegroundColor Green
    }
}

function Get-TopMemory {
    Write-Header "Top 10 Processes by Memory Usage"
    Get-Process |
        Sort-Object WorkingSet -Descending |
        Select-Object -First 10 Name, Id,
            @{N='Mem(MB)';       E={[math]::Round($_.WorkingSet / 1MB, 2)}},
            @{N='PrivateMem(MB)';E={[math]::Round($_.PrivateMemorySize64 / 1MB, 2)}},
            @{N='Handles';       E={$_.HandleCount}} |
        Format-Table -AutoSize
}

function Get-SwapUsage {
    Write-Header "Top 10 Processes by Page File (Swap) Usage"
    $pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
    if ($pf) {
        foreach ($p in $pf) {
            $pct = if ($p.AllocatedBaseSize -gt 0) {
                [math]::Round($p.CurrentUsage / $p.AllocatedBaseSize * 100, 1)
            } else { 0 }
            Write-Host ("  Pagefile: {0}  Used: {1} MB / {2} MB  ({3}%)" -f `
                $p.Name, $p.CurrentUsage, $p.AllocatedBaseSize, $pct) -ForegroundColor $(
                    if ($pct -ge 80) { 'Red' } elseif ($pct -ge 60) { 'Yellow' } else { 'Green' }
                )
        }
        Write-Host ""
    }
    Get-Process |
        Sort-Object PagedMemorySize64 -Descending |
        Select-Object -First 10 Name, Id,
            @{N='PagedMem(MB)';   E={[math]::Round($_.PagedMemorySize64 / 1MB, 2)}},
            @{N='VirtualMem(MB)'; E={[math]::Round($_.VirtualMemorySize64 / 1MB, 2)}},
            @{N='NonPagedMem(MB)';E={[math]::Round($_.NonpagedSystemMemorySize64 / 1MB, 2)}} |
        Format-Table -AutoSize
}

function Get-ActiveSessions {
    Write-Header "Active User Sessions"
    $raw = query session 2>$null
    if (-not $raw) {
        Write-Host "  No session data available." -ForegroundColor Yellow
        return
    }
    $raw | Select-Object -Skip 1 | ForEach-Object {
        if ($_ -match '^\s*(\S+)\s+(\S+)\s+(\d+)\s+(\S+)') {
            [PSCustomObject]@{
                SessionName = $Matches[1]
                Username    = $Matches[2]
                ID          = $Matches[3]
                State       = $Matches[4]
            }
        }
    } | Format-Table -AutoSize
}

function Export-HealthReport {
    $stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
    $outDir  = "$env:SystemDrive\AdminReports"
    $outFile = "$outDir\HealthReport_$env:COMPUTERNAME`_$stamp.txt"

    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory $outDir | Out-Null }

    $report = & {
        "=" * 60
        "  SERVER HEALTH REPORT — $env:COMPUTERNAME"
        "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "=" * 60

        "`n[DISK SPACE]"
        Get-PSDrive -PSProvider FileSystem |
            Select-Object Name,
                @{N='Used(GB)';  E={[math]::Round($_.Used/1GB,2)}},
                @{N='Free(GB)';  E={[math]::Round($_.Free/1GB,2)}},
                @{N='Total(GB)'; E={[math]::Round(($_.Used+$_.Free)/1GB,2)}} |
            Format-Table -AutoSize | Out-String

        "`n[TOP 15 PROCESSES - CPU]"
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name, Id,
            @{N='CPU(s)'; E={[math]::Round($_.CPU,2)}},
            @{N='Mem(MB)';E={[math]::Round($_.WorkingSet/1MB,2)}} |
            Format-Table -AutoSize | Out-String

        "`n[TOP 10 PROCESSES - MEMORY]"
        Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, Id,
            @{N='Mem(MB)';       E={[math]::Round($_.WorkingSet/1MB,2)}},
            @{N='PrivateMem(MB)';E={[math]::Round($_.PrivateMemorySize64/1MB,2)}} |
            Format-Table -AutoSize | Out-String

        "`n[ACTIVE SESSIONS]"
        (query session 2>$null) -join "`n"

        "`n[PAGEFILE USAGE]"
        Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue |
            Select-Object Name, CurrentUsage, AllocatedBaseSize |
            Format-Table -AutoSize | Out-String

        "`n" + ("=" * 60)
        "  END OF REPORT"
        "=" * 60
    }

    $report | Out-File -FilePath $outFile -Encoding UTF8
    Write-Host "  Report saved to: $outFile" -ForegroundColor Cyan
    Write-Host "  Size: $([math]::Round((Get-Item $outFile).Length / 1KB, 1)) KB" -ForegroundColor DarkCyan
}

function Invoke-SystemHealthCheck {
    Get-DiskSpace
    Get-TopProcesses
}

function Invoke-DiskCleanup {
    param([string]$Drive = 'C')

    $root = "${Drive}:\"
    if (-not (Test-Path $root)) {
        Write-Host "  Drive $Drive`: not found." -ForegroundColor Red
        return
    }

    Write-Header "Disk Cleanup - ${Drive}:"

    $targets = @(
        @{ Label = 'Windows Temp';               Path = "$env:SystemRoot\Temp" },
        @{ Label = 'User Temp';                  Path = "$env:TEMP" },
        @{ Label = 'Prefetch';                   Path = "$env:SystemRoot\Prefetch" },
        @{ Label = 'CBS Logs';                   Path = "$env:SystemRoot\Logs\CBS" },
        @{ Label = 'Memory Dump Files';          Path = "$env:SystemRoot\MEMORY.DMP"; IsFile = $true },
        @{ Label = 'Minidumps';                  Path = "$env:SystemRoot\Minidump" },
        @{ Label = 'IIS Logs';                   Path = "$env:SystemDrive\inetpub\logs\LogFiles" },
        @{ Label = 'SoftwareDistribution\Download'; Path = "$env:SystemRoot\SoftwareDistribution\Download" }
    )

    $preview = foreach ($t in $targets) {
        if (-not (Test-Path $t.Path)) { continue }
        if ($t.IsFile) {
            $f     = Get-Item $t.Path -ErrorAction SilentlyContinue
            $size  = if ($f) { $f.Length } else { 0 }
            $count = if ($f) { 1 } else { 0 }
        } else {
            $files = Get-ChildItem $t.Path -Recurse -Force -File -ErrorAction SilentlyContinue
            $size  = ($files | Measure-Object Length -Sum).Sum
            $count = $files.Count
        }
        [PSCustomObject]@{
            Location   = $t.Label
            Files      = $count
            'Size(MB)' = [math]::Round($size / 1MB, 2)
            Path       = $t.Path
        }
    }

    $totalMB = [math]::Round(($preview | Measure-Object 'Size(MB)' -Sum).Sum, 2)

    if (-not $preview -or $totalMB -eq 0) {
        Write-Host "  Nothing to clean on ${Drive}:." -ForegroundColor Green
        return
    }

    $preview | Select-Object Location, Files, 'Size(MB)' | Format-Table -AutoSize
    Write-Host "  Total recoverable: $totalMB MB" -ForegroundColor Yellow

    $confirm = Read-Host "`n  Proceed with cleanup? [Y/N]"
    if ($confirm -notmatch '^[Yy]') {
        Write-Host "  Cleanup cancelled." -ForegroundColor Yellow
        return
    }

    $wuWasRunning = (Get-Service wuauserv -ErrorAction SilentlyContinue).Status -eq 'Running'
    if ($wuWasRunning) { Stop-Service wuauserv -Force -ErrorAction SilentlyContinue }

    $freed = 0
    foreach ($t in $targets) {
        if (-not (Test-Path $t.Path)) { continue }
        try {
            if ($t.IsFile) {
                $f = Get-Item $t.Path -ErrorAction SilentlyContinue
                if ($f) { $freed += $f.Length; Remove-Item $t.Path -Force -ErrorAction SilentlyContinue }
            } else {
                $files  = Get-ChildItem $t.Path -Recurse -Force -File -ErrorAction SilentlyContinue
                $freed += ($files | Measure-Object Length -Sum).Sum
                Remove-Item "$($t.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Host "  Cleaned: $($t.Label)" -ForegroundColor Green
        } catch {
            Write-Host "  Skipped: $($t.Label) - $_" -ForegroundColor DarkYellow
        }
    }

    if ($wuWasRunning) { Start-Service wuauserv -ErrorAction SilentlyContinue }

    $freedMB = [math]::Round($freed / 1MB, 2)
    Write-Host "`n  Done. Freed approximately $freedMB MB on ${Drive}:." -ForegroundColor Cyan

    $drv = Get-PSDrive -Name $Drive -PSProvider FileSystem -ErrorAction SilentlyContinue
    if ($drv) {
        $usedGB  = [math]::Round($drv.Used / 1GB, 2)
        $freeGB  = [math]::Round($drv.Free / 1GB, 2)
        $totalGB = [math]::Round(($drv.Used + $drv.Free) / 1GB, 2)
        Write-Host "  ${Drive}: - Used: ${usedGB} GB  Free: ${freeGB} GB  Total: ${totalGB} GB" -ForegroundColor White
    }
}

function Show-AdminMenu {
    Show-Banner
    while ($true) {
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host "  SERVER ADMIN MENU  -  $env:COMPUTERNAME" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkGray
        Write-Host "  [1]  Disk Space"              -ForegroundColor Green
        Write-Host "  [2]  Top Processes (CPU)"     -ForegroundColor Green
        Write-Host "  [3]  Restart a Service"       -ForegroundColor Yellow
        Write-Host "  [4]  Pending Windows Updates" -ForegroundColor Yellow
        Write-Host "  [5]  Full System Health Check"-ForegroundColor Cyan
        Write-Host "  [M]  Top 10 Memory Usage"     -ForegroundColor Green
        Write-Host "  [S]  Top 10 Swap/Page File"   -ForegroundColor Green
        Write-Host "  [A]  Active User Sessions"    -ForegroundColor Green
        Write-Host "  [C]  Disk Cleanup (C: drive)" -ForegroundColor Magenta
        Write-Host "  [E]  Export Health Report"    -ForegroundColor DarkCyan
        Write-Host "  [0]  Exit to Shell"           -ForegroundColor Red
        Write-Host ("=" * 60) -ForegroundColor DarkGray

        $choice = Read-Host "`n  Select an option"

        $ranTask = $true
        switch ($choice.ToUpper()) {
            '1' { Get-DiskSpace }
            '2' { Get-TopProcesses }
            '3' { Restart-ServiceByName }
            '4' { Get-PendingUpdates }
            '5' { Invoke-SystemHealthCheck }
            'M' { Get-TopMemory }
            'S' { Get-SwapUsage }
            'A' { Get-ActiveSessions }
            'C' { Invoke-DiskCleanup -Drive 'C' }
            'E' { Export-HealthReport }
            '0' {
                Write-Host "`n  Exiting menu. Type 'Show-AdminMenu' to return.`n" -ForegroundColor Cyan
                return
            }
            default {
                Write-Host "  Invalid option. Please choose 0-5, A, C, E, M, or S." -ForegroundColor Red
                $ranTask = $false
            }
        }

        if ($ranTask) {
            Write-Host "`n  [Enter] Return to menu    [X] Exit to shell" -ForegroundColor DarkGray
            $after = Read-Host "  Choose"
            if ($after -match '^[Xx]') {
                Write-Host "`n  Exiting menu. Type 'Show-AdminMenu' to return.`n" -ForegroundColor Cyan
                return
            }
        }
    }
}

Show-AdminMenu
