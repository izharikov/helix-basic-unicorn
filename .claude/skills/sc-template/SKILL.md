---
name: sc-template
description: Manage Sitecore templates - create, add fields, rename, move, remove. Writes Rainbow YAML serialization directly, allocates GUIDs, and runs your code generator. Use when asked to add or change a Sitecore template, its sections, or its fields.
---

# Sitecore template management

```powershell
powershell -File .\.claude\skills\sc-template\Invoke-TemplateOp.ps1 -Json '<json>'
```

The JSON argument is one blob starting with `{`, so Git Bash leaves it alone and any shell works.
The one case that breaks is a **Windows PowerShell 5.1 parent** spawning the script: 5.1 rewrites
the quotes and the JSON arrives unparseable. Call it from bash, from pwsh, or directly.

Exit code **2** means the script needs something from you - it prints what, and writes nothing.

## Operations

All operations share `layer` (`Feature` / `Foundation` / `Project`), `module` and `templateName`.
Add `"skipCodegen": true` to any operation to suppress the generator run.

### get - read an existing template as JSON

```json
{ "operation": "get", "layer": "Feature", "module": "Accordion", "templateName": "Accordion Container" }
```

Use this before changing a template. It returns sections, fields, types, sort orders and standard
values, so you never guess at the current shape.

### create - new template, optionally with fields in one call

```json
{
  "operation": "create", "layer": "Feature", "module": "Accordion",
  "templateName": "Accordion Settings", "sectionName": "Data",
  "icon": "Office/32x32/gear.png", "baseTemplates": [],
  "fields": [
    { "name": "Title", "type": "Single-Line Text", "defaultValue": "Untitled" },
    { "name": "Type", "type": "Droplink", "source": "/sitecore/system/Settings/Feature/Accordion/Types", "shared": true }
  ]
}
```

### add-field

Single field:

```json
{ "operation": "add-field", "layer": "Feature", "module": "Accordion", "templateName": "Accordion Container",
  "sectionName": "Data", "name": "Title", "type": "Single-Line Text", "defaultValue": "Untitled" }
```

Batch, which is preferred because it triggers one generator run instead of several:

```json
{ "operation": "add-field", "layer": "Feature", "module": "Accordion", "templateName": "Accordion Container",
  "sectionName": "Data",
  "fields": [
    { "name": "Title", "type": "Single-Line Text" },
    { "name": "Icon", "type": "Image" },
    { "name": "Type", "type": "Droplink", "source": "/sitecore/system/Settings/...", "shared": true }
  ]
}
```

Per-field optional keys: `sectionName` (overrides the top-level one), `source`, `shared`,
`sortOrder`, `defaultValue`.

### rename-field

```json
{ "operation": "rename-field", "layer": "Feature", "module": "Accordion", "templateName": "Accordion Container",
  "sectionName": "Data", "oldFieldName": "Type", "newFieldName": "Accordion Type" }
```

### move-field

```json
{ "operation": "move-field", "layer": "Feature", "module": "Accordion", "templateName": "Accordion Container",
  "fieldName": "Title", "fromSection": "Data", "toSection": "Display" }
```

### remove-field

```json
{ "operation": "remove-field", "layer": "Feature", "module": "Accordion", "templateName": "Accordion Container",
  "sectionName": "Data", "fieldName": "Old Field" }
```

### remove - the whole template

```json
{ "operation": "remove", "layer": "Feature", "module": "Accordion", "templateName": "Old Template" }
```

## Field types

`type` is the Sitecore field type name, verbatim. What the field stores, and whether it needs a
`source`:

| Type | Raw value | Source |
|---|---|---|
| Single-Line Text, Multi-Line Text | text | - |
| Rich Text | HTML | optional - editor profile path (e.g. `/sitecore/system/Settings/Html Editor Profiles/Rich Text Default`) |
| Image | media reference XML | - (use this for icons too, never Single-Line Text) |
| General Link | link XML | - |
| Checkbox | `1` or empty | - |
| Integer | integer | - |
| Number | double | - |
| Date, Datetime | `yyyyMMddTHHmmssZ` | - |
| Droplink, Droptree | one GUID | required - item path |
| Multilist, Treelist, TreelistEx, Checklist | pipe-separated GUIDs | required - item path |

A field type this table does not list still works - pass the name Sitecore knows it by, including a
custom type from the solution.

Turning those raw values into code is the solution's own model layer - a generator, a mapper, or
hand-written ID constants. This skill never touches it; `codegen.command` in `config.json` runs
whatever the solution uses, if anything. After a field is added, follow that layer's convention:
regenerate, or add the constant or property by hand.

## __Standard Values

`defaultValue` in `create` and `add-field` populates the standard values automatically, in every
configured language, inserted in field-ID order. `remove-field` clears the entry again and
`rename-field` keeps its hint in step. For a field added without a default, edit
`__Standard Values.yml`.

## Rules

- **Never hand-edit a GUID.** Every identifier comes from the script.
- **Never edit generated model files.** They are rewritten on the next generator run.
- **Never use the reserved field names** `Name` and `DisplayName`.
- Read the template with `get` before changing it.
