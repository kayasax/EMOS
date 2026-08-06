function Get-EMOSAffectedAdminUnits {
    <#
    .SYNOPSIS
        Finds all dynamic Administrative Units using the MemberOf rule operator.
    .DESCRIPTION
        Queries Microsoft Graph for all dynamic AUs and filters those whose
        membershipRule contains the deprecated MemberOf() operator.
    .PARAMETER IncludeAdmins
        Retrieve scoped role member counts for each affected AU.
    .EXAMPLE
        Get-EMOSAffectedAdminUnits
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [switch]$IncludeAdmins
    )

    Write-Progress -Activity "EMOS Scan" -Status "Scanning Administrative Units..." -PercentComplete 40

    # Graph filter: dynamic AUs only
    $allAUs = Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/administrativeUnits?`$filter=membershipType eq 'Dynamic'&`$select=id,displayName,membershipRule,membershipType,description" `
        -OutputType PSObject

    $aus = $allAUs.value
    while ($allAUs.'@odata.nextLink') {
        $allAUs = Invoke-MgGraphRequest -Method GET -Uri $allAUs.'@odata.nextLink' -OutputType PSObject
        $aus += $allAUs.value
    }

    Write-Verbose "Found $($aus.Count) dynamic AUs. Filtering for MemberOf..."

    $affected = $aus | Where-Object { $_.membershipRule -match $script:MEMBEROF_PATTERN }

    foreach ($au in $affected) {
        [PSCustomObject]@{
            ObjectType      = 'DynamicAdminUnit'
            ObjectId        = $au.id
            DisplayName     = $au.displayName
            Description     = $au.description
            MembershipRule  = $au.membershipRule
            RuleComplexity  = Get-EMOSRuleComplexity -Rule $au.membershipRule
            SuggestedAction = Get-EMOSSuggestedAction -Rule $au.membershipRule -ObjectType 'AdminUnit'
            DeadlineDays    = [int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays)
            BlastRadius     = ''
        }
    }

    Write-Progress -Activity "EMOS Scan" -Status "AUs done" -PercentComplete 60
}
