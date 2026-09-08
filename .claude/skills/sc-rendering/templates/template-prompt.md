# sc-rendering needs this solution's view and action shape

A rendering's YAML is a Sitecore item and ships fixed. A view and a controller action are this
solution's conventions, and no default can guess them - a Glass Mapper view in a solution that
binds plain models is broken code that looks finished.

## Read first

- two or three existing views of one module, under the website root and views folder the
  configuration names
- the controller they belong to, in that module's controllers folder
- that module's project file - which mapper package it references, if any

## Then write both templates

`templates/view.cshtml.template` and `templates/action.cs.template`.

Keep what repeats across the views; drop what belongs to one component. Replace anything naming a
specific module, model, action or namespace with the matching token.

| Token | Expands to | Example |
|---|---|---|
| `{{NamespacePrefix}}` | `namespacePrefix` from config.json | `BasicCompany` |
| `{{Layer}}` | the layer | `Feature` |
| `{{Module}}` | the module | `Navigation` |
| `{{AssemblyName}}` | `{prefix}.{layer}.{module}` | `BasicCompany.Feature.Navigation` |
| `{{ControllerNamespace}}` | `rendering.controllerNamespace` expanded | `BasicCompany.Feature.Navigation.Controllers` |
| `{{ModelNamespace}}` | `rendering.modelNamespace` expanded | `BasicCompany.Feature.Navigation.Models` |
| `{{ControllerClass}}` | the `-ControllerClass` argument | `NavigationController` |
| `{{ActionName}}` | the `-ActionName` argument | `Header` |
| `{{DatasourceModelInterface}}` | the `-DatasourceModelInterface` argument | `Header`, `IHeader` |
| `{{RenderingName}}` | the rendering's display name | `Header Navigation` |

Item-only, for `rendering.yml.template` - never put these in a view or an action, they are written
in Rainbow's format and may arrive quoted or as a block scalar:

| Token | Expands to |
|---|---|
| `{{RenderingGuid}}` | new GUID for the rendering item, `d290f1ee-...`, no braces |
| `{{ParentGuid}}` | the folder GUID, read from a sibling rendering |
| `{{DatasourceTemplatePath}}` | the `-DatasourceTemplatePath` argument |
| `{{DatasourceLocation}}` | `-DatasourceLocation`, else `rendering.defaultDatasourceLocation` |
| `{{LanguagesBlock}}` | the whole `Languages:` section, one block per configured language |
| `{{Timestamp}}` | `yyyyMMddTHHmmssZ`, UTC |

A `{{Token}}` that survives expansion stops the run - a typo never reaches a file.

## Rules

- Never introduce a mapper, base controller or helper the solution does not already use.
- A view that renders a literal string is wrong: visible text comes from a field or the dictionary.
- Leave the body a TODO. The template is the frame, not the content.
