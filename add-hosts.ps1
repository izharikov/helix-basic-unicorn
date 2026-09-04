#Requires -RunAsAdministrator
[CmdletBinding()]
Param (
    [string]$HostName = "helix-sample.com"
)

$ErrorActionPreference = "Stop"

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

$hostNames = @(
    "cd.$($HostName)",
    "cm.$($HostName)",
    "id.$($HostName)",
    "www.$($HostName)",
    "preview.$($HostName)"
)

$content = Get-Content $hostsPath -Encoding UTF8
$added = @()

foreach ($name in $hostNames) {
    if ($content | Where-Object { $_ -match "^\s*[\d\.:]+\s+$([regex]::Escape($name))\s*$" }) {
        Write-Host "Already present: $name" -ForegroundColor Gray
        continue
    }
    $content += "127.0.0.1 $name"
    $added += $name
}

if ($added.Count -gt 0) {
    [System.IO.File]::WriteAllLines($hostsPath, $content)
    $added | ForEach-Object { Write-Host "Added: 127.0.0.1 $_" -ForegroundColor Green }
}
else {
    Write-Host "Nothing to do." -ForegroundColor Green
}
