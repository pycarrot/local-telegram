Add-Type -AssemblyName System.Net.Http

function Assert-PowerShellVersion {
    if ($PSVersionTable.PSVersion -lt [version]"5.1") {
        throw "Windows PowerShell 5.1 or newer is required."
    }
}

function Get-AppRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-ConfigPath {
    return (Join-Path (Get-AppRoot) "config.json")
}

function Get-LogPath {
    return (Join-Path (Get-AppRoot) "logs\watcher.log")
}

function Get-DataPath {
    param([string]$Name = "")

    $dataDir = Join-Path (Get-AppRoot) "data"
    if ([string]::IsNullOrWhiteSpace($Name)) { return $dataDir }
    return (Join-Path $dataDir $Name)
}

function Get-DefaultConfig {
    [pscustomobject]@{
        telegram = [pscustomobject]@{
            bot_token = ""
            chat_id = ""
        }
        watch = [pscustomobject]@{
            folders = @()
            file_filter = "*.jpg"
            poll_minutes = 2
            send_existing_files_from_last_minutes = 0
        }
        message = [pscustomobject]@{
            caption_template = "Camera: {camera}`nTime: {date} {time}`nFolder: {folder}"
            send_as_document_on_photo_fail = $true
        }
        reliability = [pscustomobject]@{
            retry_count = 3
            retry_delay_seconds = 10
            max_file_ready_wait_seconds = 30
            log_retention_days = 14
            state_retention_days = 30
        }
    }
}

function Get-ConfigValue {
    param($Object, [string]$Name, $Default)

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name -and $null -ne $Object.$Name) {
        return $Object.$Name
    }
    return $Default
}

function Load-Config {
    param([string]$Path = (Get-ConfigPath))

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Config file not found: $Path. Run .\setup.ps1 first."
    }

    $loaded = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) | ConvertFrom-Json
    $defaults = Get-DefaultConfig

    [pscustomobject]@{
        telegram = [pscustomobject]@{
            bot_token = Get-ConfigValue $loaded.telegram "bot_token" $defaults.telegram.bot_token
            chat_id = Get-ConfigValue $loaded.telegram "chat_id" $defaults.telegram.chat_id
        }
        watch = [pscustomobject]@{
            folders = @(Get-ConfigValue $loaded.watch "folders" $defaults.watch.folders) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            file_filter = Get-ConfigValue $loaded.watch "file_filter" $defaults.watch.file_filter
            poll_minutes = [double](Get-ConfigValue $loaded.watch "poll_minutes" $defaults.watch.poll_minutes)
            send_existing_files_from_last_minutes = [int](Get-ConfigValue $loaded.watch "send_existing_files_from_last_minutes" $defaults.watch.send_existing_files_from_last_minutes)
        }
        message = [pscustomobject]@{
            caption_template = Get-ConfigValue $loaded.message "caption_template" $defaults.message.caption_template
            send_as_document_on_photo_fail = [bool](Get-ConfigValue $loaded.message "send_as_document_on_photo_fail" $defaults.message.send_as_document_on_photo_fail)
        }
        reliability = [pscustomobject]@{
            retry_count = [int](Get-ConfigValue $loaded.reliability "retry_count" $defaults.reliability.retry_count)
            retry_delay_seconds = [int](Get-ConfigValue $loaded.reliability "retry_delay_seconds" $defaults.reliability.retry_delay_seconds)
            max_file_ready_wait_seconds = [int](Get-ConfigValue $loaded.reliability "max_file_ready_wait_seconds" $defaults.reliability.max_file_ready_wait_seconds)
            log_retention_days = [int](Get-ConfigValue $loaded.reliability "log_retention_days" $defaults.reliability.log_retention_days)
            state_retention_days = [int](Get-ConfigValue $loaded.reliability "state_retention_days" $defaults.reliability.state_retention_days)
        }
    }
}

function Save-Config {
    param($Config, [string]$Path = (Get-ConfigPath))

    $Config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-Config {
    param($Config, [switch]$RequireFolders, [switch]$RequireExistingFolders)

    if ([string]::IsNullOrWhiteSpace($Config.telegram.bot_token) -or $Config.telegram.bot_token -like "YOUR_*") {
        throw "Telegram bot token is missing in config.json."
    }
    if ([string]::IsNullOrWhiteSpace($Config.telegram.chat_id) -or $Config.telegram.chat_id -like "YOUR_*") {
        throw "Telegram chat/group ID is missing in config.json."
    }
    if ($Config.watch.poll_minutes -le 0) {
        throw "watch.poll_minutes must be a positive number."
    }
    if ($RequireFolders -and @(Get-WatchFolders $Config).Count -eq 0) {
        throw "Add at least one folder to watch.folders in config.json."
    }
    if ($RequireExistingFolders) {
        foreach ($folder in @(Get-WatchFolders $Config)) {
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
                throw "Watch folder not found: $folder"
            }
        }
    }
}

function Write-AppLog {
    param([string]$Message, [string]$Level = "INFO")

    $logPath = Get-LogPath
    $logDir = Split-Path -Parent $logPath
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level.ToUpperInvariant(), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line
}

function Rotate-Logs {
    param($Config)

    $logDir = Split-Path -Parent (Get-LogPath)
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        return
    }

    $days = [int]$Config.reliability.log_retention_days
    if ($days -le 0) { return }
    $cutoff = (Get-Date).AddDays(-1 * $days)
    Get-ChildItem -LiteralPath $logDir -Filter "*.log*" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Wait-FileReady {
    param([string]$Path, [int]$MaxWaitSeconds = 30)

    for ($i = 0; $i -lt $MaxWaitSeconds; $i++) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
        try {
            $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
            $stream.Dispose()
            return $true
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }
    return $false
}

function Get-FileIdentity {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    return "{0}|{1}|{2}" -f $item.FullName.ToLowerInvariant(), $item.Length, $item.LastWriteTimeUtc.Ticks
}

function Get-WatchFolders {
    param($Config)

    return @($Config.watch.folders) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function Get-PhotoMetadata {
    param([string]$Path, $Config)

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    $root = @(Get-WatchFolders $Config) |
        Sort-Object Length -Descending |
        Where-Object { $Path.StartsWith($_.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase) } |
        Select-Object -First 1

    $relative = if ($root) { $Path.Substring($root.TrimEnd("\").Length).TrimStart("\") } else { Split-Path -Leaf $Path }
    $parts = @($relative -split "\\")
    $camera = if ($root) { Split-Path -Leaf $root } else { Split-Path -Leaf (Split-Path -Parent $Path) }
    $date = $item.LastWriteTime.ToString("yyyy-MM-dd")
    $time = $item.LastWriteTime.ToString("HH:mm:ss")

    if ($parts.Count -ge 6 -and $parts[1] -match "^\d{4}-?\d{2}-?\d{2}$" -and $parts[4] -match "^\d{1,2}$" -and $parts[5] -match "^\d{1,2}$") {
        $date = $parts[1]
        $time = "{0}:{1}" -f $parts[4], $parts[5]
    }

    [pscustomobject]@{
        camera = $camera
        date = $date
        time = $time
        folder = Split-Path -Parent $relative
        filename = Split-Path -Leaf $Path
        fullpath = $Path
    }
}

function New-TelegramCaption {
    param([string]$Path, $Config)

    $meta = Get-PhotoMetadata -Path $Path -Config $Config
    $caption = [string]$Config.message.caption_template
    foreach ($name in @("camera", "date", "time", "folder", "filename", "fullpath")) {
        $caption = $caption.Replace("{$name}", [string]$meta.$name)
    }
    return $caption
}

function Get-TelegramErrorMessage {
    param($Response, [string]$Body)

    if ($Body -like "*Unauthorized*") { return "Telegram rejected the bot token. Check config.json." }
    if ($Body -like "*chat not found*" -or $Body -like "*Bad Request*chat*") { return "Telegram chat ID is invalid or the bot cannot access that chat." }
    if ([int]$Response.StatusCode -eq 429 -or $Body -like "*Too Many Requests*") { return "Telegram rate limit hit (HTTP 429). Wait and retry later. $Body" }
    return "Telegram API error: $($Response.StatusCode) $Body"
}

function Invoke-TelegramGetMe {
    param($Config)

    $uri = "https://api.telegram.org/bot$($Config.telegram.bot_token)/getMe"
    try {
        return Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
    }
    catch {
        throw "Telegram getMe failed. Check the bot token and network connection. $($_.Exception.Message)"
    }
}

function Invoke-TelegramMultipart {
    param($Config, [string]$Path, [string]$Method, [string]$FileField, [string]$ContentType, [string]$Caption)

    $uri = "https://api.telegram.org/bot$($Config.telegram.bot_token)/$Method"
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $stream = $null

    try {
        $content.Add((New-Object System.Net.Http.StringContent([string]$Config.telegram.chat_id)), "chat_id")
        $content.Add((New-Object System.Net.Http.StringContent($Caption)), "caption")
        $stream = [System.IO.File]::OpenRead($Path)
        $fileContent = New-Object System.Net.Http.StreamContent($stream)
        if ($ContentType) {
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($ContentType)
        }
        $content.Add($fileContent, $FileField, [System.IO.Path]::GetFileName($Path))
        $response = $client.PostAsync($uri, $content).Result
        $body = $response.Content.ReadAsStringAsync().Result
        if (-not $response.IsSuccessStatusCode) {
            throw (Get-TelegramErrorMessage -Response $response -Body $body)
        }
        return $body
    }
    finally {
        if ($stream) { $stream.Dispose() }
        $content.Dispose()
        $client.Dispose()
    }
}

function Send-TelegramFile {
    param($Config, [string]$Path, [string]$Caption)

    $attempts = [Math]::Max(1, [int]$Config.reliability.retry_count)
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            Invoke-TelegramMultipart -Config $Config -Path $Path -Method "sendPhoto" -FileField "photo" -ContentType "image/jpeg" -Caption $Caption | Out-Null
            return "photo"
        }
        catch {
            $message = $_.Exception.Message
            if ($message -like "*IMAGE_PROCESS_FAILED*" -and $Config.message.send_as_document_on_photo_fail) {
                Write-AppLog "sendPhoto failed with IMAGE_PROCESS_FAILED, trying sendDocument: $Path" "WARN"
                Invoke-TelegramMultipart -Config $Config -Path $Path -Method "sendDocument" -FileField "document" -ContentType $null -Caption $Caption | Out-Null
                return "document"
            }
            if ($i -ge $attempts) { throw }
            Write-AppLog "Send attempt $i failed for ${Path}: $message" "WARN"
            Start-Sleep -Seconds ([Math]::Max(1, [int]$Config.reliability.retry_delay_seconds))
        }
    }
}

function Load-State {
    $statePath = Get-DataPath "state.json"
    if (-not (Test-Path -LiteralPath (Get-DataPath))) {
        New-Item -ItemType Directory -Force -Path (Get-DataPath) | Out-Null
    }
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return @{ sent = @{} }
    }

    try {
        $raw = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @{ sent = @{} } }
        $loaded = $raw | ConvertFrom-Json
        $sent = @{}
        if ($loaded.sent) {
            foreach ($prop in $loaded.sent.PSObject.Properties) {
                $sent[$prop.Name] = $prop.Value
            }
        }
        return @{ sent = $sent }
    }
    catch {
        Write-AppLog "State file could not be read and will be recreated: $($_.Exception.Message)" "WARN"
        return @{ sent = @{} }
    }
}

function Save-State {
    param($State)

    if (-not (Test-Path -LiteralPath (Get-DataPath))) {
        New-Item -ItemType Directory -Force -Path (Get-DataPath) | Out-Null
    }
    ([pscustomobject]@{ sent = $State.sent }) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Get-DataPath "state.json") -Encoding UTF8
}

function Remove-OldState {
    param($State, $Config)

    $days = [int]$Config.reliability.state_retention_days
    if ($days -le 0) { return }
    $cutoff = (Get-Date).AddDays(-1 * $days)
    foreach ($key in @($State.sent.Keys)) {
        try {
            if ([datetime]$State.sent[$key].sent_at -lt $cutoff) {
                $State.sent.Remove($key)
            }
        }
        catch {
        }
    }
}

function Add-SentState {
    param($State, [string]$Path)

    $State.sent[(Get-FileIdentity -Path $Path)] = [pscustomobject]@{
        path = $Path
        sent_at = (Get-Date).ToString("o")
    }
}

function Test-AlreadySent {
    param($State, [string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $true }
    return $State.sent.ContainsKey((Get-FileIdentity -Path $Path))
}

function Add-FailedSend {
    param([string]$Path, [string]$ErrorMessage)

    if (-not (Test-Path -LiteralPath (Get-DataPath))) {
        New-Item -ItemType Directory -Force -Path (Get-DataPath) | Out-Null
    }
    $entry = [pscustomobject]@{
        path = $Path
        failed_at = (Get-Date).ToString("o")
        error = $ErrorMessage
    }
    Add-Content -LiteralPath (Get-DataPath "failed.jsonl") -Value ($entry | ConvertTo-Json -Compress) -Encoding UTF8
}

function Test-IsMappedDrivePath {
    param([string]$Path)

    if ($Path -notmatch "^([A-Za-z]):\\") {
        return $false
    }

    $driveName = $Matches[1]
    $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
    if (-not $drive -or $drive.Provider.Name -ne "FileSystem") {
        return $false
    }

    $displayRoot = $null
    if ($drive.PSObject.Properties.Name -contains "DisplayRoot") {
        $displayRoot = $drive.DisplayRoot
    }

    return (
        (-not [string]::IsNullOrWhiteSpace($displayRoot) -and $displayRoot -like "\\*") -or
        (-not [string]::IsNullOrWhiteSpace($drive.Root) -and $drive.Root -like "\\*")
    )
}
