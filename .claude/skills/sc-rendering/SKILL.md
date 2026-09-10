---
name: sc-rendering
description: Create a Sitecore controller rendering with every artifact it needs - rendering YAML, view stub, csproj entry and placeholder registration. Use when asked to add a new rendering, a controller action with a view, or a Sitecore component.
---

# Create a Sitecore controller rendering

Run via `powershell -File`. Git Bash mangles `/sitecore/...` arguments into Windows paths before
PowerShell sees them.

```bash
powershell -File .claude/skills/sc-rendering/New-Rendering.ps1 -Module Accordion -RenderingName "Accordion Container" -ControllerClass AccordionController -ActionName Container -DatasourceTemplatePath "/sitecore/templates/Feature/Accordion/Accordion Container" -DatasourceModelInterface IAccordionContainer
```

- `-Layer Foundation` - defaults to `Feature`
- `-DatasourceLocation "<item path or query: expression>"` - defaults to the configured value
- `-Icon "Office/16x16/book.png"` - defaults to the configured value, omitted when neither is set
- `-SkipPlaceholder` - do not register the rendering in placeholder settings

Exit code **2** means the script needs something from you - it prints what, and writes nothing.

## What it writes

| Artifact | Detail |
|---|---|
| Rendering YAML | New GUID, parent taken from a sibling rendering |
| View stub | `Views/{ControllerPrefix}/{Action}.cshtml` |
| csproj entry | Only for old-style projects that list files explicitly |
| Placeholder registration | Appends the GUID to the configured placeholder settings item |

Not written: the controller action. The script prints it - add it to `{ControllerClass}.cs`,
adapted to the solution's base controller.

## Customising the output

`templates/` holds the output shapes. `rendering.yml.template` is a Sitecore item and ships fixed.
`view.cshtml.template` and `action.cs.template` are this solution's conventions: when they are
missing the script prints `templates/template-prompt.md` and exits 2, and you write them from the
views and controller the solution already has. Edit them later and every rendering follows.

`templates/template-prompt.md` lists every token and what it expands to. A token that survives
expansion stops the run rather than landing in a file.

## Rules

- **Never hand-edit the rendering GUID.** The script allocates it.
- Create the datasource template first, with `sc-template`, so `-DatasourceTemplatePath` and
  `-DatasourceModelInterface` point at something real.
- In the view, every visible string comes from a datasource field or the dictionary, never a
  literal.
