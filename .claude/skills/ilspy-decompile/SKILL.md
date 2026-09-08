---
name: ilspy-decompile
description: Understand implementation details of .NET code by decompiling assemblies. Use when the user wants to see how a .NET API works internally, inspect NuGet package source, view framework implementation, or understand compiled .NET binaries.
---

# Decompile .NET assemblies with ILSpy

`dnx ilspycmd` needs no install with the .NET 10 SDK. From Git Bash call it as **`dnx.cmd`** - the
SDK ships a `.cmd` shim and bash does not apply PATHEXT, so the bare name is "command not found".

## Workflow

1. Locate the assembly (below).
2. `dnx ilspycmd -l class <dll>` - find the exact type name.
3. `dnx ilspycmd -t <Namespace.Type> <dll>` - decompile just that type.

Decompiling a whole assembly to stdout floods the context. Target a type.

## Find the assembly

| Source | Path |
|---|---|
| NuGet package | `<global-packages>/<id>/<version>/lib/<tfm>/<Assembly>.dll` |
| .NET runtime | listed by `dotnet --list-runtimes`, then `<path>/<version>/<Assembly>.dll` |
| SDK reference assemblies | listed by `dotnet --list-sdks`, under `packs/Microsoft.NETCore.App.Ref/` |
| This solution's build output | `bin/Debug/<tfm>/`, `bin/Release/<tfm>/publish/` |

The global packages folder is **not** always `~/.nuget/packages` - `NUGET_PACKAGES` or a
`globalPackagesFolder` setting moves it. Ask NuGet:

```bash
dotnet nuget locals global-packages --list
```

## Package not on this machine

Pull it from a feed into the cache, then decompile from there. Run inside the repository so its
`nuget.config` sources apply (a Sitecore assembly needs the Sitecore feed):

```bash
dotnet nuget list source
dotnet new classlib -o "$TEMP/pkgfetch" -f net8.0
dotnet add "$TEMP/pkgfetch" package Sitecore.Kernel --version 10.4.1
dotnet nuget locals global-packages --list
```

`dotnet add package` restores into the global cache even when the project itself never builds, so
the `lib/<tfm>/*.dll` is on disk afterwards. For a feed the config does not list, add
`--source <url>`. A `.nupkg` already downloaded is a zip - unzip it and read `lib/<tfm>/`.

## Commands

```bash
dnx ilspycmd -t Namespace.Type <dll>            # one type as C#
dnx ilspycmd -il -t Namespace.Type <dll>        # the same type as IL
dnx ilspycmd -l class|interface|struct|enum|delegate <dll>
dnx ilspycmd -p -o ./src <dll>                  # whole assembly as a compilable project
dnx ilspycmd -r ./dependencies <dll>            # resolve references from a folder
dnx ilspycmd -lv CSharp12_0 <dll>               # target C# version (CSharp1..CSharp12_0, Latest, Preview)
dnx ilspycmd --no-dead-code <dll>
dnx ilspycmd -h
```

## Example

```powershell
$cache = (dotnet nuget locals global-packages --list) -replace '.*:\s*', ''
$dll   = "$cache\sitecore.kernel\10.4.1\lib\net48\Sitecore.Kernel.dll"
dnx ilspycmd -l class $dll | Select-String Item
dnx ilspycmd -t Sitecore.Data.Items.Item $dll
```
