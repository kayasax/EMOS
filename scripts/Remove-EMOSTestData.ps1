#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Removes all EMOS_ prefixed test objects created by New-EMOSTestData.ps1.
.EXAMPLE
    ./Remove-EMOSTestData.ps1
.EXAMPLE
    ./Remove-EMOSTestData.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Import-Module Microsoft.Graph.Authentication -Force

$ctx = Get-MgContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Connect-MgGraph -Scopes @(
        'Group.ReadWrite.All'
        'AdministrativeUnit.ReadWrite.All'
        'EntitlementManagement.ReadWrite.All'
        'Directory.ReadWrite.All'
    ) -NoWelcome
}

function Invoke-GraphDelete { param([string]$Uri)
    Invoke-MgGraphRequest -Method DELETE -Uri $Uri -OutputType PSObject -ErrorAction SilentlyContinue
}

#region Groups
Write-Host "Removing EMOS_ dynamic groups..." -ForegroundColor Cyan
$response = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName,'EMOS_')&`$select=id,displayName&`$top=999&`$count=true" `
    -Headers @{ConsistencyLevel='eventual'} -OutputType PSObject
$groups = $response.value
while ($response.'@odata.nextLink') {
    $response = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink' -OutputType PSObject
    $groups  += $response.value
}
Write-Host "  Found $($groups.Count) groups"
foreach ($g in $groups) {
    if ($PSCmdlet.ShouldProcess($g.displayName, 'Delete group')) {
        Invoke-GraphDelete -Uri "https://graph.microsoft.com/v1.0/groups/$($g.id)"
        Write-Host "  ✓ Deleted: $($g.displayName)" -ForegroundColor DarkGray
    }
}
#endregion

#region AUs
Write-Host "`nRemoving EMOS_ Administrative Units..." -ForegroundColor Cyan
$response = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/administrativeUnits?`$filter=startswith(displayName,'EMOS_')&`$select=id,displayName&`$top=999" `
    -OutputType PSObject
$aus = $response.value
while ($response.'@odata.nextLink') {
    $response = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink' -OutputType PSObject
    $aus += $response.value
}
Write-Host "  Found $($aus.Count) AUs"
foreach ($au in $aus) {
    if ($PSCmdlet.ShouldProcess($au.displayName, 'Delete AU')) {
        Invoke-GraphDelete -Uri "https://graph.microsoft.com/beta/administrativeUnits/$($au.id)"
        Write-Host "  ✓ Deleted: $($au.displayName)" -ForegroundColor DarkGray
    }
}
#endregion

#region EM Catalog + packages
Write-Host "`nRemoving EMOS_ EM catalog and access packages..." -ForegroundColor Cyan
try {
    $catalogs = (Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/catalogs?`$filter=startswith(displayName,'EMOS_')" `
        -OutputType PSObject).value

    foreach ($cat in $catalogs) {
        # Delete packages first
        $pkgs = (Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/accessPackages?`$filter=catalog/id eq '$($cat.id)'" `
            -OutputType PSObject).value
        foreach ($pkg in $pkgs) {
            if ($PSCmdlet.ShouldProcess($pkg.displayName, 'Delete access package')) {
                Invoke-GraphDelete -Uri "https://graph.microsoft.com/beta/identityGovernance/entitlementManagement/accessPackages/$($pkg.id)"
                Write-Host "  ✓ Deleted package: $($pkg.displayName)" -ForegroundColor DarkGray
            }
        }
        if ($PSCmdlet.ShouldProcess($cat.displayName, 'Delete catalog')) {
            Invoke-GraphDelete -Uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/catalogs/$($cat.id)"
            Write-Host "  ✓ Deleted catalog: $($cat.displayName)" -ForegroundColor DarkGray
        }
    }
}
catch {
    Write-Warning "EM cleanup skipped: $_"
}
#endregion

Write-Host "`n✅ Cleanup complete." -ForegroundColor Green


