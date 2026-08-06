# Contributing to EMOS

Thank you for helping improve EMOS!

## Prerequisites

- PowerShell 7+
- [Pester 5](https://pester.dev/) (`Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser`)
- [Microsoft.Graph modules](https://learn.microsoft.com/powershell/microsoftgraph) (for integration tests)

## Development workflow

```powershell
git clone https://github.com/kayasax/EMOS
cd EMOS

# Run unit tests (no Graph connection needed)
./build.ps1 -Task Test

# Run full build + test
./build.ps1 -Task Build
```

## TDD approach

EMOS follows **Test-Driven Development**:

1. **Write a failing test first** in the appropriate `tests/Public/` or `tests/Private/` file.
2. **Run `./build.ps1`** — confirm it's RED.
3. **Implement** the minimal code to make it GREEN.
4. **Refactor** and re-run.

Every PR must include tests for new behaviour. PRs that reduce coverage below **70%** will not be merged.

## Test tags

| Tag | Meaning |
|---|---|
| *(none)* | Unit test — runs in CI with mocks, no Graph connection needed |
| `Integration` | Requires a live Entra tenant — excluded from CI, run manually |

Mark integration tests: `It 'does X' -Tag Integration { ... }`

## Commit conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add -IncludeOwners to Get-EMOSAffectedGroups
fix: handle null automaticRequestSettings in EM policies
test: add pagination coverage for Get-EMOSAffectedAdminUnits
docs: update README quickstart
```

## Releasing

1. Update `CHANGELOG.md` under `[Unreleased]` with what changed.
2. Create a GitHub Release with a semver tag (e.g. `v0.2.0`).
3. The [publish workflow](.github/workflows/publish.yml) will:
   - Run all tests
   - Stamp the version into `EMOS.psd1`
   - Publish to PSGallery automatically

> **Note:** A `PSGALLERY_API_KEY` secret must be set in the repo settings for publishing to work.

## Pull request checklist

- [ ] Tests written and passing (`./build.ps1 -Task Test`)
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] No hardcoded tenant IDs or credentials
- [ ] `Get-Help` comment blocks updated if cmdlet signature changed
