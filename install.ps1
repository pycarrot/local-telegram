. "$PSScriptRoot\scripts\common.ps1"

$taskName = "LocalTelegramNotifier"
$scriptPath = Join-Path $PSScriptRoot "watch.ps1"
$logPath = Get-LogPath
$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

try {
    $config = Load-Config
    foreach ($folder in @(Get-WatchFolders $config)) {
        if (Test-IsMappedDrivePath -Path $folder) {
            Write-Host "Warning: $folder is a mapped network drive."
            Write-Host "Mapped drives may not be available after reboot. For production, prefer UNC paths like \\server\share\folder."
        }
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            Write-Host "Warning: watch folder is currently unavailable: $folder"
        }
    }
}
catch {
    Write-Host "Warning: could not read config.json yet. Run .\setup.ps1 if this is a fresh install."
}

$command = "& '$scriptPath' *> '$logPath'"
$arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
$action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory $PSScriptRoot
$settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew

Write-Host "Installing Scheduled Task: $taskName"

try {
    if ($isAdmin) {
        $trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force -ErrorAction Stop | Out-Null
        Write-Host "Installed $taskName as an AtStartup task."
    }
    else {
        $userId = "$env:USERDOMAIN\$env:USERNAME"
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
        $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
        Write-Host "Installed $taskName as an AtLogOn task for $userId."
    }

    Write-Host "Use .\start.ps1 to start it now."
    exit 0
}
catch {
    Write-Error "Failed to install Scheduled Task: $($_.Exception.Message)"
    exit 1
}
