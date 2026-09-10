param(
    [Parameter(Mandatory)] [string] $Module,
    [Parameter(Mandatory)] [string] $RenderingName,
    [Parameter(Mandatory)] [string] $ControllerClass,
    [Parameter(Mandatory)] [string] $ActionName,
    [Parameter(Mandatory)] [string] $DatasourceTemplatePath,
    [Parameter(Mandatory)] [string] $DatasourceModelInterface,
    [string] $Layer = "Feature",
    [string] $DatasourceLocation,
    [string] $Icon,
    [switch] $SkipPlaceholder
)

$ErrorActionPreference = "Stop"

function ConvertTo-ItemPath {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Path)

    $match = [regex]::Match($Path.Replace('\', '/'), '(?i)/sitecore/.*$')
    if ($match.Success) { return $match.Value }
    return $Path
}

$DatasourceTemplatePath = ConvertTo-ItemPath $DatasourceTemplatePath
if ($DatasourceLocation) { $DatasourceLocation = ConvertTo-ItemPath $DatasourceLocation }

$script:Defaults = @{
    namespacePrefix = $null
    languages       = @("en")
    serialization   = @{ root = $null; renderings = $null }
    website         = @{ root = "src/{layer}/{module}/website"; csproj = "src/{layer}/{module}/website/{prefix}.{layer}.{module}.csproj"; views = "Views" }
    rendering       = @{ defaultDatasourceLocation = $null; defaultIcon = $null; placeholderSettings = $null; controllerNamespace = "{prefix}.{layer}.{module}.Controllers"; modelNamespace = "{prefix}.{layer}.{module}.Models" }
}

$script:Required = @("namespacePrefix", "serialization.root", "serialization.renderings", "rendering.defaultDatasourceLocation")

function Find-DatasourceLocation {
    try {
        $src = Join-Path (Get-RepoRoot) "src"
        if (!(Test-Path $src)) { return @() }

        $values = Get-ChildItem -Path $src -Recurse -Filter "*.yml" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\\(obj|bin|node_modules)\\' } |
            ForEach-Object {
                $match = [regex]::Match((Get-Content $_.FullName -Raw),
                    '(?m)^- ID: "b5b27af1-25ef-405c-87ce-369b3a004016"\r?\n\s+Hint: Datasource Location\r?\n\s+Value: (.+?)\r?$')
                if ($match.Success) { $match.Groups[1].Value.Trim() }
            }

        return @($values | Where-Object { $_ } | Group-Object | Sort-Object Count -Descending |
            Select-Object -First 3 | ForEach-Object { "$($_.Name)   ($($_.Count) rendering(s))" })
    } catch { return @() }
}

function Show-ConfigRequest([string] $Reason) {
    $file = Join-Path $PSScriptRoot "config.json"
    Write-Host "[CONFIG] $Reason" -ForegroundColor Yellow

    $observed = Find-DatasourceLocation
    if ($observed) {
        Write-Host ""
        Write-Host "Datasource Location values already in this solution:" -ForegroundColor Yellow
        foreach ($value in $observed) { Write-Host "  $value" -ForegroundColor Yellow }
    }

    Write-Host @"

Write $file from this solution, then run the command again:

{
  "namespacePrefix": "",              first segment the src/*/*/website/*.csproj files share
                                      (Foo.Feature.Bar.csproj -> "Foo")
  "serialization": {
    "root": "",                       path from the repo root to a module's serialized items,
                                      with {layer} {module} {prefix} placeholders
                                      (e.g. "src/{layer}/{module}/serialization")
    "renderings": ""                  fragment under root holding rendering items
                                      ("renderings/{module}" when per-module, else "renderings")
  },
  "languages": ["en"],                the "- Language:" values in the existing .yml items
  "website": {
    "root": "src/{layer}/{module}/website",
    "csproj": "src/{layer}/{module}/website/{prefix}.{layer}.{module}.csproj",
    "views": "Views"                  folder under the website root holding .cshtml views
  },
  "rendering": {
    "defaultDatasourceLocation": "",   copy verbatim from the Datasource Location field
                                      (b5b27af1-25ef-405c-87ce-369b3a004016) of an existing
                                      rendering .yml - the value most of them share
    "defaultIcon": null,              __Icon for new renderings, or null to write none
    "placeholderSettings": null,      repo-relative .yml of the placeholder settings item new
                                      renderings are registered in, or null to register by hand
    "controllerNamespace": "{prefix}.{layer}.{module}.Controllers",
    "modelNamespace": "{prefix}.{layer}.{module}.Models"
  }
}

Read one existing rendering item and one module project to fill it. Do not guess a path you
have not seen.
"@ -ForegroundColor Yellow
    exit 2
}

function Get-RepoRoot {
    $dir = $PSScriptRoot
    while ($dir) {
        if (Test-Path (Join-Path $dir "src")) { return $dir }
        $dir = Split-Path $dir -Parent
    }
    return (Get-Location).Path
}

function Merge-Defaults([hashtable] $Defaults, $Json) {
    $out = @{}
    foreach ($key in $Defaults.Keys) {
        $prop = if ($Json) { $Json.PSObject.Properties[$key] } else { $null }
        if ($Defaults[$key] -is [hashtable]) {
            $out[$key] = Merge-Defaults $Defaults[$key] $(if ($prop) { $prop.Value } else { $null })
        } elseif ($prop -and $null -ne $prop.Value) {
            $out[$key] = $prop.Value
        } else {
            $out[$key] = $Defaults[$key]
        }
    }
    return $out
}

function Get-SkillConfig {
    $file = Join-Path $PSScriptRoot "config.json"
    if (!(Test-Path $file)) { Show-ConfigRequest "sc-rendering has no config.json." }

    $config = Merge-Defaults $script:Defaults (Get-Content $file -Raw | ConvertFrom-Json)
    $config.languages = @($config.languages)

    foreach ($path in $script:Required) {
        $value = $config
        foreach ($part in ($path -split '\.')) { $value = $value[$part] }
        if (!$value) { Show-ConfigRequest "config.json has no value for '$path'." }
    }
    return $config
}

function Expand-ConfigPath([string] $Path) {
    return $Path -replace '\{prefix\}', $config.namespacePrefix -replace '\{layer\}', $Layer -replace '\{module\}', $Module
}

function Save-Text([string] $Path, [string] $Text) {
    $bom = $true
    if (Test-Path $Path) {
        $head = [System.IO.File]::ReadAllBytes($Path)
        $bom = ($head.Length -ge 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)
    }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($bom)))
}

function Format-RainbowValue {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Value, [int] $Indent = 2)

    if ($Value.IndexOfAny([char[]]@("`n", "`r", '"', '\')) -ge 0) {
        $pad = " " * ($Indent + 2)
        return "|`r`n" + ((($Value -split "`r?`n") | ForEach-Object { "$pad$_" }) -join "`r`n")
    }
    if ($Value.IndexOfAny([char[]]@('"', ':', '[', ']', '{', '}', '!', '?', '-')) -ge 0) {
        return '"' + $Value.Replace('"', '\"') + '"'
    }
    return $Value
}

function ConvertTo-RainbowText([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text) {
    $Text = [regex]::Replace($Text, '(?m)^Path: (.+?)\r?$', {
        param($m) "Path: " + (Format-RainbowValue -Value $m.Groups[1].Value -Indent 0)
    })
    return ($Text -replace "`r`n", "`n") -replace "`n", "`r`n"
}

function New-LanguageBlock([string] $Timestamp) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Languages:")
    foreach ($lang in ($config.languages | Sort-Object)) {
        [void]$sb.AppendLine("- Language: $(Format-RainbowValue -Value $lang)")
        [void]$sb.AppendLine("  Versions:")
        [void]$sb.AppendLine("  - Version: 1")
        [void]$sb.AppendLine("    Fields:")
        [void]$sb.AppendLine("    - ID: `"25bed78c-4957-4165-998a-ca1b52f67497`"")
        [void]$sb.AppendLine("      Hint: __Created")
        [void]$sb.AppendLine("      Value: $Timestamp")
    }
    return $sb.ToString().TrimEnd()
}

function Show-TemplateRequest([string[]] $Missing) {
    Write-Host "[TEMPLATE] sc-rendering has no solution-specific templates yet:" -ForegroundColor Yellow
    foreach ($m in $Missing) { Write-Host "             templates\$m" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host (Get-Content (Join-Path $PSScriptRoot "templates/template-prompt.md") -Raw) -ForegroundColor Yellow
    exit 2
}

$config   = Get-SkillConfig
$repoRoot = Get-RepoRoot

$missingTemplates = @("view.cshtml.template", "action.cs.template") |
    Where-Object { !(Test-Path (Join-Path $PSScriptRoot "templates/$_")) }
if ($missingTemplates) { Show-TemplateRequest $missingTemplates }

if (!$DatasourceLocation) { $DatasourceLocation = $config.rendering.defaultDatasourceLocation }
if (!$Icon) { $Icon = $config.rendering.defaultIcon }

$serializationRoot = Join-Path $repoRoot (Expand-ConfigPath $config.serialization.root)
$renderingsDir     = Join-Path $serializationRoot (Expand-ConfigPath $config.serialization.renderings)
$controllerPrefix  = $ControllerClass -replace 'Controller$', ''
$websiteRoot       = Join-Path $repoRoot (Expand-ConfigPath $config.website.root)
$viewsDir          = Join-Path $websiteRoot (Join-Path $config.website.views $controllerPrefix)
$csprojFile        = Join-Path $repoRoot (Expand-ConfigPath $config.website.csproj)

if (!(Test-Path $renderingsDir)) { throw "Renderings directory not found: $renderingsDir" }

# The parent GUID comes from a sibling rendering, so the new item lands in the same folder.
$siblingYml = Get-ChildItem -Path $renderingsDir -Filter "*.yml" | Select-Object -First 1
if (!$siblingYml) { throw "No sibling rendering YAML in $renderingsDir to read the parent GUID from" }

$parentGuid = (Select-String -Path $siblingYml.FullName -Pattern '^Parent:\s+"(.+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
if (!$parentGuid) { throw "Could not parse the parent GUID from $($siblingYml.Name)" }

$renderingGuid      = [guid]::NewGuid().ToString("D")
$renderingGuidUpper = "{$($renderingGuid.ToUpper())}"
$timestamp          = (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'")

$iconBlock = if ($Icon) {
    "- ID: `"06d5295c-ed2f-4a54-9bf2-26228d113318`"`r`n  Hint: __Icon`r`n  Value: $(Format-RainbowValue -Value $Icon)`r`n"
} else { "" }

function Expand-Template([string] $TemplateFile) {
    $expanded = (Get-Content -Path (Join-Path $PSScriptRoot "templates/$TemplateFile") -Raw) `
        -replace '\{\{RenderingGuid\}\}',            $renderingGuid `
        -replace '\{\{ParentGuid\}\}',               $parentGuid `
        -replace '\{\{NamespacePrefix\}\}',          $config.namespacePrefix `
        -replace '\{\{Layer\}\}',                    $Layer `
        -replace '\{\{Module\}\}',                   $Module `
        -replace '\{\{RenderingName\}\}',            $RenderingName `
        -replace '\{\{ControllerClass\}\}',          $ControllerClass `
        -replace '\{\{ControllerNamespace\}\}',      (Expand-ConfigPath $config.rendering.controllerNamespace) `
        -replace '\{\{ModelNamespace\}\}',           (Expand-ConfigPath $config.rendering.modelNamespace) `
        -replace '\{\{AssemblyName\}\}',             "$($config.namespacePrefix).$Layer.$Module" `
        -replace '\{\{ActionName\}\}',               $ActionName `
        -replace '\{\{DatasourceTemplatePath\}\}',   (Format-RainbowValue -Value $DatasourceTemplatePath) `
        -replace '\{\{DatasourceModelInterface\}\}', $DatasourceModelInterface `
        -replace '\{\{DatasourceLocation\}\}',       (Format-RainbowValue -Value $DatasourceLocation) `
        -replace '\{\{IconBlock\}\}',                $iconBlock `
        -replace '\{\{LanguagesBlock\}\}',           (New-LanguageBlock $timestamp) `
        -replace '\{\{Timestamp\}\}',                $timestamp

    $leftover = [regex]::Match($expanded, '\{\{[A-Z][A-Za-z]*\}\}')
    if ($leftover.Success) { throw "$TemplateFile still holds $($leftover.Value) after expansion - unknown token." }

    return $expanded
}

$renderingYml = Join-Path $renderingsDir "$RenderingName.yml"
Save-Text $renderingYml (ConvertTo-RainbowText (Expand-Template "rendering.yml.template"))
Write-Host "[OK] Rendering YAML: $renderingYml" -ForegroundColor Green

if (!(Test-Path $viewsDir)) { New-Item -ItemType Directory -Path $viewsDir -Force | Out-Null }
$viewFile = Join-Path $viewsDir "$ActionName.cshtml"
if (!(Test-Path $viewFile)) {
    Save-Text $viewFile (Expand-Template "view.cshtml.template")
    Write-Host "[OK] View: $viewFile" -ForegroundColor Green
} else {
    Write-Host "[SKIP] View already exists: $viewFile" -ForegroundColor Yellow
}

if (Test-Path $csprojFile) {
    $viewInclude   = "$($config.website.views)\$controllerPrefix\$ActionName.cshtml"
    $csprojContent = Get-Content -Path $csprojFile -Raw
    $existing      = [regex]::Matches($csprojContent, '<Content Include="[^"]+\.cshtml"\s*/>')

    if ($csprojContent -match [regex]::Escape($viewInclude)) {
        Write-Host "[SKIP] View already in csproj" -ForegroundColor Yellow
    } elseif ($existing.Count -gt 0) {
        $last = $existing[$existing.Count - 1]
        Save-Text $csprojFile ($csprojContent.Insert($last.Index + $last.Length, "`r`n    <Content Include=`"$viewInclude`" />"))
        Write-Host "[OK] Added view to csproj: $viewInclude" -ForegroundColor Green
    } else {
        Write-Host "[INFO] No explicit view entries in csproj - SDK-style project, nothing to add" -ForegroundColor Cyan
    }
} else {
    Write-Host "[WARN] Csproj not found: $csprojFile" -ForegroundColor Yellow
}

$placeholderYml = if ($config.rendering.placeholderSettings) { Join-Path $repoRoot $config.rendering.placeholderSettings } else { $null }

if ($SkipPlaceholder) {
    Write-Host "[SKIP] Placeholder registration skipped" -ForegroundColor Yellow
} elseif (!$placeholderYml) {
    Write-Host "[INFO] No placeholderSettings configured - register the rendering manually" -ForegroundColor Cyan
} elseif (!(Test-Path $placeholderYml)) {
    Write-Host "[WARN] Placeholder file not found: $placeholderYml" -ForegroundColor Yellow
} else {
    $content = Get-Content -Path $placeholderYml -Raw
    if ($content -match [regex]::Escape($renderingGuidUpper)) {
        Write-Host "[SKIP] Already in placeholder: $renderingGuidUpper" -ForegroundColor Yellow
    } else {
        Save-Text $placeholderYml ($content -replace '(?m)^(Languages:)', "    $renderingGuidUpper`r`n`$1")
        Write-Host "[OK] Added to placeholder settings: $renderingGuidUpper" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Rendering created ===" -ForegroundColor Cyan
Write-Host "  GUID:       $renderingGuid"
Write-Host "  GUID (ref): $renderingGuidUpper"
Write-Host "  Module:     $Layer/$Module"
Write-Host "  Action:     $ActionName"
Write-Host "  Model:      $DatasourceModelInterface"
Write-Host ""
Write-Host "Remaining manual steps:" -ForegroundColor Yellow
Write-Host "  1. Add the controller action to $ControllerClass.cs:" -ForegroundColor Yellow
Write-Host ""
Write-Host (Expand-Template "action.cs.template")
Write-Host ""
Write-Host "  2. Edit the view content in: $viewFile" -ForegroundColor Yellow
