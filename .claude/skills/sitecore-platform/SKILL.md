---
name: sitecore-platform
description: Read the Sitecore platform files shipped with the product - configuration patches, views, scripts and assemblies. Use when you need to know what Sitecore does by default, which pipeline processors run, or what a setting controls.
---

# Sitecore platform files

Sitecore ships its own source - `App_Config` XML, `sitecore/shell` views, scripts - and none of it
is on the public web. Read it from a clean installation on disk.

## First, read `config.json` next to this file

```json
{ "version": "10.4.1", "root": "D:/sitecore/10.4.1" }
```

Both set, and `<root>/App_Config` exists: use `<root>` and carry on silently.

**Either missing: ask the user where their unzipped Sitecore platform copy is, then stop and wait
for their answer.** Never search the disk, never assume a location, never proceed on a guess, and
**never start a Docker extraction on your own.** Write their answer into `config.json`.

### Only if the user says they have no unzipped copy

Then, and only then, offer to pull one from the CM image the solution runs. Do not run any `docker`
command until the user agrees to this path.

Find the image, never assume it - the name follows the topology (`sitecore-xm1-cm`,
`sitecore-xp0-cm`, `-xp1-`) and a solution that builds its own uses its own tag:

```powershell
docker compose config     # .env and override files resolved - read the cm service
```

If the cm service has a `build:`, extract from the **base** that build declares - a `BASE_IMAGE`
build arg in the compose file, or the `FROM` in its Dockerfile. The built image carries the
solution's own files on top, which is the patched copy this skill tells you not to read.

```powershell
docker create --name sc-extract <image>
docker cp sc-extract:C:/inetpub/wwwroot/App_Config <root>/
docker rm sc-extract
```

## What to read there

| Question | Where to look |
|---|---|
| Which processors run in a pipeline, and in what order | `App_Config/Sitecore/**/*.config` |
| What a setting defaults to | `App_Config/Sitecore/**/*.config`, `<settings>` |
| How a backend UI page is built | `sitecore/shell/**` |
| What an assembly actually does | Decompile that one type - see the `ilspy-decompile` skill |

Use a copy with **no project patches on top of it**: it answers "what does Sitecore do by default",
which is the question. What your solution does is already in the repository.

## Rules

- **Never cite a project `bin/` or `obj/` folder as platform source.** Stale build output, often
  copied from other modules.
- Prefer the shipped configuration over any blog post when the two disagree.
- If config and views leave a specific type's behaviour unexplained, decompile that type - see
  `ilspy-decompile`. Do not decompile to check an API shape.
