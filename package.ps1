. "$PSScriptRoot\scripts\common.ps1"

Assert-PowerShellVersion

$version = "v0.1.0-beta"
$distDir = Join-Path $PSScriptRoot "dist"
$zipPath = Join-Path $distDir "local-telegram-$version.zip"
$stageDir = Join-Path $distDir "package-stage"

$includeFiles = @(
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "SECURITY.md",
    "RELEASE_CHECKLIST.md",
    ".gitignore",
    "config.example.json",
    "setup.ps1",
    "install.ps1",
    "uninstall.ps1",
    "start.ps1",
    "stop.ps1",
    "status.ps1",
    "send-test.ps1",
    "watch.ps1",
    "scripts/common.ps1",
    "logs/.gitkeep",
    "data/.gitkeep"
)

if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $distDir, $stageDir | Out-Null

foreach ($relativePath in $includeFiles) {
    $source = Join-Path $PSScriptRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Package source file not found: $relativePath"
    }

    $destination = Join-Path $stageDir $relativePath
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    }

    Copy-Item -LiteralPath $source -Destination $destination -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $zipPath)
Remove-Item -LiteralPath $stageDir -Recurse -Force

Write-Host "Created release package: $zipPath"
