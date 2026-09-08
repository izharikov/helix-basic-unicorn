<#
.SYNOPSIS
    PostToolUse hook: applies the repo .editorconfig to a C# file Claude just wrote.

.DESCRIPTION
    Reads the Claude Code hook payload from stdin, extracts the written file path and,
    when it is a non-generated .cs file inside the repo, runs

        dotnet format whitespace <dir> --folder --include <file>

    Folder mode does not load a project or solution, so nothing is compiled and the
    user's manual MSBuild workflow is untouched. The root .editorconfig is resolved by
    walking up from the file, which gives us charset=utf-8-bom, indent_size=4 and the
    C# brace/indent rules for free.

    The Write tool always emits UTF-8 without BOM and with a trailing newline, while the
    .editorconfig demands charset=utf-8-bom and insert_final_newline=false. That means
    every single write is "changed" by the formatter even when the code was already
    formatted correctly. Those two edge bytes cannot invalidate a later Edit, so the
    hook stays silent for them and only reports when the body of the file really moved.

    Failures are swallowed on purpose - a formatter must never break the turn.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Directories and generated files that must never be reformatted.
$excluded = @(
    '\node_modules\',
    '\bin\',
    '\obj\',
    '\packages\',
    '\.claude\',
    '\Models\Templates.cs'   # code generator output - regenerated on build
)

# Content as an Edit would see it: no BOM, no trailing blank space. A difference that
# survives this is a real reformat (indentation, braces, inner whitespace).
function Get-ComparableText([string]$file)
{
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $text.TrimStart([char]0xFEFF).TrimEnd([char[]]@([char]0x0D, [char]0x0A, [char]0x20, [char]0x09))
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

    $payload = $raw | ConvertFrom-Json

    $path = $payload.tool_input.file_path
    if (-not $path) { $path = $payload.tool_response.filePath }
    if (-not $path) { exit 0 }
    if ($path -notmatch '\.cs$') { exit 0 }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { exit 0 }

    $full = (Resolve-Path -LiteralPath $path).Path
    $normalized = $full -replace '/', '\'

    foreach ($fragment in $excluded) {
        if ($normalized -like "*$fragment*") { exit 0 }
    }

    $before = Get-ComparableText $full
    $directory = Split-Path -Parent $full

    # dotnet writes progress to stderr; under ErrorActionPreference=Stop that would
    # surface as a terminating NativeCommandError, so relax it for the call only.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & dotnet format whitespace $directory --folder --include $full --verbosity quiet 2>&1 | Out-Null
    $ErrorActionPreference = $previous

    $after = Get-ComparableText $full
    if ($before -ne $after) {
        $name = Split-Path -Leaf $full
        $result = @{
            systemMessage = "editorconfig: reformatted $name (indent / braces). Re-read the file before editing it again."
        }
        $result | ConvertTo-Json -Compress
    }
}
catch {
    # Formatting is best-effort; never surface an error to the session.
}

exit 0
