param(
    [Parameter(Mandatory = $true)]
    [string]$PhotoPath
)

. "$PSScriptRoot\scripts\common.ps1"

Assert-PowerShellVersion

try {
    $config = Load-Config
    Assert-Config -Config $config

    if (-not (Test-Path -LiteralPath $PhotoPath -PathType Leaf)) {
        throw "Photo not found: $PhotoPath"
    }

    $caption = "Test: $(Split-Path -Leaf $PhotoPath)"
    $sentAs = Send-TelegramFile -Config $config -Path $PhotoPath -Caption $caption
    Write-Host "Success. Sent test photo as ${sentAs}: $PhotoPath"
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
