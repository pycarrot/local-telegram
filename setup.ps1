. "$PSScriptRoot\scripts\common.ps1"

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "Windows PowerShell 5.1 or newer is required."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Get-LogPath)), (Get-DataPath) | Out-Null

Write-Host ""
Write-Host "Local Telegram Notifier setup"
Write-Host "This setup will help you send new camera photos to Telegram."
Write-Host ""

$configPath = Get-ConfigPath
$existingConfig = $null
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $existingConfig = Load-Config
        Write-Host "Found existing config.json. Press Enter at prompts to keep existing values."
    }
    catch {
        Write-Host "Existing config.json could not be loaded: $($_.Exception.Message)"
    }
}

$tokenPrompt = if ($existingConfig -and -not [string]::IsNullOrWhiteSpace($existingConfig.telegram.bot_token)) { "Telegram bot token [keep existing]" } else { "Telegram bot token" }
$token = Read-Host $tokenPrompt
if ([string]::IsNullOrWhiteSpace($token) -and $existingConfig) {
    $token = $existingConfig.telegram.bot_token
}
while ([string]::IsNullOrWhiteSpace($token) -or $token -like "YOUR_*") {
    $token = Read-Host "Telegram bot token is required"
}

$chatPrompt = if ($existingConfig -and -not [string]::IsNullOrWhiteSpace($existingConfig.telegram.chat_id)) { "Telegram chat/group ID [keep existing]" } else { "Telegram chat/group ID" }
$chatId = Read-Host $chatPrompt
if ([string]::IsNullOrWhiteSpace($chatId) -and $existingConfig) {
    $chatId = $existingConfig.telegram.chat_id
}
while ([string]::IsNullOrWhiteSpace($chatId) -or $chatId -like "YOUR_*") {
    $chatId = Read-Host "Telegram chat/group ID is required"
}

$folders = @()
$existingFolders = if ($existingConfig) { @(Get-WatchFolders $existingConfig) } else { @() }
if ($existingFolders.Count -gt 0) {
    Write-Host "Existing watch folders:"
    foreach ($existingFolder in $existingFolders) {
        Write-Host "  $existingFolder"
    }
    $keepFolders = Read-Host "Keep these watch folders? (Y/n)"
    if ($keepFolders -notmatch "^(n|no)$") {
        $folders = $existingFolders
    }
}

if ($folders.Count -eq 0) {
    do {
        $folder = Read-Host "Watch folder path"
        if ([string]::IsNullOrWhiteSpace($folder)) {
            Write-Host "Please enter a folder path."
        }
        elseif (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            Write-Host "Folder does not exist: $folder"
        }
        else {
            $folders += $folder
        }

        if ($folders.Count -gt 0) {
            $more = Read-Host "Add another watch folder? (y/N)"
        }
        else {
            $more = "y"
        }
    } while ($more -match "^(y|yes)$")
}

$defaultFileFilter = if ($existingConfig) { $existingConfig.watch.file_filter } else { "*.jpg" }
$fileFilter = Read-Host "File filter [$defaultFileFilter]"
if ([string]::IsNullOrWhiteSpace($fileFilter)) { $fileFilter = $defaultFileFilter }

$defaultPollMinutes = if ($existingConfig) { [string]$existingConfig.watch.poll_minutes } else { "2" }
$pollText = Read-Host "Poll interval in minutes [$defaultPollMinutes]"
if ([string]::IsNullOrWhiteSpace($pollText)) { $pollText = $defaultPollMinutes }
$pollMinutes = 0.0
while (-not [double]::TryParse($pollText, [ref]$pollMinutes) -or $pollMinutes -le 0) {
    $pollText = Read-Host "Poll interval must be a positive number"
}

$defaultRecentMinutes = if ($existingConfig) { [string]$existingConfig.watch.send_existing_files_from_last_minutes } else { "0" }
$recentText = Read-Host "Send recent files on startup, minutes [$defaultRecentMinutes]"
if ([string]::IsNullOrWhiteSpace($recentText)) { $recentText = $defaultRecentMinutes }
$recentMinutes = 0
while (-not [int]::TryParse($recentText, [ref]$recentMinutes) -or $recentMinutes -lt 0) {
    $recentText = Read-Host "Recent file minutes must be 0 or greater"
}

$config = if ($existingConfig) { $existingConfig } else { Get-DefaultConfig }
$config.telegram.bot_token = $token
$config.telegram.chat_id = $chatId
$config.watch.folders = $folders
$config.watch.file_filter = $fileFilter
$config.watch.poll_minutes = $pollMinutes
$config.watch.send_existing_files_from_last_minutes = $recentMinutes
Assert-Config -Config $config -RequireFolders -RequireExistingFolders

$tmpConfigPath = "$configPath.tmp"
Save-Config -Config $config -Path $tmpConfigPath
Move-Item -LiteralPath $tmpConfigPath -Destination $configPath -Force

Write-Host ""
Write-Host "Saved config.json."

try {
    $me = Invoke-TelegramGetMe -Config $config
    Write-Host "Telegram token is valid. Bot: $($me.result.username)"
}
catch {
    Write-Host "Telegram validation failed: $($_.Exception.Message)"
    Write-Host "You can fix config.json and run setup again."
}

$testNow = Read-Host "Send a test photo now? (y/N)"
if ($testNow -match "^(y|yes)$") {
    $photoPath = Read-Host "Test photo path"
    & "$PSScriptRoot\send-test.ps1" -PhotoPath $photoPath
}

$installNow = Read-Host "Install auto-start now? (y/N)"
if ($installNow -match "^(y|yes)$") {
    & "$PSScriptRoot\install.ps1"
}

Write-Host ""
Write-Host "Setup complete."
Write-Host "Next commands:"
Write-Host "  .\start.ps1"
Write-Host "  .\stop.ps1"
Write-Host "  .\status.ps1"
Write-Host "  .\uninstall.ps1"
