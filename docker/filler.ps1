[CmdletBinding()]
Param (
    [string] $Path = "$PSScriptRoot\deploy\website",

    [int] $Count = 20000,

    [int] $Size = 102400
)

$ErrorActionPreference = "Stop"

$fillerPath = Join-Path $Path "bin\zz-filler"

if ((Test-Path $fillerPath) -and @(Get-ChildItem $fillerPath -File).Count -ge $Count) {
    Write-Host "Filler already present: $fillerPath" -ForegroundColor Green
    return
}

New-Item -ItemType Directory -Force -Path $fillerPath | Out-Null

Write-Host "Populating filler: $fillerPath ($Count x $Size bytes)..." -ForegroundColor Green

foreach ($i in 1..$Count) {
    $file = Join-Path $fillerPath "f$i.bin"
    if (-not (Test-Path $file)) {
        $stream = [System.IO.File]::Create($file)
        try {
            $stream.SetLength($Size)
        }
        finally {
            $stream.Dispose()
        }
    }
}

Write-Host "Filler populated: $fillerPath" -ForegroundColor Green
