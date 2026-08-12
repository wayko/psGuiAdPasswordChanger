# psGuiAdPasswordChanger

A PowerShell **WPF** GUI for resetting user passwords in on‑prem **Active Directory**.
Built to run in **PowerShell 7** (recommended) and also works in **Windows PowerShell 5.1**
on Windows. WPF requires an **STA** thread — the launcher takes care of that automatically.

> The launcher is intentionally minimal: it only guarantees STA, dot‑sources the
> modules/functions, loads config + logging and shows the window. All real logic lives
> in `functions\function` (one function per file) and `modules`.

---

## Run

```powershell
# Recommended (PowerShell 7)
pwsh -STA -File .\adPasswordChanger.ps1

# Windows PowerShell 5.1 also works
powershell -STA -File .\adPasswordChanger.ps1
```

If you start it without `-STA`, the launcher relaunches itself in STA mode for you.

No live domain? Set `Demo.Enabled = true` in the config (below) to explore the GUI with
sample data. If the **ActiveDirectory** module is missing, the app auto‑falls back to demo
mode (controlled by `Demo.AutoFallbackWhenNoAd`).

---

## Folder layout

```
psGuiAdPasswordChanger\
├─ adPasswordChanger.ps1        # minimal loader
├─ modules\
│  └─ Import-AppModules.ps1         # loads WPF assemblies + ActiveDirectory
├─ functions\function\             # one function per file
│  ├─ Get-AppConfig.ps1  Initialize-AppLog.ps1  Write-AppLog.ps1
│  ├─ Get-AdPasswordPolicy.ps1  Get-PasswordPolicyText.ps1
│  ├─ New-CompliantPassword.ps1  Test-PasswordCompliance.ps1
│  ├─ Get-AdChildOu.ps1  Get-AdOuUser.ps1  Get-UserStatusTag.ps1
│  ├─ ConvertTo-UserObject.ps1  Get-DemoData.ps1  Get-TopOuFromDn.ps1
│  ├─ Set-AdUserPassword.ps1  Set-AdAccountOption.ps1  Invoke-PasswordRun.ps1
│  ├─ New-HtmlReport.ps1  New-CsvReport.ps1  Save-Report.ps1
│  ├─ New-TreeNode.ps1  Expand-TreeNode.ps1  Set-NodeCheckState.ps1
│  ├─ Get-TreeItem.ps1  Get-SelectedUser.ps1  Update-SelectedCount.ps1
│  ├─ Update-UserFilter.ps1  Update-LogFilter.ps1  Invoke-GenerateSample.ps1
│  ├─ Get-GuiGeneratorSetting.ps1  Search-AdUser.ps1  Connect-AdData.ps1
│  └─ Invoke-GuiRun.ps1  Invoke-GlobalSearch.ps1  Show-MainWindow.ps1
├─ settings\config\config.json      # settings
├─ asset\logo\                       # logo used in GUI header + HTML report
├─ asset\xaml\MainWindow.xaml        # the WPF layout
└─ logs\                             # daily log files (auto‑created)
```

---

## What it does

* **Full OU tree, lazy‑loaded.** The tree shows the domain's OU structure. Expanding an OU
  reveals its child OUs and the users directly in it (loaded on demand, so large domains
  stay responsive). Each OU shows the number of users in its whole subtree, computed with a
  single fast query per level. Each user shows its display name and username plus status
  tags: **[Disabled] [Locked] [PW Expired]**, **[PW Expire : YYYY‑MM‑DD]**,
  **[Account Expired]** / **[Account Expire : YYYY‑MM‑DD]**.
* **No hard‑coded password rule.** There is only a generator that follows the domain
  **GPO password policy**. The effective policy is read live and shown in the GUI, the
  generator states how complex the password must be, and **Generate sample** shows a grey
  example. Every generated password is guaranteed to satisfy the policy (length + 3‑of‑4
  complexity categories when complexity is enabled). Character sets are cryptographically
  random (`RandomNumberGenerator`).
* **Buttons.** `Connect & Load AD` (green) connects and loads the tree; `Reload AD`
  reloads it.
* **Global search + status filter.** A directory search box finds people **anywhere in
  the domain** (by name, display name, account or personal id — not just nodes already
  loaded in the tree). Results appear with checkboxes and feed the same run as tree
  selections; **Back to tree** returns to the OU view. The tree itself can still be
  filtered by **Year 1/2/3** and **active / disabled** (the *Show* dropdown), and the log
  box has its own search.
* **Account options.** Enable/disable, unlock, *password never expires*, *must change at
  next logon* — the last two are mutually exclusive and blocked from being set together
  (in the UI and defensively in code).
* **Test mode / What‑if.** `What if ( Simulate Change Password )` always simulates.
  `Change Passwords (live)` performs the real reset — but only when **Test mode** is
  unchecked; with Test mode on, a live click is safely downgraded to a simulation.
* **Reports.** One **HTML** + one **CSV** per top‑level OU, with an optional combined
  report for all OUs. Reports are written to the output folder, which opens after the run.
  The HTML report has columns Name / Account / Status / State / PW, quick filter buttons
  (**Active, Inactive, Locked, PW never expires**), a search box, and Changed/Skipped tabs.
  Table **rows** use rotating colours (columns are not coloured); **hovering** a row makes
  its text bold and changes the row background.
* **Logging.** Everything is logged to the on‑screen log box and to a **daily log file**
  in `logs\` (with configurable retention).

---

## Configuration — `settings\config\config.json`

The file is created with defaults on first run. Key settings:

| Section | Key | Meaning |
|--------|-----|---------|
| `Domain` | `Server` | Optional DC / domain to target (blank = current domain). |
| `Domain` | `SearchBase` | The OU used as the tree root. Blank = domain root; the top level is the OUs one level below it. |
| `Domain` | `IncludeEmptyOus` | Show OUs with 0 users. |
| `Attributes` | `PersonalIdAttribute` | AD attribute holding the personal id (default `employeeID`). |
| `Attributes` | `DisplayNameAttribute` | Attribute used as the display name. |
| `Generator` | `DefaultLength`, `UseUpper/Lower/Digit/Special`, `SpecialChars`, `AvoidAmbiguous`, `SamePasswordForAll` | Generator defaults (the policy always wins on minimum length/complexity). |
| `Report` | `OutputFolder` | Where HTML/CSV reports are written. |
| `Report` | `OpenAfterRun` | Open the output folder when a run finishes. |
| `Report` | `CombinedReportByDefault` | Tick the combined‑report box by default. |
| `Logging` | `Folder`, `RetentionDays` | Log folder and how long to keep daily logs. |
| `Ui` | `DomainLabel`, `TestModeDefault` | Header label override; default state of the Test‑mode checkbox. |
| `Demo` | `Enabled`, `AutoFallbackWhenNoAd` | Force demo data; auto‑demo when AD is unavailable. |

---

## Assumptions worth confirming for your domain

The tree is a generic **OU tree**. Set `SearchBase` in the config to the OU you want as the
root (blank = the domain root, so the top level is the OUs directly under the domain, e.g.
`TEST`, `Domain Controllers`). Reports are grouped per top‑level OU under that base.

## Requirements

* Windows with the **.NET Desktop runtime** (for WPF).
* **PowerShell 7** (or Windows PowerShell 5.1).
* **RSAT ActiveDirectory** module for live use (`Get-ADDefaultDomainPasswordPolicy`,
  `Get-ADUser`, `Set-ADAccountPassword`, …). Without it, the app runs in demo mode.
* Rights to reset passwords / modify the account options for the target OUs.
