[CmdletBinding()]
Param (
    [string] $Configuration = "Debug",

    [ValidateSet("Full", "Quick")]
    [string] $Mode = "Full",

    [switch] $Interactive,

    [switch] $NoRestore
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$projectFile = (Get-Item "$root\src\Environment\Website\Website.csproj").FullName
$deployFolderPath = "$root\docker\deploy\website"

$debugSymbols = "false"
$debugType = "none"
$defineDebug = "false"

if ($Configuration.ToUpper() -eq "DEBUG") {
    $debugSymbols = "true"
    $debugType = "full"
    $defineDebug = "true"
}

$msbuildPaths = Resolve-Path "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\MSBuild\*\bin\msbuild.exe" -ErrorAction SilentlyContinue

if ($msbuildPaths.Length -eq 0) {
    $msbuildPaths = Resolve-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\*\MSBuild\*\bin\msbuild.exe" -ErrorAction SilentlyContinue
}

if ($msbuildPaths.Length -eq 0) {
    $msbuildPaths = Resolve-Path "${env:ProgramFiles}\Microsoft Visual Studio\*\*\MSBuild\*\bin\msbuild.exe" -ErrorAction SilentlyContinue
}

if ($msbuildPaths.Length -eq 0) {
    $msbuildPaths = Resolve-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\MSBuild\*\bin\msbuild.exe" -ErrorAction SilentlyContinue
}

if ($msbuildPaths.Length -eq 0) {
    throw "MSBuild not found. Install Visual Studio 2019 or newer with the ASP.NET and web development workload."
}

$msbuildPath = $msbuildPaths[$msbuildPaths.Length - 1]

if (-not (Test-Path $deployFolderPath)) {
    New-Item -ItemType Directory -Force -Path $deployFolderPath | Out-Null
}
$deployFolder = (Get-Item $deployFolderPath).FullName

Write-Host "**********************************************************"
Write-Host "Project:       $projectFile"
Write-Host "Deploy folder: $deployFolder"
Write-Host "Configuration: $Configuration"
Write-Host "Mode:          $Mode"
Write-Host "Debug:         $debugSymbols / $debugType"
Write-Host "MSBuild:       $msbuildPath"
Write-Host "**********************************************************"

if ($Mode -eq "Full") {
    Write-Host "$deployFolder cleaning..." -ForegroundColor Green
    Get-ChildItem -Path $deployFolder -Exclude ".gitkeep" -Force | Remove-Item -Force -Recurse
}

if (-not $NoRestore) {
    Write-Host "Restoring NuGet packages..." -ForegroundColor Green

    $restoreArgs = @($projectFile, "-t:Restore", "/nodeReuse:false")
    if ($Interactive) {
        $restoreArgs += "-interactive"
    }

    & $msbuildPath $restoreArgs
    if ($LASTEXITCODE -ne 0) {
        throw "NuGet restore failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Building and publishing..." -ForegroundColor Green

$publishArgs = @(
    $projectFile,
    "/m",
    "/nodeReuse:false",
    "/p:Configuration=$Configuration",
    "/p:DeployOnBuild=True",
    "/p:DeployDefaultTarget=WebPublish",
    "/p:WebPublishMethod=FileSystem",
    "/p:PublishUrl=$deployFolder",
    "/p:DebugSymbols=$debugSymbols",
    "/p:DebugType=$debugType",
    "/p:DefineDebug=$defineDebug",
    "/p:AutoPublish=false",
    "/p:PrecompileRazorFiles=true"
)

if ($debugSymbols -eq "false") {
    $publishArgs += "/p:AllowedReferenceRelatedFileExtensions=none"
}

& $msbuildPath $publishArgs

if ($LASTEXITCODE -ne 0) {
    throw "Publish failed with exit code $LASTEXITCODE"
}

Write-Host "Published project:" -ForegroundColor Green
Write-Host $projectFile -ForegroundColor Green
Write-Host "to folder:" -ForegroundColor Green
Write-Host $deployFolder -ForegroundColor Green
Write-Host "successfully." -ForegroundColor Green

$envFile = "$root\.env"
if ((Test-Path $envFile) -and (Select-String -Path $envFile -Pattern '^\s*FILLER\s*=\s*1\s*$' -Quiet)) {
    & "$root\docker\filler.ps1" -Path $deployFolder
}
