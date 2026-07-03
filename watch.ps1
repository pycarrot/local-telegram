. "$PSScriptRoot\scripts\common.ps1"

Assert-PowerShellVersion

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
}
catch {
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Get-LogPath)), (Get-DataPath) | Out-Null

$config = Load-Config
Assert-Config -Config $config -RequireFolders
Rotate-Logs -Config $config

$state = Load-State
Remove-OldState -State $state -Config $config
Save-State -State $state

$queue = New-Object System.Collections.Queue
$queued = @{}
$watchers = @{}
$nextPoll = Get-Date

function Add-QueueItem {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if ($queued.ContainsKey($Path)) { return }
    if (Test-AlreadySent -State $state -Path $Path) { return }
    $queued[$Path] = $true
    $queue.Enqueue($Path)
}

function Register-WatchFolder {
    param([string]$Folder, [int]$Index)

    if ($watchers.ContainsKey($Folder)) { return }
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        Write-AppLog "Watch folder not found, will retry later: $Folder" "WARN"
        return
    }

    try {
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $Folder
        $watcher.Filter = $config.watch.file_filter
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents = $true
        Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "LocalTelegramCreated$Index" | Out-Null
        Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier "LocalTelegramChanged$Index" | Out-Null
        $watchers[$Folder] = [pscustomobject]@{ watcher = $watcher; index = $Index }
        Write-AppLog "Watching: $Folder"
    }
    catch {
        Write-AppLog "Could not watch ${Folder}: $($_.Exception.Message)" "WARN"
    }
}

function Poll-WatchFolders {
    param([datetime]$Since)

    $folders = @(Get-WatchFolders $config)
    for ($i = 0; $i -lt $folders.Count; $i++) {
        $folder = $folders[$i]
        Register-WatchFolder -Folder $folder -Index $i

        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            Write-AppLog "Poll skipped, watch folder unavailable: $folder" "WARN"
            continue
        }

        try {
            Get-ChildItem -LiteralPath $folder -Filter $config.watch.file_filter -Recurse -File -ErrorAction Stop |
                Where-Object { $_.LastWriteTime -ge $Since } |
                ForEach-Object { Add-QueueItem -Path $_.FullName }
        }
        catch {
            Write-AppLog "Poll failed for ${folder}: $($_.Exception.Message)" "WARN"
        }
    }
}

function Receive-WatcherEvents {
    foreach ($entry in @($watchers.Values)) {
        foreach ($source in @("LocalTelegramCreated$($entry.index)", "LocalTelegramChanged$($entry.index)")) {
            $events = Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
            foreach ($event in $events) {
                $path = $event.SourceEventArgs.FullPath
                Write-AppLog "Detected: $path"
                Add-QueueItem -Path $path
                Remove-Event -EventIdentifier $event.EventIdentifier
            }
        }
    }
}

function Send-QueuedFiles {
    while ($queue.Count -gt 0) {
        $path = $queue.Dequeue()
        $queued.Remove($path)

        if (Test-AlreadySent -State $state -Path $path) { continue }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Write-AppLog "File disappeared before sending: $path" "WARN"
            continue
        }
        if (-not (Wait-FileReady -Path $path -MaxWaitSeconds $config.reliability.max_file_ready_wait_seconds)) {
            Write-AppLog "File was not ready before timeout: $path" "WARN"
            Add-FailedSend -Path $path -ErrorMessage "File was not ready before timeout."
            continue
        }

        try {
            $caption = New-TelegramCaption -Path $path -Config $config
            $sentAs = Send-TelegramFile -Config $config -Path $path -Caption $caption
            Add-SentState -State $state -Path $path
            Save-State -State $state
            Write-AppLog "Sent as ${sentAs}: $path"
        }
        catch {
            Write-AppLog "Permanent send failure for ${path}: $($_.Exception.Message)" "ERROR"
            Add-FailedSend -Path $path -ErrorMessage $_.Exception.Message
        }
    }
}

try {
    Unregister-Event -SourceIdentifier "LocalTelegram*" -ErrorAction SilentlyContinue
    Remove-Event -SourceIdentifier "LocalTelegram*" -ErrorAction SilentlyContinue

    $folders = @(Get-WatchFolders $config)
    for ($i = 0; $i -lt $folders.Count; $i++) {
        Register-WatchFolder -Folder $folders[$i] -Index $i
    }

    if ($config.watch.send_existing_files_from_last_minutes -gt 0) {
        $since = (Get-Date).AddMinutes(-1 * [int]$config.watch.send_existing_files_from_last_minutes)
        Poll-WatchFolders -Since $since
    }

    Write-AppLog "Local Telegram watcher started."

    while ($true) {
        Receive-WatcherEvents
        Send-QueuedFiles

        if ((Get-Date) -ge $nextPoll) {
            $since = (Get-Date).AddMinutes(-1 * [double]$config.watch.poll_minutes)
            Poll-WatchFolders -Since $since
            Write-AppLog "Poll scan completed."
            $nextPoll = (Get-Date).AddMinutes([double]$config.watch.poll_minutes)
        }

        Start-Sleep -Seconds 1
    }
}
finally {
    foreach ($entry in @($watchers.Values)) {
        $entry.watcher.Dispose()
    }
}
