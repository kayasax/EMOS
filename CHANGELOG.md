# Changelog

All notable changes to EMOS are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial module scaffold: `Connect-EMOS`, `Get-EMOSAffectedGroups`, `Get-EMOSAffectedAdminUnits`, `Get-EMOSAffectedEMPolicies`, `Invoke-EMOSReport`
- HTML + CSV + JSON report output
- Conditional Access blast-radius enrichment
- Pester 5 test suite with mocks
- GitHub Actions CI workflow (Pester + coverage)
- GitHub Actions PSGallery publish workflow (triggered on release)
- `build.ps1` for local Test / Build / Pack / Publish tasks

## [0.1.0] - 2026-08-06

Initial release.
