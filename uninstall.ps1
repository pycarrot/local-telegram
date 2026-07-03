$taskName = "LocalTelegramNotifier"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed Scheduled Task: $taskName"
}
else {
    Write-Host "Scheduled Task was not installed: $taskName"
}

$removeConfig = Read-Host "Delete config.json? (y/N)"
if ($removeConfig -match "^(y|yes)$") {
    $path = Join-Path $PSScriptRoot "config.json"
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        Write-Host "Removed: $path"
    }
}
else {
    Write-Host "Kept config.json."
}

$removeLogs = Read-Host "Delete logs folder? (y/N)"
if ($removeLogs -match "^(y|yes)$") {
    $path = Join-Path $PSScriptRoot "logs"
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Removed: $path"
    }
}
else {
    Write-Host "Kept logs folder."
}

$removeData = Read-Host "Delete data folder? (y/N)"
if ($removeData -match "^(y|yes)$") {
    $path = Join-Path $PSScriptRoot "data"
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Removed: $path"
    }
}
else {
    Write-Host "Kept data folder."
}
