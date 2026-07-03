. "$PSScriptRoot\scripts\common.ps1"

Assert-PowerShellVersion

$taskName = "LocalTelegramNotifier"
$configPath = Get-ConfigPath
$logPath = Get-LogPath
$failedPath = Get-DataPath "failed.jsonl"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$taskInfo = $null

Write-Host "Config exists: $(Test-Path -LiteralPath $configPath -PathType Leaf)"
Write-Host "Config path: $configPath"
Write-Host ""

Write-Host "Scheduled Task exists: $([bool]$task)"
if ($task) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    Write-Host "Task state: $($task.State)"
    if ($taskInfo) {
        Write-Host "Last run time: $($taskInfo.LastRunTime)"
        Write-Host "Last result: $($taskInfo.LastTaskResult)"
    }
}

Write-Host ""
Write-Host "Watched folders:"
try {
    $config = Load-Config
    foreach ($folder in @(Get-WatchFolders $config)) {
        $state = if (Test-Path -LiteralPath $folder -PathType Container) { "OK" } else { "Missing" }
        Write-Host "  [$state] $folder"
        if (Test-IsMappedDrivePath -Path $folder) {
            Write-Host "    Warning: this is a mapped network drive. For auto-start, prefer a UNC path like \\server\share\folder."
        }
        if ($state -eq "Missing") {
            Write-Host "    Warning: this folder is unavailable. The watcher will retry while running."
        }
    }
}
catch {
    Write-Host "  Could not load config: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Log file: $logPath"
Write-Host "Recent log lines:"
if (Test-Path -LiteralPath $logPath -PathType Leaf) {
    Get-Content -LiteralPath $logPath -Tail 25 -Encoding UTF8
}
else {
    Write-Host "  No log file found yet."
}

Write-Host ""
if (Test-Path -LiteralPath $failedPath -PathType Leaf) {
    $failedCount = @(Get-Content -LiteralPath $failedPath -Encoding UTF8).Count
    Write-Host "Failed sends: $failedCount"
    Write-Host "Failed-send file: $failedPath"
}
else {
    Write-Host "Failed sends: 0"
}
