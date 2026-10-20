$ErrorActionPreference = "Stop"

if (Test-Path "C:\deploy") {
    Write-Host "$(Get-Date -Format 'HH:mm:ss:fff'): Pre-syncing deploy folder to wwwroot..."
    robocopy "C:\deploy" "C:\inetpub\wwwroot" /E /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -ge 8) { Write-Warning "robocopy failed with exit code $LASTEXITCODE" }
    $LASTEXITCODE = 0
    Write-Host "$(Get-Date -Format 'HH:mm:ss:fff'): Pre-sync complete."
}

if ($env:ASPNET_TEMP_DIRECTORY) {
    Write-Host "$(Get-Date -Format 'HH:mm:ss:fff'): Setting ASP.NET tempDirectory to $env:ASPNET_TEMP_DIRECTORY"
    if (Get-ChildItem $env:ASPNET_TEMP_DIRECTORY -Force) {
        takeown /F "$env:ASPNET_TEMP_DIRECTORY\*" /R /D Y | Out-Null
        icacls "$env:ASPNET_TEMP_DIRECTORY\*" /reset /T /C /Q | Out-Null
    }
    icacls $env:ASPNET_TEMP_DIRECTORY /grant "IIS_IUSRS:(OI)(CI)M" | Out-Null
    $webConfigPath = "C:\inetpub\wwwroot\Web.config"
    [xml]$webConfig = Get-Content $webConfigPath
    $webConfig.configuration.'system.web'.compilation.SetAttribute("tempDirectory", $env:ASPNET_TEMP_DIRECTORY)
    $webConfig.Save($webConfigPath)
}

& C:\tools\entrypoints\iis\Development.ps1
