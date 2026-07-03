. "$PSScriptRoot\scripts\common.ps1"

Assert-PowerShellVersion

$taskName = "LocalTelegramNotifier"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task) {
    Start-ScheduledTask -TaskName $taskName
    $updated = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Write-Host "Started Scheduled Task: $taskName"
    Write-Host "Task state: $($updated.State)"
}
else {
    Write-Host "Scheduled Task is not installed."
    Write-Host "Run .\install.ps1 first, or run .\watch.ps1 manually."
    $startNow = Read-Host "Start watch.ps1 in this PowerShell session now? (y/N)"
    if ($startNow -match "^(y|yes)$") {
        & "$PSScriptRoot\watch.ps1"
    }
    else {
        Write-Host "Watcher was not started. Run .\install.ps1 to install auto-start, or .\watch.ps1 to run manually."
    }
}
