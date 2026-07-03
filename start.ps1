$taskName = "LocalTelegramNotifier"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task) {
    Start-ScheduledTask -TaskName $taskName
    $updated = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Write-Host "Started Scheduled Task: $taskName"
    Write-Host "Task state: $($updated.State)"
}
else {
    Write-Host "Scheduled Task is not installed. Starting watch.ps1 in this PowerShell session."
    & "$PSScriptRoot\watch.ps1"
}
