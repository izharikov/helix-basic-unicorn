# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Sitecore **XM** solution (XM1 container topology), platform **10.4.1**, targeting **.NET Framework 4.8**, non-SDK `.csproj`. Helix layers under `src/{Foundation,Feature,Project}/<Module>/website`, with a `serialization/` sibling per module. Assembly and root namespace are `BasicCompany.<Layer>.<Module>` (e.g. `BasicCompany.Feature.Navigation`); `src/Environment/Website` is the build-only aggregator, not a module.

## Serialization

**Unicorn 4.1.6** (Rainbow YAML). Item changes land as `.yml` files under each module's `serialization/` folder and show up in a git diff — never edit the content DB directly. Each module registers its predicate in `App_Config/Include/.../*.Serialization.config`.

## Code generation

No codegen. A YAML template change produces no `.cs`. Field and template IDs are hand-maintained per module in `src/<Layer>/<Module>/website/Templates.cs` as `ID` constants. The `sc-template` skill's `codegen.command` is `null` — after adding a field, add the matching constant to `Templates.cs` by hand.

## Build & publish

`.\publish-website.ps1` is the single entry point. It restores and builds `src/Environment/Website/Website.csproj` (which pulls in every `Foundation|Feature|Project/*/website/*.csproj` via `src/Environment/Website/Directory.Build.props` globs — do not add project references there by hand) and file-system-publishes the merged web root to `docker\deploy\website`. Params: `-Configuration Debug|Release`, `-Mode Full|Quick`, `-NoRestore`. The Docker image build runs the same script. Requires MSBuild from Visual Studio 2022.

Central package versions: `Packages.props` (versions) + `Directory.Build.targets` (CentralPackageVersions SDK). `PlatformVersion` / `UnicornVersion` drive the pins.

## Tests

xUnit projects at `src/Feature/<Module>/tests/BasicCompany.Feature.<Module>.Tests.csproj` (`Sitecore.FakeDb` + `Moq`). Non-SDK, so run through Visual Studio Test Explorer or `vstest.console.exe` against the built `*.Tests.dll` (msbuild restore + build first). Filter a single test with the runner's `/Tests:` switch.
