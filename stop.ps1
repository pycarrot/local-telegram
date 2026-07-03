. "$PSScriptRoot\scripts\common.ps1"

Assert-PowerShellVersion

$taskName = "LocalTelegramNotifier"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "Scheduled Task is not installed: $taskName"
    Write-Host "If you started watch.ps1 manually, stop it with Ctrl+C in that window."
    exit 0
}

Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$updated = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Write-Host "Stopped Scheduled Task: $taskName"
Write-Host "Task state: $($updated.State)"
