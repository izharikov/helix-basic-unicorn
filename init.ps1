[CmdletBinding()]
Param (
    [string]
    $LicenseXmlPath = "c:\license\license.xml",

    [string]
    $HostName = "helix-sample.com",

    # We do not need to use [SecureString] here since the value will be stored unencrypted in .env,
    # and used only for transient local example environment.
    [string]
    $SitecoreAdminPassword = "b"
)

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$envFile = Join-Path $root ".env"
$envExampleFile = Join-Path $root ".env.example"
$licenseFolder = Join-Path $root "docker\license"

if (-not (Test-Path $envFile)) {
    if (-not (Test-Path $envExampleFile)) {
        throw "Did not find $envFile or $envExampleFile"
    }
    Copy-Item $envExampleFile $envFile
}

###############################
# Helpers
###############################

function Get-RandomString {
    Param (
        [int]$Length = 8,
        [switch]$DisallowSpecial,
        [switch]$EnforceComplexity
    )

    $lower = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $digit = "0123456789".ToCharArray()
    $special = "!#%&()*+,-./:;<=>?@[]^_{|}~".ToCharArray()

    $pool = $lower + $upper + $digit
    if (-not $DisallowSpecial) {
        $pool += $special
    }

    do {
        $value = -join (1..$Length | ForEach-Object { $pool | Get-Random })
    } while ($EnforceComplexity -and -not (
            ($value -cmatch "[a-z]") -and ($value -cmatch "[A-Z]") -and ($value -match "[0-9]")
        ))

    return $value
}

function Set-EnvFileVariable {
    Param (
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [string]$Path = $envFile
    )

    $content = Get-Content $Path -Encoding UTF8
    $found = $false
    $content = $content | ForEach-Object {
        if ($_ -match "^\s*$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$Value"
        }
        else {
            $_
        }
    }
    if (-not $found) {
        $content += "$Key=$Value"
    }
    [System.IO.File]::WriteAllLines($Path, $content)
}

function New-IdentityServerCertificateAsBase64String {
    Param (
        [Parameter(Mandatory = $true)][string]$DnsName,
        [Parameter(Mandatory = $true)][securestring]$Password
    )

    $cert = New-SelfSignedCertificate `
        -DnsName $DnsName `
        -FriendlyName "Sitecore Identity Server ($DnsName)" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy Exportable `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
        -NotAfter (Get-Date).AddYears(5)

    $pfxPath = Join-Path ([System.IO.Path]::GetTempPath()) ("sitecore-id-{0}.pfx" -f ([guid]::NewGuid()))
    try {
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $Password | Out-Null
        return [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($pfxPath))
    }
    finally {
        if (Test-Path $pfxPath) { Remove-Item $pfxPath -Force }
        Remove-Item ("Cert:\CurrentUser\My\{0}" -f $cert.Thumbprint) -Force -ErrorAction SilentlyContinue
    }
}

###############################
# License
###############################

Write-Host "Preparing license..." -ForegroundColor Green

if (-not (Test-Path $LicenseXmlPath)) {
    throw "Did not find $LicenseXmlPath"
}
if (-not (Test-Path $LicenseXmlPath -PathType Leaf)) {
    $LicenseXmlPath = Join-Path $LicenseXmlPath "license.xml"
    if (-not (Test-Path $LicenseXmlPath -PathType Leaf)) {
        throw "Did not find license.xml in the supplied folder"
    }
}

if (-not (Test-Path $licenseFolder)) {
    New-Item $licenseFolder -ItemType Directory | Out-Null
}
Copy-Item $LicenseXmlPath (Join-Path $licenseFolder "license.xml") -Force

###############################
# Populate the environment file
###############################

Write-Host "Populating required .env file variables..." -ForegroundColor Green

Set-EnvFileVariable "HOST_LICENSE_FOLDER" -Value ".\docker\license"

Set-EnvFileVariable "CD_HOST" -Value "cd.$($HostName)"
Set-EnvFileVariable "CM_HOST" -Value "cm.$($HostName)"
Set-EnvFileVariable "ID_HOST" -Value "id.$($HostName)"
Set-EnvFileVariable "SITE_HOST" -Value "www.$($HostName)"
Set-EnvFileVariable "CM_SITE_HOST" -Value "preview.$($HostName)"

Set-EnvFileVariable "SITECORE_ADMIN_PASSWORD" -Value $SitecoreAdminPassword
Set-EnvFileVariable "SQL_SA_PASSWORD" -Value (Get-RandomString 12 -DisallowSpecial -EnforceComplexity)
Set-EnvFileVariable "TELERIK_ENCRYPTION_KEY" -Value (Get-RandomString 128 -DisallowSpecial)
Set-EnvFileVariable "MEDIA_REQUEST_PROTECTION_SHARED_SECRET" -Value (Get-RandomString 64 -DisallowSpecial)
Set-EnvFileVariable "SITECORE_IDSECRET" -Value (Get-RandomString 64 -DisallowSpecial)
Set-EnvFileVariable "UNICORN_SHARED_SECRET" -Value (Get-RandomString 64 -DisallowSpecial)
Set-EnvFileVariable "SITECORE_GRAPHQL_UPLOADMEDIAOPTIONS_ENCRYPTIONKEY" -Value (Get-RandomString 16 -DisallowSpecial)

$idCertPassword = Get-RandomString 12 -DisallowSpecial
Set-EnvFileVariable "SITECORE_ID_CERTIFICATE" -Value (New-IdentityServerCertificateAsBase64String -DnsName "localhost" -Password (ConvertTo-SecureString -String $idCertPassword -Force -AsPlainText))
Set-EnvFileVariable "SITECORE_ID_CERTIFICATE_PASSWORD" -Value $idCertPassword

##################################
# Configure TLS/HTTPS certificates
##################################

$certsFolder = Join-Path $root "docker\traefik\certs"
if (-not (Test-Path $certsFolder)) {
    New-Item $certsFolder -ItemType Directory | Out-Null
}

Push-Location $certsFolder
try {
    $mkcert = ".\mkcert.exe"
    if ($null -ne (Get-Command mkcert.exe -ErrorAction SilentlyContinue)) {
        # mkcert installed in PATH
        $mkcert = "mkcert"
    }
    elseif (-not (Test-Path $mkcert)) {
        Write-Host "Downloading and installing mkcert certificate tool..." -ForegroundColor Green
        Invoke-WebRequest "https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-windows-amd64.exe" -UseBasicParsing -OutFile mkcert.exe
    }

    Write-Host "Generating Traefik TLS certificate..." -ForegroundColor Green
    & $mkcert -install
    & $mkcert "*.$($HostName)"
}
catch {
    Write-Host "An error occurred while attempting to generate TLS certificate: $_" -ForegroundColor Red
}
finally {
    Pop-Location
}

################################
# Windows hosts file entries
################################

$hostNames = @(
    "cd.$($HostName)",
    "cm.$($HostName)",
    "id.$($HostName)",
    "www.$($HostName)",
    "preview.$($HostName)"
)

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$missing = $hostNames | Where-Object { -not (Select-String -Path $hostsPath -Pattern ([regex]::Escape($_)) -Quiet) }

if ($missing) {
    Write-Host ""
    Write-Host "Hosts file entries are missing. Run add-hosts.ps1 from an ELEVATED PowerShell:" -ForegroundColor Yellow
    Write-Host "    powershell -ExecutionPolicy Bypass -File `"$(Join-Path $root 'add-hosts.ps1')`"" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Missing entries:" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "    127.0.0.1 $_" -ForegroundColor Yellow }
}
else {
    Write-Host "Windows hosts file entries already present." -ForegroundColor Green
}

Write-Host "Done!" -ForegroundColor Green
