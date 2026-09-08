param(
    [Parameter(Mandatory)] [string] $Json
)

$ErrorActionPreference = "Stop"

$script:Defaults = @{
    namespacePrefix = $null
    languages       = @("en")
    serialization   = @{ root = $null; templates = $null }
    template        = @{ defaultSection = "Data"; defaultIcon = "Office/32x32/document.png"; defaultWorkflow = $null; enableItemFallback = $false }
    codegen         = @{ command = $null; workingDirectory = $null }
}

$script:Required = @("namespacePrefix", "serialization.root", "serialization.templates")

function Show-ConfigRequest([string] $Reason) {
    $file = Join-Path $PSScriptRoot "config.json"
    Write-Host "[CONFIG] $Reason" -ForegroundColor Yellow
    Write-Host @"

Write $file from this solution, then run the command again:

{
  "namespacePrefix": "",              first segment the src/*/*/website/*.csproj files share
                                      (Foo.Feature.Bar.csproj -> "Foo")
  "serialization": {
    "root": "",                       path from the repo root to a module's serialized items,
                                      with {layer} {module} {prefix} placeholders
                                      (e.g. "src/{layer}/{module}/serialization")
    "templates": ""                   fragment under root holding template items
                                      ("templates/{module}" when per-module, else "templates")
  },
  "languages": ["en"],                the "- Language:" values in the existing .yml items
  "template": {
    "defaultSection": "Data",
    "defaultIcon": "Office/32x32/document.png",
    "defaultWorkflow": null,          __Default workflow in existing __Standard Values, or null
    "enableItemFallback": false
  },
  "codegen": {
    "command": null,                  model generator to run after a change, repo-relative
                                      (a *leprechaun*.ps1 or T4 runner), or null
    "workingDirectory": null
  }
}

Read one existing module to fill it - the folders under src/, one serialized template item,
and any generator script in the repository. Do not guess a path you have not seen.
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
    if (!(Test-Path $file)) { Show-ConfigRequest "sc-template has no config.json." }

    $config = Merge-Defaults $script:Defaults (Get-Content $file -Raw | ConvertFrom-Json)
    $config.languages = @($config.languages)

    foreach ($path in $script:Required) {
        $value = $config
        foreach ($part in ($path -split '\.')) { $value = $value[$part] }
        if (!$value) { Show-ConfigRequest "config.json has no value for '$path'." }
    }
    return $config
}

function Expand-ConfigPath([string] $Path, [string] $Layer, [string] $Module) {
    return $Path -replace '\{prefix\}', $config.namespacePrefix -replace '\{layer\}', $Layer -replace '\{module\}', $Module
}

function Get-Base([string] $Layer, [string] $Module) {
    $root = Join-Path $repoRoot (Expand-ConfigPath $config.serialization.root $Layer $Module)
    return Join-Path $root (Expand-ConfigPath $config.serialization.templates $Layer $Module)
}

function Get-TemplateDir([string] $Layer, [string] $Module, [string] $TemplateName) {
    return Join-Path (Get-Base $Layer $Module) $TemplateName
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

function ConvertFrom-RainbowValue([AllowEmptyString()] [string] $Value) {
    if (!$Value) { return "" }
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) {
        $v = $v.Substring(1, $v.Length - 2).Replace('\"', '"')
    }
    return $v
}

function ConvertTo-RainbowText([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text) {
    $Text = [regex]::Replace($Text, '(?m)^Path: (.+?)\r?$', {
        param($m) "Path: " + (Format-RainbowValue -Value $m.Groups[1].Value -Indent 0)
    })
    return ($Text -replace "`r`n", "`n") -replace "`n", "`r`n"
}

function New-ItemTimestamp { return (Get-Date).ToUniversalTime().ToString("yyyyMMdd'T'HHmmss'Z'") }

function Read-ItemGuid([string] $File, [string] $Pattern = '^ID:\s+"(.+)"') {
    $m = Select-String -Path $File -Pattern $Pattern | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value }
    return $null
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

function Add-StandardValuesEntry {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $FieldGuid,
        [Parameter(Mandatory)] [string] $Hint,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Value
    )

    # Rainbow writes version fields sorted by ID, and one block per language: the entry
    # goes into every block, in ID order, or the first sync rewrites the file.
    $lines = ([System.IO.File]::ReadAllText($Path)) -split "`r?`n"
    $entry = @(
        "    - ID: `"$FieldGuid`"",
        "      Hint: $Hint",
        "      Value: $(Format-RainbowValue -Value $Value -Indent 6)"
    )

    $out      = New-Object System.Collections.Generic.List[string]
    $inFields = $false
    $placed   = $false
    $added    = 0

    foreach ($line in $lines) {
        $indent = $line.Length - $line.TrimStart(' ').Length

        if ($line.Trim() -eq 'Fields:' -and $indent -eq 4) {
            $inFields = $true
            $placed   = $false
            $out.Add($line)
            continue
        }

        if ($inFields) {
            if ($indent -eq 4 -and $line.TrimStart(' ').StartsWith('- ID: "') -and !$placed) {
                $existingId = [regex]::Match($line, '- ID: "([^"]+)"').Groups[1].Value
                if ([string]::Compare($existingId, $FieldGuid, $true) -gt 0) {
                    $out.AddRange([string[]]$entry); $placed = $true; $added++
                }
            }
            if ($line.Trim() -eq '' -or ($indent -lt 4 -and $line.Trim() -ne '')) {
                if (!$placed) { $out.AddRange([string[]]$entry); $placed = $true; $added++ }
                $inFields = $false
            }
        }

        $out.Add($line)
    }

    if ($inFields -and !$placed) { $out.AddRange([string[]]$entry); $added++ }
    if ($added -eq 0) { return 0 }

    Save-Text $Path (ConvertTo-RainbowText ($out -join "`r`n"))
    return $added
}

function Remove-StandardValuesEntry {
    param([Parameter(Mandatory)] [string] $Path, [Parameter(Mandatory)] [string] $FieldGuid)

    # Sitecore keys the value by field ID, so a leftover entry syncs a value for a field
    # nobody can see. Takes the continuation lines of a block scalar with it.
    $lines   = ([System.IO.File]::ReadAllText($Path)) -split "`r?`n"
    $kept    = New-Object System.Collections.Generic.List[string]
    $removed = $false
    $pattern = '^(\s*)- ID: "' + [regex]::Escape($FieldGuid) + '"\s*$'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -imatch $pattern) {
            $entryIndent = $Matches[1].Length
            $removed = $true
            $i++
            while ($i -lt $lines.Count) {
                $next   = $lines[$i]
                $indent = $next.Length - $next.TrimStart(' ').Length
                if ($next.Trim() -eq '' -or $indent -le $entryIndent) { break }
                $i++
            }
            $i--
            continue
        }
        $kept.Add($lines[$i])
    }

    if (!$removed) { return $false }
    Save-Text $Path (ConvertTo-RainbowText ($kept -join "`r`n"))
    return $true
}

function Invoke-Generator {
    if ($op.skipCodegen -eq $true -or $op.skipLeprechaun -eq $true) { return }
    $command = $config.codegen.command
    if (!$command) { return }

    $path = if ([System.IO.Path]::IsPathRooted($command)) { $command } else { Join-Path $repoRoot $command }
    if (!(Test-Path $path)) {
        Write-Host "[WARN] Code generator not found: $path" -ForegroundColor Yellow
        return
    }

    $workDir = if ($config.codegen.workingDirectory) { Join-Path $repoRoot $config.codegen.workingDirectory } else { $repoRoot }
    Write-Host "[...] Running code generator..." -ForegroundColor Cyan
    Push-Location $workDir
    try {
        & $path
        if ($LASTEXITCODE -ne 0) { throw "Code generator failed (exit $LASTEXITCODE)" }
        Write-Host "[OK] Code generator completed" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

function New-SectionYaml([string] $SectionGuid, [string] $ParentGuid, [string] $Layer, [string] $Module, [string] $TemplateName, [string] $SectionName, [string] $Timestamp) {
    $languages = New-LanguageBlock $Timestamp
    return @"
---
ID: "$SectionGuid"
Parent: "$ParentGuid"
Template: "e269fbb5-3750-427a-9149-7aa950b49301"
Path: /sitecore/templates/$Layer/$Module/$TemplateName/$SectionName
DB: master
$languages
"@
}

function New-StandardValuesSharedBlock {
    $entries = @()

    if ($config.template.defaultWorkflow) {
        $wf = $config.template.defaultWorkflow
        if ($wf -notmatch '^\{') { $wf = "{$wf}" }
        $entries += "- ID: `"ca9b9f52-4fb0-4f87-a79f-24dea62cda65`"`r`n  Hint: __Default workflow`r`n  Value: `"$($wf.ToUpper())`""
    }
    if ($config.template.enableItemFallback -eq $true) {
        $entries += "- ID: `"fd4e2050-186c-4375-8b99-e8a85dd7436e`"`r`n  Hint: __Enable item fallback`r`n  Type: Checkbox`r`n  Value: 1"
    }

    if ($entries.Count -eq 0) { return "" }
    return "SharedFields:`r`n" + ($entries -join "`r`n") + "`r`n"
}

function Read-YamlField([string] $Text, [string] $Hint, [switch] $Numeric) {
    $pattern = '(?m)Hint: ' + [regex]::Escape($Hint) + '\s*\r?\n(?:\s*Type:[^\r\n]*\r?\n)?\s*Value:\s*(' + $(if ($Numeric) { '\d+' } else { '.+' }) + ')'
    $m = [regex]::Match($Text, $pattern)
    if (!$m.Success) { return $null }
    return (ConvertFrom-RainbowValue $m.Groups[1].Value)
}

function Add-Field([string] $Layer, [string] $Module, [string] $TemplateName, [string] $SectionName, $Field) {
    if (@("Name", "DisplayName") -contains $Field.name) { throw "Field name '$($Field.name)' is reserved by Sitecore." }

    $templateDirPath = Get-TemplateDir $Layer $Module $TemplateName
    $sectionDir      = Join-Path $templateDirPath $SectionName
    $sectionYmlPath  = Join-Path $templateDirPath "$SectionName.yml"

    if (!(Test-Path $sectionDir)) { New-Item -ItemType Directory -Path $sectionDir -Force | Out-Null }

    # An existing section item keeps its GUID: allocating a new one here would orphan the
    # section in Sitecore and take every field ID reference with it.
    if (!(Test-Path $sectionYmlPath)) {
        $templateGuidForSec = Read-ItemGuid (Join-Path (Get-Base $Layer $Module) "$TemplateName.yml")
        if (!$templateGuidForSec) { throw "Could not read the template GUID for section $SectionName" }
        $newSecGuid = [guid]::NewGuid().ToString("D")
        Save-Text $sectionYmlPath (ConvertTo-RainbowText (New-SectionYaml $newSecGuid $templateGuidForSec $Layer $Module $TemplateName $SectionName (New-ItemTimestamp)))
        Write-Host "[OK] Created section: $SectionName (GUID: $newSecGuid)" -ForegroundColor Green
    }

    $fieldYml = Join-Path $sectionDir "$($Field.name).yml"
    if (Test-Path $fieldYml) { throw "Field already exists: $fieldYml" }

    $parentGuid = Read-ItemGuid $sectionYmlPath
    if (!$parentGuid) { throw "Could not read section GUID from $sectionYmlPath" }

    $sortOrder = if ($null -ne $Field.sortOrder) { [int]$Field.sortOrder } else { -1 }
    if ($sortOrder -lt 0) {
        # 100 past the highest sibling, matching Sitecore's own spacing.
        $maxSort = 0
        foreach ($sibling in (Get-ChildItem -Path $sectionDir -Filter "*.yml" -ErrorAction SilentlyContinue)) {
            $value = Read-YamlField (Get-Content $sibling.FullName -Raw) "__Sortorder" -Numeric
            if ($value -and [int]$value -gt $maxSort) { $maxSort = [int]$value }
        }
        $sortOrder = $maxSort + 100
    }

    $fieldGuid = [guid]::NewGuid().ToString("D")
    $timestamp = New-ItemTimestamp

    $content = Get-Content -Path (Join-Path $PSScriptRoot "templates/field.yml.template") -Raw
    $content = $content `
        -replace '\{\{FieldGuid\}\}',      $fieldGuid `
        -replace '\{\{ParentGuid\}\}',     $parentGuid `
        -replace '\{\{Layer\}\}',          $Layer `
        -replace '\{\{Module\}\}',         $Module `
        -replace '\{\{TemplateName\}\}',   $TemplateName `
        -replace '\{\{SectionName\}\}',    $SectionName `
        -replace '\{\{FieldName\}\}',      $Field.name `
        -replace '\{\{FieldType\}\}',      (Format-RainbowValue -Value ([string]$Field.type)) `
        -replace '\{\{SortOrder\}\}',      $sortOrder `
        -replace '\{\{LanguagesBlock\}\}', (New-LanguageBlock $timestamp)

    if ($Field.source) {
        $srcBlock = "- ID: ""1eb8ae32-e190-44a6-968d-ed904c794ebf""`r`n  Hint: Source`r`n  Value: $(Format-RainbowValue -Value ([string]$Field.source))`r`n"
        $content = $content -replace '(?m)(^- ID: "ab162cc0)', "$srcBlock`$1"
    }
    if ($Field.shared -eq $true) {
        $sharedBlock = "- ID: ""be351a73-fcb0-4213-93fa-c302d8ab4f51""`r`n  Hint: Shared`r`n  Type: Checkbox`r`n  Value: 1`r`n"
        $content = $content -replace '(?m)(^Languages:)', "$sharedBlock`$1"
    }

    Save-Text $fieldYml (ConvertTo-RainbowText $content)
    Write-Host "[OK] Field: $($Field.name) (GUID: $fieldGuid, Sort: $sortOrder)" -ForegroundColor Green

    if ($Field.defaultValue) {
        $stdValYml = Join-Path $templateDirPath "__Standard Values.yml"
        if (Test-Path $stdValYml) {
            $added = Add-StandardValuesEntry -Path $stdValYml -FieldGuid $fieldGuid -Hint $Field.name -Value ([string]$Field.defaultValue)
            if ($added -gt 0) { Write-Host "[OK] __Standard Values: $($Field.name) = ""$($Field.defaultValue)"" ($added language version(s))" -ForegroundColor Green }
        } else {
            Write-Host "[WARN] __Standard Values.yml not found - skipping default value" -ForegroundColor Yellow
        }
    }

    return $fieldGuid
}

$op       = $Json | ConvertFrom-Json
$config   = Get-SkillConfig
$repoRoot = Get-RepoRoot

$layer        = $op.layer
$module       = $op.module
$templateName = $op.templateName
$sectionName  = if ($op.sectionName) { [string]$op.sectionName } else { $config.template.defaultSection }

switch ($op.operation) {

    "get" {
        $base        = Get-Base $layer $module
        $templateYml = Join-Path $base "$templateName.yml"
        $templateDir = Join-Path $base $templateName
        if (!(Test-Path $templateYml)) { throw "Template not found: $templateYml" }

        $tContent = Get-Content $templateYml -Raw

        # The base template value is one quoted GUID on the same line, or a block scalar
        # listing several: reading only the block form reports single-base templates as none.
        $baseTemplates = @()
        $baseSection   = [regex]::Match($tContent, '(?ms)Hint: __Base template.*?(?=^- ID:|^Languages:|\z)')
        if ($baseSection.Success) {
            $baseTemplates = @([regex]::Matches($baseSection.Value, '\{[0-9A-Fa-f-]{36}\}') | ForEach-Object { $_.Value })
        }

        $sections = @()
        if (Test-Path $templateDir) {
            foreach ($secFile in (Get-ChildItem -Path $templateDir -Filter "*.yml" -File | Where-Object { $_.Name -ne "__Standard Values.yml" })) {
                $secName = [System.IO.Path]::GetFileNameWithoutExtension($secFile.Name)
                $secDir  = Join-Path $templateDir $secName
                $fields  = @()

                if (Test-Path $secDir) {
                    foreach ($fieldFile in (Get-ChildItem -Path $secDir -Filter "*.yml" -File)) {
                        $fContent = Get-Content $fieldFile.FullName -Raw
                        $fObj = [ordered]@{
                            name      = [System.IO.Path]::GetFileNameWithoutExtension($fieldFile.Name)
                            fieldId   = Read-ItemGuid $fieldFile.FullName
                            type      = [string](Read-YamlField $fContent "Type")
                            sortOrder = [int](Read-YamlField $fContent "__Sortorder" -Numeric)
                        }
                        $source = Read-YamlField $fContent "Source"
                        if ($source) { $fObj.source = $source }
                        # Shared is a checkbox: the hint is present for both states, so its
                        # presence alone reported every unshared field as shared.
                        if ((Read-YamlField $fContent "Shared") -eq '1') { $fObj.shared = $true }
                        $fields += $fObj
                    }
                }

                $sections += [ordered]@{ name = $secName; sectionId = Read-ItemGuid $secFile.FullName; fields = @($fields | Sort-Object { $_.sortOrder }) }
            }
        }

        $standardValues = @()
        $stdValYml = Join-Path $templateDir "__Standard Values.yml"
        if (Test-Path $stdValYml) {
            foreach ($m in [regex]::Matches((Get-Content $stdValYml -Raw), '- ID: "([^"]+)"\s*\r?\n\s*Hint: ([^\r\n]+)\s*\r?\n\s*Value: "?([^"\r\n]*)"?')) {
                $hint = $m.Groups[2].Value.Trim()
                if ($hint -notmatch '^__') { $standardValues += [ordered]@{ fieldId = $m.Groups[1].Value; hint = $hint; value = $m.Groups[3].Value } }
            }
        }

        [ordered]@{
            templateName   = $templateName
            templateId     = Read-ItemGuid $templateYml
            icon           = [string](Read-YamlField $tContent "__Icon")
            baseTemplates  = @($baseTemplates)
            sections       = @($sections)
            standardValues = @($standardValues)
        } | ConvertTo-Json -Depth 10
    }

    "create" {
        $icon = if ($op.icon) { $op.icon } else { $config.template.defaultIcon }
        $base = Get-Base $layer $module
        if (!(Test-Path $base)) { throw "Templates directory not found: $base" }

        $templateDir = Join-Path $base $templateName
        if (Test-Path $templateDir) { throw "Template already exists: $templateDir" }

        # Parent is the containing folder item, whose own YAML sits one level up and is
        # named after the folder. Reading a sibling template here yields the wrong ID.
        $folderYml = Join-Path (Split-Path $base -Parent) ("{0}.yml" -f (Split-Path $base -Leaf))
        if (!(Test-Path $folderYml)) { throw "Parent folder item YAML not found: $folderYml" }
        $parentGuid = Read-ItemGuid $folderYml
        if (!$parentGuid) { throw "Could not read parent GUID from $folderYml" }

        $templateGuid  = [guid]::NewGuid().ToString("D")
        $sectionGuid   = [guid]::NewGuid().ToString("D")
        $stdValGuid    = [guid]::NewGuid().ToString("D")
        $timestamp     = New-ItemTimestamp

        $standardTemplateGuid = "{1930BBEB-7805-471A-A3BE-4858AC7CF696}"
        $allBases = @($standardTemplateGuid)
        foreach ($bt in @($op.baseTemplates)) {
            $n = "$bt".Trim()
            if ($n -and $n -ne $standardTemplateGuid) {
                if ($n -notmatch '^\{') { $n = "{$n}" }
                $allBases += $n.ToUpper()
            }
        }

        $values = @{
            TemplateGuid          = $templateGuid
            ParentGuid            = $parentGuid
            Layer                 = $layer
            Module                = $module
            TemplateName          = $templateName
            SectionName           = $sectionName
            SectionGuid           = $sectionGuid
            StandardValuesGuid    = $stdValGuid
            StandardValuesGuidRef = "{$($stdValGuid.ToUpper())}"
            BaseTemplateValue     = (Format-RainbowValue -Value ($allBases -join "`r`n"))
            Icon                  = $icon
            Timestamp             = $timestamp
            LanguagesBlock        = (New-LanguageBlock $timestamp)
            SharedFieldsBlock     = (New-StandardValuesSharedBlock)
        }

        function Expand([string] $Tpl) {
            $c = Get-Content (Join-Path $PSScriptRoot "templates/$Tpl") -Raw
            foreach ($k in $values.Keys) { $c = $c -replace "\{\{$k\}\}", $values[$k] }
            return $c
        }

        Save-Text (Join-Path $base "$templateName.yml") (ConvertTo-RainbowText (Expand "template.yml.template"))
        Write-Host "[OK] Template: $templateName (GUID: $templateGuid)" -ForegroundColor Green

        New-Item -ItemType Directory -Path (Join-Path $templateDir $sectionName) -Force | Out-Null
        Save-Text (Join-Path $templateDir "$sectionName.yml") (ConvertTo-RainbowText (Expand "section.yml.template"))
        Write-Host "[OK] Section: $sectionName (GUID: $sectionGuid)" -ForegroundColor Green

        Save-Text (Join-Path $templateDir "__Standard Values.yml") (ConvertTo-RainbowText (Expand "standard-values.yml.template"))
        Write-Host "[OK] __Standard Values (GUID: $stdValGuid)" -ForegroundColor Green

        foreach ($f in @($op.fields)) {
            if ($f) { Add-Field $layer $module $templateName $(if ($f.sectionName) { $f.sectionName } else { $sectionName }) $f | Out-Null }
        }

        Invoke-Generator

        Write-Host ""
        Write-Host "=== Template created ===" -ForegroundColor Cyan
        Write-Host "  Path: /sitecore/templates/$layer/$module/$templateName"
        Write-Host "  Template GUID:  $templateGuid"
        Write-Host "  Section GUID:   $sectionGuid"
        Write-Host "  StdValues GUID: $stdValGuid"
    }

    "add-field" {
        if ($op.fields) {
            foreach ($f in $op.fields) {
                Add-Field $layer $module $templateName $(if ($f.sectionName) { [string]$f.sectionName } else { $sectionName }) $f | Out-Null
            }
        } else {
            Add-Field $layer $module $templateName $sectionName $op | Out-Null
        }
        Invoke-Generator
    }

    "rename-field" {
        $sectionDir = Join-Path (Get-TemplateDir $layer $module $templateName) $sectionName
        $oldFile    = Join-Path $sectionDir "$($op.oldFieldName).yml"
        $newFile    = Join-Path $sectionDir "$($op.newFieldName).yml"

        if (!(Test-Path $oldFile)) { throw "Field not found: $oldFile" }
        if (Test-Path $newFile)    { throw "Target already exists: $newFile" }

        $itemPath = "/sitecore/templates/$layer/$module/$templateName/$sectionName"
        Save-Text $oldFile ((Get-Content $oldFile -Raw) -replace [regex]::Escape("$itemPath/$($op.oldFieldName)"), "$itemPath/$($op.newFieldName)")
        Rename-Item -Path $oldFile -NewName "$($op.newFieldName).yml"
        Write-Host "[OK] Renamed: $($op.oldFieldName) -> $($op.newFieldName)" -ForegroundColor Green

        # The hint is only a label - Sitecore keys the value by field ID - but leaving the
        # old name in __Standard Values makes the file lie about what the value belongs to.
        $stdValFile  = Join-Path (Get-TemplateDir $layer $module $templateName) "__Standard Values.yml"
        $renamedGuid = Read-ItemGuid $newFile
        if ($renamedGuid -and (Test-Path $stdValFile)) {
            $sv = Get-Content $stdValFile -Raw
            $hintPattern = '(?im)(^(\s*)- ID: "' + [regex]::Escape($renamedGuid) + '"\s*\r?\n\2  Hint: )(.+?)(\r?$)'
            if ($sv -match $hintPattern) {
                $sv = [regex]::Replace($sv, $hintPattern, { param($m) $m.Groups[1].Value + $op.newFieldName + $m.Groups[4].Value })
                Save-Text $stdValFile (ConvertTo-RainbowText $sv)
                Write-Host "[OK] Updated the __Standard Values hint" -ForegroundColor Green
            }
        }

        Write-Host "[NOTE] The field ID is unchanged; update the name wherever the model layer spells it out." -ForegroundColor Yellow
        Invoke-Generator
    }

    "move-field" {
        $templateDir = Get-TemplateDir $layer $module $templateName
        $srcFile     = Join-Path (Join-Path $templateDir $op.fromSection) "$($op.fieldName).yml"
        $toDir       = Join-Path $templateDir $op.toSection

        if (!(Test-Path $srcFile)) { throw "Field not found: $srcFile" }

        if (!(Test-Path $toDir)) {
            New-Item -ItemType Directory -Path $toDir -Force | Out-Null
            $templateGuid = Read-ItemGuid (Join-Path (Get-Base $layer $module) "$templateName.yml")
            $newSecGuid   = [guid]::NewGuid().ToString("D")
            Save-Text (Join-Path $templateDir "$($op.toSection).yml") (ConvertTo-RainbowText (New-SectionYaml $newSecGuid $templateGuid $layer $module $templateName $op.toSection (New-ItemTimestamp)))
            Write-Host "[OK] Created section: $($op.toSection) (GUID: $newSecGuid)" -ForegroundColor Green
        }

        $toSectionGuid = Read-ItemGuid (Join-Path $templateDir "$($op.toSection).yml")
        $itemPath      = "/sitecore/templates/$layer/$module/$templateName"

        $content = (Get-Content $srcFile -Raw) `
            -replace 'Parent:\s+"[^"]+"', "Parent: `"$toSectionGuid`"" `
            -replace [regex]::Escape("$itemPath/$($op.fromSection)/$($op.fieldName)"), "$itemPath/$($op.toSection)/$($op.fieldName)"

        Save-Text (Join-Path $toDir "$($op.fieldName).yml") $content
        Remove-Item $srcFile
        Write-Host "[OK] Moved: $($op.fromSection)/$($op.fieldName) -> $($op.toSection)/$($op.fieldName)" -ForegroundColor Green

        Invoke-Generator
    }

    "remove-field" {
        $templateDir = Get-TemplateDir $layer $module $templateName
        $fieldFile   = Join-Path $templateDir "$sectionName/$($op.fieldName).yml"
        if (!(Test-Path $fieldFile)) { throw "Field not found: $fieldFile" }

        $fieldGuid = Read-ItemGuid $fieldFile
        Remove-Item $fieldFile
        Write-Host "[OK] Removed: $($op.fieldName) (GUID: $fieldGuid)" -ForegroundColor Green

        $stdValFile = Join-Path $templateDir "__Standard Values.yml"
        if ($fieldGuid -and (Test-Path $stdValFile) -and (Remove-StandardValuesEntry -Path $stdValFile -FieldGuid $fieldGuid)) {
            Write-Host "[OK] Removed the field's __Standard Values entry" -ForegroundColor Green
        }

        Write-Host "[NOTE] Drop the field from the model layer too, however this solution declares it." -ForegroundColor Yellow
        Invoke-Generator
    }

    "remove" {
        $base        = Get-Base $layer $module
        $templateYml = Join-Path $base "$templateName.yml"
        $templateDir = Join-Path $base $templateName
        if (!(Test-Path $templateYml)) { throw "Template not found: $templateYml" }

        $templateGuid = Read-ItemGuid $templateYml
        if (Test-Path $templateDir) { Remove-Item $templateDir -Recurse -Force }
        Remove-Item $templateYml
        Write-Host "[OK] Removed template: $templateName (GUID: $templateGuid)" -ForegroundColor Green

        Write-Host "[NOTE] This GUID may still be referenced elsewhere. Search the repository for it and clean up:" -ForegroundColor Yellow
        Write-Host "         {$($templateGuid.ToUpper())}" -ForegroundColor Yellow
        Write-Host "       placeholder settings, rendering datasource templates, and the model layer." -ForegroundColor Yellow

        Invoke-Generator
    }

    default { throw "Unknown operation: $($op.operation). Valid: get, create, add-field, rename-field, move-field, remove-field, remove" }
}
