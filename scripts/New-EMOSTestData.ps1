#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates test data for EMOS integration testing.
.DESCRIPTION
    Creates 150 dynamic groups, 150 dynamic AUs, and 5 EM access package policies
    all using the MemberOf rule operator, with mixed complexity (Low/Medium/High).
    All objects are prefixed with EMOS_ for easy identification and cleanup.

    Run Remove-EMOSTestData.ps1 to clean up all created objects.

.PARAMETER TenantId
    Entra tenant ID. Falls back to $env:tenantid.
.PARAMETER GroupCount
    Number of dynamic groups to create (default 150).
.PARAMETER AUCount
    Number of dynamic AUs to create (default 150).
.PARAMETER APCount
    Number of EM access package policies to create (default 5).
.PARAMETER WhatIf
    Show what would be created without actually creating anything.
.EXAMPLE
    ./New-EMOSTestData.ps1 -TenantId $env:tenantid
.EXAMPLE
    ./New-EMOSTestData.ps1 -GroupCount 10 -AUCount 10 -APCount 2  # quick smoke test
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TenantId  = $env:tenantid,
    [int]$GroupCount   = 150,
    [int]$AUCount      = 150,
    [int]$APCount      = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Authentication -Force

#region ── Auth ──────────────────────────────────────────────────────────────
$requiredScopes = @(
    'Group.ReadWrite.All'
    'AdministrativeUnit.ReadWrite.All'
    'EntitlementManagement.ReadWrite.All'
    'Directory.ReadWrite.All'
)
$ctx = Get-MgContext -ErrorAction SilentlyContinue
$missingScopes = $requiredScopes | Where-Object { $_ -notin @($ctx.Scopes) }
if (-not $ctx -or $missingScopes) {
    if ($missingScopes) { Write-Host "Reconnecting — missing scopes: $($missingScopes -join ', ')" -ForegroundColor Yellow }
    Connect-MgGraph -TenantId $TenantId -Scopes $requiredScopes -NoWelcome
}
Write-Host "Connected: $((Get-MgContext).Account) | $((Get-MgContext).TenantId)" -ForegroundColor Green
#endregion

#region ── Helpers ───────────────────────────────────────────────────────────
function Invoke-GraphPost {
    param([string]$Uri, [hashtable]$Body)
    Invoke-MgGraphRequest -Method POST -Uri $Uri -Body ($Body | ConvertTo-Json -Depth 5) `
        -ContentType 'application/json' -OutputType PSObject
}

function New-MemberOfRule {
    param([int]$Complexity)
    # Complexity = number of group IDs in the -in list
    # We use the real existing EMOSTEST1 source groups + generated fake GUIDs
    $ids = 1..$Complexity | ForEach-Object { "'$([guid]::NewGuid())'" }
    return "user.memberof -any (group.objectId -in [$($ids -join ', ')])"
}

function Get-ComplexityLabel {
    param([int]$Complexity)
    if ($Complexity -ge 3) { 'High' }
    elseif ($Complexity -eq 2) { 'Medium' }
    else { 'Low' }
}
#endregion

#region ── 1. Source groups (idempotent) ─────────────────────────────────────
Write-Host "`n[1/4] Ensuring source reference groups exist..." -ForegroundColor Cyan
$sourceGroupIds = @()
1..3 | ForEach-Object {
    $name = "EMOS_Source_$_"
    # Reuse if already exists
    $existing = (Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$name'&`$select=id,displayName&`$count=true" `
        -Headers @{ConsistencyLevel='eventual'} -OutputType PSObject).value
    if ($existing) {
        $sourceGroupIds += $existing[0].id
        Write-Host "  ↩ Reusing: $name ($($existing[0].id))" -ForegroundColor DarkGray
    } elseif ($PSCmdlet.ShouldProcess($name, 'Create source group')) {
        $g = Invoke-GraphPost -Uri 'https://graph.microsoft.com/v1.0/groups' -Body @{
            displayName     = $name
            mailEnabled     = $false
            mailNickname    = "emos-src-$_"
            securityEnabled = $true
        }
        $sourceGroupIds += $g.id
        Write-Host "  ✓ $name ($($g.id))" -ForegroundColor DarkGray
    }
}
Write-Host "Source groups: $($sourceGroupIds.Count)"
#endregion

#region ── 2. Dynamic groups ─────────────────────────────────────────────────
Write-Host "`n[2/4] Creating $GroupCount dynamic groups with MemberOf rules..." -ForegroundColor Cyan

$groupResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$batchSize    = 20   # Graph batch API max

for ($i = 1; $i -le $GroupCount; $i++) {
    # Distribute complexity: ~1/3 Low, ~1/3 Medium, ~1/3 High
    $complexity = switch (($i % 3)) { 0 { 1 } 1 { 2 } 2 { 3 } }
    $label      = Get-ComplexityLabel $complexity
    $name       = "EMOS_Group_{0:D3}_{1}" -f $i, $label
    $rule       = New-MemberOfRule -Complexity $complexity

    if ($PSCmdlet.ShouldProcess($name, 'Create dynamic group')) {
        try {
            $g = Invoke-GraphPost -Uri 'https://graph.microsoft.com/v1.0/groups' -Body @{
                displayName     = $name
                mailEnabled     = $false
                mailNickname    = "emos-g-$i"
                securityEnabled = $true
                groupTypes      = @('DynamicMembership')
                membershipRule  = $rule
                membershipRuleProcessingState = 'On'
            }
            $groupResults.Add([PSCustomObject]@{ Name = $name; Id = $g.id; Complexity = $label })
            if ($i % 10 -eq 0) { Write-Host "  Groups: $i/$GroupCount" -ForegroundColor DarkGray }
        }
        catch {
            Write-Warning "Failed to create $name : $_"
        }
    }
}
Write-Host "Created: $($groupResults.Count)/$GroupCount groups" -ForegroundColor Green
#endregion

#region ── 3. Dynamic Administrative Units ───────────────────────────────────
Write-Host "`n[3/4] Creating $AUCount dynamic AUs with MemberOf rules..." -ForegroundColor Cyan

$auResults = [System.Collections.Generic.List[PSCustomObject]]::new()

for ($i = 1; $i -le $AUCount; $i++) {
    $complexity = switch (($i % 3)) { 0 { 1 } 1 { 2 } 2 { 3 } }
    $label      = Get-ComplexityLabel $complexity
    $name       = "EMOS_AU_{0:D3}_{1}" -f $i, $label
    $rule       = New-MemberOfRule -Complexity $complexity

    if ($PSCmdlet.ShouldProcess($name, 'Create dynamic AU')) {
        try {
            $au = Invoke-GraphPost -Uri 'https://graph.microsoft.com/beta/administrativeUnits' -Body @{
                displayName    = $name
                description    = "EMOS test AU - $label complexity MemberOf rule"
                membershipType = 'Dynamic'
                membershipRule = $rule
                membershipRuleProcessingState = 'On'
            }
            $auResults.Add([PSCustomObject]@{ Name = $name; Id = $au.id; Complexity = $label })
            if ($i % 10 -eq 0) { Write-Host "  AUs: $i/$AUCount" -ForegroundColor DarkGray }
        }
        catch {
            Write-Warning "Failed to create $name : $_"
        }
    }
}
Write-Host "Created: $($auResults.Count)/$AUCount AUs" -ForegroundColor Green
#endregion

#region ── 4. EM Access Package Policies ─────────────────────────────────────
Write-Host "`n[4/4] Creating $APCount EM access package auto-assignment policies..." -ForegroundColor Cyan

$apResults = [System.Collections.Generic.List[PSCustomObject]]::new()

try {
    # Use the built-in General catalog — avoids catalog-owner permission issues
    $catalog = (Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/accessPackageCatalogs?`$filter=displayName eq 'General'" `
        -OutputType PSObject -ErrorAction Stop).value | Select-Object -First 1

    if (-not $catalog) { throw "General catalog not found — Entitlement Management may not be enabled." }
    Write-Host "  ✓ Using built-in catalog: General ($($catalog.id))" -ForegroundColor DarkGray

    for ($i = 1; $i -le $APCount; $i++) {
        $complexity = switch (($i % 3)) { 0 { 1 } 1 { 2 } 2 { 3 } }
        $label      = Get-ComplexityLabel $complexity
        $pkgName    = "EMOS_AP_{0:D2}_{1}" -f $i, $label

        if ($PSCmdlet.ShouldProcess($pkgName, 'Create access package + policy')) {
            # Skip if already exists
            $existingPkg = (Invoke-MgGraphRequest -Method GET `
                -Uri "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/accessPackages?`$filter=displayName eq '$pkgName'" `
                -OutputType PSObject).value | Select-Object -First 1
            if ($existingPkg) {
                Write-Host "  ↩ Reusing: $pkgName" -ForegroundColor DarkGray
                $apResults.Add([PSCustomObject]@{ Name = $pkgName; PolicyId = '(existing)'; Complexity = $label })
                continue
            }

            $pkg = Invoke-GraphPost `
                -Uri 'https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/accessPackages' `
                -Body @{ displayName = $pkgName; description = "EMOS test - $label complexity"; catalog = @{ id = $catalog.id } }

            $groupIds   = 1..$complexity | ForEach-Object { [guid]::NewGuid().ToString() }
            $filterExpr = "user.memberof -any (group.objectId -in [$( ($groupIds | ForEach-Object { "'$_'" }) -join ', ')])"

            $policy = Invoke-GraphPost `
                -Uri 'https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/assignmentPolicies' `
                -Body @{
                    displayName        = "${pkgName}_AutoPolicy"
                    description        = 'EMOS test auto-assignment policy'
                    accessPackage      = @{ id = $pkg.id }
                    allowedTargetScope = 'allMemberUsers'
                    automaticRequestSettings = @{
                        requestorFilterType                    = 'IncludeAll'
                        requestorFilterExpression              = $filterExpr
                        enableOnBehalfRequestorsToAddAccess    = $true
                        enableOnBehalfRequestorsToUpdateAccess = $true
                        enableOnBehalfRequestorsToRemoveAccess = $true
                        onBehalfRequestors                     = @()
                    }
                }
            $apResults.Add([PSCustomObject]@{ Name = $pkgName; PolicyId = $policy.id; Complexity = $label })
            Write-Host "  ✓ $pkgName" -ForegroundColor DarkGray
        }
    }
}
catch {
    Write-Warning "EM policy creation failed: $_"
}
Write-Host "Created: $($apResults.Count)/$APCount EM policies" -ForegroundColor $(if ($apResults.Count -eq $APCount) { 'Green' } else { 'Yellow' })
#endregion

#region ── Summary ───────────────────────────────────────────────────────────
Write-Host "`n=== TEST DATA SUMMARY ===" -ForegroundColor Cyan
Write-Host "Dynamic Groups : $($groupResults.Count)"
Write-Host "  Low    : $(@($groupResults | Where-Object Complexity -eq 'Low').Count)"
Write-Host "  Medium : $(@($groupResults | Where-Object Complexity -eq 'Medium').Count)"
Write-Host "  High   : $(@($groupResults | Where-Object Complexity -eq 'High').Count)"
Write-Host "Admin Units    : $($auResults.Count)"
Write-Host "  Low    : $(@($auResults | Where-Object Complexity -eq 'Low').Count)"
Write-Host "  Medium : $(@($auResults | Where-Object Complexity -eq 'Medium').Count)"
Write-Host "  High   : $(@($auResults | Where-Object Complexity -eq 'High').Count)"
Write-Host "EM Policies    : $($apResults.Count)"
Write-Host "`nRun 'Invoke-EMOSReport' to scan, then 'Remove-EMOSTestData.ps1' to clean up."
#endregion

