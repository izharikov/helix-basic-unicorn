# SPE verified command inventory

Every name below was read from `doc.sitecorepowershell.com`. Nothing here is from memory.

A `Verb-Noun` that is **not** in this file is either a stock PowerShell cmdlet or does not exist.
Verify before writing it — see `SKILL.md`.

## Fetching a command's real signature

Per-command pages exist for the appendix categories and return clean markdown:

```
https://doc.sitecorepowershell.com/appendix/<category>/<lowercase-command>.md
```

`<category>` is one of `common`, `indexing`, `packaging`, `presentation`, `security`, `session`
(the sections below). `provider` is a category too but contains only `get-item`.
`<lowercase-command>` must be lowercase — `.../security/Set-User.md` does **not** resolve. Example:
`https://doc.sitecorepowershell.com/appendix/security/set-user.md` returns full syntax, every
parameter and worked examples.

Always append `.md` — the plain URL is a JS shell. A wrong path (bad category, wrong case, missing
`appendix/`) still returns **HTTP 200**, with a body that starts `# Page Not Found` and a
"Suggested Pages" list. Treat that body as *unverified*, not as an answer.

Site-wide index: `https://doc.sitecorepowershell.com/llms.txt`.
Any doc page takes `.md` (`https://doc.sitecorepowershell.com/working-with-items/editing-items.md`).

---

## Provider and item cmdlets

**The appendix does not cover these.** `appendix/provider.md` lists `Get-Item` and nothing else.
The names and parameters below come from the *Working with Items* pages instead.

| Cmdlet | Verified parameters | Source page |
|---|---|---|
| `Get-Item` | `-Path -ID -Language -Version -Query -Uri -Database -AmbiguousPaths` | `retrieving-items` |
| `Get-ChildItem` | `-Path -Recurse -Language -Version -ID -WithParent` | `retrieving-items` |
| `New-Item` | `-Path -Parent -Name -ItemType -Language -ForceId -StartWorkflow` | `creating-and-removing-items` |
| `Remove-Item` | `-Path -Permanently -FailSilently` | `creating-and-removing-items` |
| `Copy-Item` | `-Path -Destination -DestinationItem -Recurse -PassThru -TransferOptions -FailSilently` | `moving-and-copying-items` |
| `Move-Item` | `-Path -Destination -DestinationItem -FailSilently` | `moving-and-copying-items` |
| `Set-ItemProperty` | `-Path -Name -Value` | `editing-items` |
| `Test-Path` | path | `moving-and-copying-items` |
| `Add-ItemLanguage` | `-Language -TargetLanguage -IfExist` | `item-languages` |
| `Remove-ItemLanguage` | `-Language` | `item-languages` |
| `Initialize-Item` | — | `retrieving-items` (also `appendix/indexing`) |

`-ItemType` takes a template path *or* a template GUID string.

### Setting field values

There is no `Set-ItemField` cmdlet. Three documented ways (`working-with-items/editing-items.md`):

```powershell
$item.Title = "value"            # automated property
$item["FieldName"] = "value"     # bracket notation, inside an edit context
Set-ItemProperty -Path $p -Name "FieldName" -Value "value"
```

Values accept strings, `DateTime`, item references (link/image fields), and arrays (multi-value).
The raw Sitecore API (`$item.Editing.BeginEdit()` / `$item.Fields[..].SetValue(..)` / `EndEdit()`)
is also used in this repo — see `Sync Article Components`.

---

## Appendix: Common

Add-BaseTemplate, Add-ItemVersion, Close-Window, ConvertFrom-CliXml, ConvertFrom-ItemClone,
ConvertTo-CliXml, Expand-Token, Get-Archive, Get-ArchiveItem, Get-Cache, Get-Database,
Get-ItemClone, Get-ItemCloneNotification, Get-ItemField, Get-ItemReference, Get-ItemReferrer,
Get-ItemTemplate, Get-ItemWorkflowEvent, Get-SitecoreJob, Get-SpeModule, Get-SpeModuleFeatureRoot,
Get-TaskSchedule, Get-UserAgent, Import-Function, Invoke-JavaScript, Invoke-Script,
Invoke-ShellCommand, Invoke-Workflow, New-ItemClone, New-ItemWorkflowEvent, New-UsingBlock,
Out-Download, Publish-Item, Read-Variable, Receive-File, Receive-ItemCloneNotification,
Remove-BaseTemplate, Remove-ArchiveItem, Remove-ItemVersion, Reset-ItemField, Restart-Application,
Restore-ArchiveItem, Send-File, Send-SheerMessage, Set-HostProperty, Set-ItemTemplate, Show-Alert,
Show-Application, Show-Confirm, Show-FieldEditor, Show-Input, Show-ListView, Show-ModalDialog,
Show-Result, Show-YesNoCancel, Start-TaskSchedule, Test-BaseTemplate, Test-Rule,
Update-ItemReferrer, Update-ListView, Write-Log

## Appendix: Indexing

Find-Item, Get-SearchIndex, Initialize-Item, Initialize-SearchIndex, Initialize-SearchIndexItem,
Remove-SearchIndexItem, Resume-SearchIndex, Stop-SearchIndex, Suspend-SearchIndex

## Appendix: Packaging

Export-Item, Export-Package, Export-UpdatePackage, Get-Package, Get-Preset, Get-UpdatePackageDiff,
Import-Item, Install-Package, Install-UpdatePackage, New-ExplicitFileSource, New-ExplicitItemSource,
New-FileSource, New-ItemSource, New-SecuritySource, New-Package

## Appendix: Presentation

Add-PlaceholderSetting, Add-Rendering, Get-Layout, Get-LayoutDevice, Get-PlaceholderSetting,
Get-Rendering, Get-RenderingParameter, Merge-Layout, New-PlaceholderSetting, New-Rendering,
Remove-PlaceholderSetting, Remove-Rendering, Remove-RenderingParameter, Reset-Layout, Set-Layout,
Set-Rendering, Set-RenderingParameter, Switch-Rendering

## Appendix: Provider

Get-Item — the only entry. See the provider table above for the rest.

## Appendix: Security

Add-ItemAcl, Add-RoleMember, Clear-ItemAcl, Disable-User, Enable-User, Export-Role, Export-User,
Get-Domain, Get-ItemAcl, Get-Role, Get-RoleMember, Get-User, Import-Role, Import-User, Lock-Item,
Login-User, Logout-User, New-Domain, New-ItemAcl, New-Role, New-User, Protect-Item, Remove-Domain,
Remove-Role, Remove-RoleMember, Remove-User, Set-ItemAcl, Set-User, Set-UserPassword, Test-Account,
Test-ItemAcl, Unlock-Item, Unlock-User, Unprotect-Item

## Appendix: Session

Get-ScriptSession, Get-Session, Receive-ScriptSession, Remove-ScriptSession, Remove-Session,
Start-ScriptSession, Stop-ScriptSession, Wait-ScriptSession

---

## Traps

- `Set-ItemField` does not exist. `Get-ItemField` and `Reset-ItemField` do. Set values the three
  ways shown above.
- `Get-ItemLanguage` is unverified — `Add-ItemLanguage` and `Remove-ItemLanguage` are documented,
  that one is not. Confirm before using it.
- `Get-Item -Path` needs the database prefix (`master:\content\home`) unless `-Database` is passed.
- Path separators: docs use `master:\content`, this repo uses `master:/sitecore/...` and bare
  `/sitecore/...`. Both work; match the surrounding script.
- `New-Item -ItemType` is the template, not a file-system type.
- `Set-User -StartUrl` is typed `<String>`; the docs say only that it is "validated with a
  pretermined set" and never list the values. Observed set — **decompiled, not doc-verified** —
  `Default,ContentEditor,PageEditor,Preview,Desktop`. Other cmdlets carry undocumented ValidateSets
  too — a parameter page listing `<String>` is not proof any string is accepted.
- Version compatibility per Sitecore release: `https://doc.sitecorepowershell.com/appendix.md`.

### Users, roles and profiles

```powershell
$name = (Get-User -Identity $name).Name                       # domain-qualify; bare name = silent no-op

New-User -Identity $name -Enabled -Password b `               # profile fields at creation
  -Email a@b.c -FullName "A B" -Comment "" -Portrait ""
Set-User -Identity $name -Email a@b.c -FullName "A B"          # existing account; no raw Profile API needed

$u = Get-User -Identity $name -Authenticated                  # -Authenticated required to WRITE Profile.*
$u.Profile.RegionalIsoCode = "de-DE"                          # else: "cannot be set for anonymous users"
$u.Profile.Save()

Add-RoleMember -Identity "sitecore\Author" -Members $name -ErrorAction Stop   # name strings, not User objects
```

- `Get-User` without `-Authenticated`: reads fine, `Profile.*` writes throw unless `allowAnonymous`.
- `RegionalIsoCode` getter falls back to `Settings.DefaultRegionalIsoCode` — reads non-empty even when unset.
- `Set-User -StartUrl` (enum, above) ≠ `Profile.StartUrl` (raw URL string).
- `$user.Roles` = direct membership only; indirect follows from the parent role.
- `Add-RoleMember -Members` with a `User` object throws `Object reference not set...`; error is non-terminating without `-ErrorAction Stop`.
