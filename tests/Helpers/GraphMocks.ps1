# Shared mock helpers loaded by BeforeAll in test files
# Usage: . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

function New-MockGroup {
    param(
        [string]$Id           = [guid]::NewGuid().ToString(),
        [string]$DisplayName  = 'Test Group',
        [string]$MembershipRule = 'user.department -eq "Sales"'
    )
    [PSCustomObject]@{
        Id             = $Id
        DisplayName    = $DisplayName
        MembershipRule = $MembershipRule
        CreatedDateTime = '2025-01-01T00:00:00Z'
    }
}

function New-MockAdminUnit {
    param(
        [string]$id          = [guid]::NewGuid().ToString(),
        [string]$displayName = 'Test AU',
        [string]$membershipRule = 'user.department -eq "HR"',
        [string]$description = ''
    )
    [PSCustomObject]@{
        id             = $id
        displayName    = $displayName
        membershipRule = $membershipRule
        description    = $description
        membershipType = 'Dynamic'
    }
}

function New-MockEMPolicy {
    param(
        [string]$Id          = [guid]::NewGuid().ToString(),
        [string]$DisplayName = 'Test Policy',
        [string]$RuleJson    = '"memberOf(group1)"',
        [string]$PackageId   = [guid]::NewGuid().ToString(),
        [string]$PackageName = 'Test Package'
    )
    [PSCustomObject]@{
        id          = $Id
        displayName = $DisplayName
        description = ''
        automaticRequestSettings = @{
            requestorFilterExpression = $RuleJson
        }
        accessPackage = @{
            id          = $PackageId
            displayName = $PackageName
        }
    }
}
