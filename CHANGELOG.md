# Changelog

All notable changes to EMOS are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-08-06

### Added
- `Connect-EMOS` with 6 auth flows: Interactive, DeviceCode, CertificateThumbprint, CertificatePath, ClientSecret, ManagedIdentity
- `Disconnect-EMOS`
- `Get-EMOSAffectedGroups` — scans dynamic groups, detects `user.memberof -any (group.objectId -in [...])` syntax, checks group-based licensing for blast radius
- `Get-EMOSAffectedAdminUnits` — scans dynamic AUs (beta endpoint)
- `Get-EMOSAffectedEMPolicies` — scans EM auto-assignment policies via `specificAllowedTargets[].membershipRule`
- `Invoke-EMOSReport` — full scan + HTML/CSV/JSON output, `-Show` to auto-open, `-IncludeOwners`
- HTML report: DataTables sorting/filtering, Type/Complexity/BlastRadius dropdowns, live search, Entra portal deep links, contextual action with group count
- Blast radius detection: ConditionalAccess (CA policy cross-reference) + Licensing (real `assignedLicenses` Graph call)
- `Invoke-EMOSGraphRequest` private helper: automatic pagination + 429 retry with Retry-After
- 88 Pester unit tests, GitHub Actions CI + PSGallery publish on release tag

### Notes
- Requires `Microsoft.Graph.Authentication` only (no Graph SDK submodules)
- Only `Microsoft.Graph.Authentication` module needed — all calls use `Invoke-MgGraphRequest` directly
- EM scanner tested against real tenant; requires Entra ID Governance license for EM policies

## [0.1.0] - 2026-08-06

Initial release.
