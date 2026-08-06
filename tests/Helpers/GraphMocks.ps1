# Shared mock helpers loaded by BeforeAll in test files
# Usage: . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

function New-MockGroup {
    param(
        [string]$Id           = [guid]::NewGuid().ToString(),
        [string]$DisplayName  = 'Test Group',
        [string]$MembershipRule = 'user.department -eq "Sales"'
    )
    [PSCustomObject]@{
        id              = $Id
        displayName     = $DisplayName
        membershipRule  = $MembershipRule
        createdDateTime = '2025-01-01T00:00:00Z'
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
        [string]$Id             = [guid]::NewGuid().ToString(),
        [string]$DisplayName    = 'Test Policy',
        [string]$MembershipRule = "user.memberof -any (group.objectId -in ['g1'])",
        [string]$PackageId      = [guid]::NewGuid().ToString(),
        [string]$PackageName    = 'Test Package'
    )
    # Real structure: memberOf rule lives in specificAllowedTargets[].membershipRule
    [PSCustomObject]@{
        id          = $Id
        displayName = $DisplayName
        description = ''
        allowedTargetScope = 'specificDirectoryUsers'
        specificAllowedTargets = @(
            [PSCustomObject]@{
                '@odata.type'  = '#microsoft.graph.attributeRuleMembers'
                description    = 'test rule'
                membershipRule = $MembershipRule
            }
        )
        automaticRequestSettings = [PSCustomObject]@{
            requestAccessForAllowedTargets             = $true
            removeAccessWhenTargetLeavesAllowedTargets = $true
        }
        accessPackage = [PSCustomObject]@{
            id          = $PackageId
            displayName = $PackageName
        }
    }
}

# Real Entra MemberOf rule syntax
$script:REAL_MEMBEROF_RULE   = "user.memberof -any (group.objectId -in ['2409120030000681', '2409120030000682'])"
$script:REAL_MEMBEROF_RULE_1 = "user.memberof -any (group.objectId -in ['2409120030000681'])"
