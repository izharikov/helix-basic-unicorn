---
name: spe
description: Verified SPE cmdlet names and parameters from doc.sitecorepowershell.com. Use when writing or changing PowerShell that runs inside Sitecore — Script Library items, reports, context-menu scripts, tasks.
---

# Sitecore PowerShell Extensions — syntax

SPE cmdlets are **not** stock PowerShell and **not** the Sitecore .NET API. Names look guessable
but aren't — `Set-ItemField` sounds obvious and doesn't exist. Wrong names fail only at runtime;
no compile step catches them.

## The rule

**Never write a `Verb-Noun` you have not verified.** Verification order:

1. Check `commands.md` in this skill folder — the full inventory read off the docs site.
2. Not there? Either a stock cmdlet (`Where-Object`, `Invoke-RestMethod`, `Import-Csv`) — fine —
   or it doesn't exist.
3. Unsure which: fetch the docs first.

**Never guess parameters either.** Fetch the command page:

```
https://doc.sitecorepowershell.com/appendix/<category>/<lowercase-command>.md
```

e.g. `.../appendix/common/read-variable.md`. Categories: `common`, `indexing`, `packaging`,
`presentation`, `security`, `session` — plus `provider`, which holds only `get-item`; every other
provider cmdlet is documented under `/working-with-items/` instead. `commands.md` maps every
command to its category. The command segment must be **lowercase** (`Set-User.md` does not resolve).

Always append `.md` — the plain URL is a JS shell. A wrong path (bad category, wrong case, missing
`appendix/`) still returns **HTTP 200** — body starts `# Page Not Found` with a "Suggested
Pages" list. Not a fetch failure, not an answer: treat the signature as unverified.

Read the **Examples** at the bottom of the page before the parameter list.

Provider cmdlets (`New-Item`, `Copy-Item`, `Add-ItemLanguage`, …) are **absent from the appendix**;
their signatures live on the docs site under
`https://doc.sitecorepowershell.com/working-with-items/<page>.md`. `commands.md` has the verified
table and names the source page per cmdlet.

## Read the Examples, not just the parameter list

Every command page ends with worked examples — the most useful part. The parameter list says what
exists; the examples say **which single call the command was designed for**. Read them first, copy
the shape.

Skipping them is how a one-liner turns into a workaround. `new-user.md` Example 2 is
`New-User -Identity michael -Enabled -Password b -Email michaellwest@gmail.com -FullName "Michael West"`
— the whole job in one call. Reading only the parameter table makes `-Email` and `-FullName` look
like things you set afterwards — sending you into `Set-User`, the profile API, the membership
provider, chasing writes that were never needed.

If a task looks like two or three chained cmdlets, re-read the first one's examples — often it
already does the whole job.

## SPE Context

- No console. `Read-Host` gets nothing — use `Read-Variable` for input, `Show-*` for dialogs.
- Context-menu / ribbon scripts get the clicked item from `Get-Item .`.
- `Get-Item -Path` needs a database prefix (`master:\content\home`) unless `-Database` given.
- No `Set-ItemField` — three documented ways to set a field value, see `commands.md`.
- Full Sitecore .NET API is reachable (`[Sitecore.Configuration.Settings]::GetSetting(...)`), but
  reach for it only when no SPE cmdlet does the job - check `commands.md` and the docs first.
  Once genuinely in .NET API territory, `sitecore-platform` answers config questions; decompile
  only a type whose behaviour those files leave unexplained.
- Users, roles and profiles fail silently — see the Traps in `commands.md` before touching them.
