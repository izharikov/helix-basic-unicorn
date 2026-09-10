---
name: ilspy-decompile
description: Decompile a .NET type's compiled body with ILSpy. Use during detailed planning or implementation, when you can already name the exact Namespace.Type. During high-level planning, scoping or exploration, ask the user before decompiling.
---

# Decompile .NET assemblies with ILSpy

`command -v ilspycmd` first - it is often already installed as a global tool
(`~/.dotnet/tools/ilspycmd`) and starts cold-free. Otherwise `dnx ilspycmd`, which needs no install
with the .NET 10 SDK. From Git Bash call that one as **`dnx.cmd`** - the SDK ships a `.cmd` shim and
bash does not apply PATHEXT, so the bare name is "command not found".

## Workflow

1. Locate the assembly (below).
2. `ilspycmd -l class <dll>` - find the exact type name.
3. Decompile that type to a path keyed by assembly, version and type, so nothing overwrites
   anything:

       out="$TEMP/ilspy/<Assembly>.<Version>/<Namespace.Type>.cs"
       mkdir -p "$(dirname "$out")"
       ilspycmd -t <Namespace.Type> <dll> > "$out"

4. `grep -n <what you came for> "$out"` - and grep the same file again for the next question.
   Never re-run the decompile to change a grep. If the file is already there, it is already the
   right version - grep it.

`rm -rf "$TEMP/ilspy"` when done with the task.

Decompiling a whole assembly to stdout floods the context. Target a type.

Do not decompile to learn a signature - a property's type, a member list, which overloads exist.
Read the callers already in the repo, or use `-l`. Decompile to learn what a body *does*.

## Find the assembly

| Source | Path |
|---|---|
| NuGet package | `<global-packages>/<id>/<version>/lib/<tfm>/<Assembly>.dll` |
| .NET runtime | listed by `dotnet --list-runtimes`, then `<path>/<version>/<Assembly>.dll` |
| SDK reference assemblies | listed by `dotnet --list-sdks`, under `packs/Microsoft.NETCore.App.Ref/` |
| This solution's build output | `bin/Debug/<tfm>/`, `bin/Release/<tfm>/publish/` |
| Legacy `packages.config` solution | `packages/<Id>.<Version>/lib/<tfm>/<Assembly>.dll` |

**Validate the version before you trust the output.** Resolve the referenced version in this order:
the project's `PackageReference`, then `Directory.Packages.props` (central package management), then
a legacy `packages.config`. Confirm the dll path you picked carries that version - a version glob
matches every version ever restored, and `head -1` takes the oldest.

The global packages folder is **not** always `~/.nuget/packages` - `NUGET_PACKAGES` or a
`globalPackagesFolder` setting moves it. Ask NuGet:

```bash
dotnet nuget locals global-packages --list
```

## Package not on this machine

Pull it from a feed into the cache, then decompile from there. Run inside the repository so its
`nuget.config` sources apply (a package from a private feed needs that feed configured):

```bash
dotnet nuget list source
dotnet new classlib -o "$TEMP/pkgfetch" -f net8.0
dotnet add "$TEMP/pkgfetch" package Newtonsoft.Json --version 13.0.3
dotnet nuget locals global-packages --list
```

`dotnet add package` restores into the global cache even when the project itself never builds, so
the `lib/<tfm>/*.dll` is on disk afterwards. For a feed the config does not list, add
`--source <url>`. A `.nupkg` already downloaded is a zip - unzip it and read `lib/<tfm>/`.

## Commands

```bash
ilspycmd -t Namespace.Type <dll>            # one type as C#
ilspycmd -il -t Namespace.Type <dll>        # the same type as IL
ilspycmd -l class|interface|struct|enum|delegate <dll>
ilspycmd -p -o ./src <dll>                  # whole assembly as a compilable project
ilspycmd -r ./dependencies <dll>            # resolve references from a folder
ilspycmd -lv CSharp12_0 <dll>               # target C# version (CSharp1..CSharp12_0, Latest, Preview)
ilspycmd --no-dead-code <dll>
ilspycmd -h
```

## Example

```powershell
$cache = (dotnet nuget locals global-packages --list) -replace '.*:\s*', ''
$dll   = "$cache\newtonsoft.json\13.0.3\lib\net45\Newtonsoft.Json.dll"
ilspycmd -l class $dll | Select-String JsonConvert
ilspycmd -t Newtonsoft.Json.JsonConvert $dll > "$env:TEMP\ilspy\Newtonsoft.Json.13.0.3\Newtonsoft.Json.JsonConvert.cs"
```

From Git Bash a path with spaces breaks `dnx.cmd` - quoting does not survive the `.cmd` shim and
`C:\Program Files\...` fails as `'C:\Program' is not recognized`. Use the 8.3 name
(`C:/PROGRA~1/...`) or run it from PowerShell.
