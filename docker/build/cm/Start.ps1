$ErrorActionPreference = "Stop"

if (Test-Path "C:\deploy") {
    Write-Host "$(Get-Date -Format 'HH:mm:ss:fff'): Pre-syncing deploy folder to wwwroot..."
    robocopy "C:\deploy" "C:\inetpub\wwwroot" /E /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { Write-Warning "robocopy failed with exit code $LASTEXITCODE" }
    $LASTEXITCODE = 0
    Write-Host "$(Get-Date -Format 'HH:mm:ss:fff'): Pre-sync complete."
}

& C:\tools\entrypoints\iis\Development.ps1
