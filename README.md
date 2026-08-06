# EMOS — Entra MemberOf Scanner

> ⏰ **November 3, 2026 deadline:** The `MemberOf` dynamic rule operator in Microsoft Entra ID is being retired. This tool finds everything in your tenant that uses it.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/EMOS)](https://www.powershellgallery.com/packages/EMOS)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it does

EMOS scans your entire Entra tenant in one command and reports every object using the deprecated `MemberOf()` rule operator across:

| Surface | Cmdlet |
|---|---|
| Dynamic membership groups | `Get-EMOSAffectedGroups` |
| Dynamic Administrative Units | `Get-EMOSAffectedAdminUnits` |
| Entitlement Management auto-assignment policies | `Get-EMOSAffectedEMPolicies` |

It also cross-references affected groups against **Conditional Access policies** to surface blast-radius impact, and generates a prioritized HTML + CSV + JSON remediation report.

## Why it exists

The [Microsoft retirement announcement](https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-member-of) requires admins to manually run three separate Graph queries across different admin centers. EMOS does it in one shot, enriches the results, and tells you what to fix first.

## Quickstart

```powershell
# Install
Install-Module EMOS -Scope CurrentUser

# If your Documents folder syncs via OneDrive (files appear delayed), use:
# Save-Module EMOS -Path "$env:LOCALAPPDATA\powershell\Modules" -Force

# Connect (interactive browser auth)
Connect-EMOS

# Run full scan and generate report
Invoke-EMOSReport -IncludeOwners
```

Output files created in `$HOME/EMOS-Reports/`:
- `EMOS-Report-<timestamp>.html` — interactive dashboard
- `EMOS-Report-<timestamp>.csv`  — for bulk remediation tracking
- `EMOS-Report-<timestamp>.json` — for pipeline consumers

## Sample output

```
EMOS - Entra MemberOf Scanner
Retirement deadline: 2026-11-03 (89 days remaining)
------------------------------------------------------------
Scan complete:
  Dynamic groups with MemberOf : 3
  Dynamic AUs with MemberOf    : 1
  EM policies with MemberOf    : 2
  TOTAL                        : 6

HTML : C:\Reports\EMOS-Report-20260806-172301.html
CSV  : C:\Reports\EMOS-Report-20260806-172301.csv
JSON : C:\Reports\EMOS-Report-20260806-172301.json
```

## Cmdlet reference

### `Connect-EMOS`
```powershell
Connect-EMOS [-TenantId <string>] [-ClientId <string>] [-UseDeviceCode]
```
Connects to Microsoft Graph with the minimum required scopes:
`Group.Read.All`, `AdministrativeUnit.Read.All`, `EntitlementManagement.Read.All`, `Policy.Read.All`, `Application.Read.All`

### `Get-EMOSAffectedGroups`
```powershell
Get-EMOSAffectedGroups [-IncludeOwners]
```

### `Get-EMOSAffectedAdminUnits`
```powershell
Get-EMOSAffectedAdminUnits
```

### `Get-EMOSAffectedEMPolicies`
```powershell
Get-EMOSAffectedEMPolicies
```

### `Invoke-EMOSReport`
```powershell
Invoke-EMOSReport [-OutputPath <string>] [-IncludeOwners] [-NoHtml]
```

## Required permissions

| Permission | Why |
|---|---|
| `Group.Read.All` | List and read dynamic groups |
| `AdministrativeUnit.Read.All` | List and read dynamic AUs |
| `EntitlementManagement.Read.All` | Read EM assignment policies |
| `Policy.Read.All` | Blast-radius: CA policy correlation |
| `Application.Read.All` | Owner resolution |

## Remediation guidance

After running the report:

1. **Replace the rule** — rewrite using supported operators (`user.department`, `user.jobTitle`, etc.)
2. **Convert to assigned** — switch the group/AU to static assigned membership
3. **Delete if unused** — if the group/AU is stale, remove it

See the Microsoft docs for each surface:
- [Dynamic groups](https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-member-of)
- [Dynamic AUs](https://learn.microsoft.com/entra/identity/role-based-access-control/admin-units-members-dynamic)
- [EM auto-assignment](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-auto-assignment-policy)

## Contributing

Issues and PRs welcome. See [CONTRIBUTING.md](docs/CONTRIBUTING.md).

## License

MIT © Loic Michel



