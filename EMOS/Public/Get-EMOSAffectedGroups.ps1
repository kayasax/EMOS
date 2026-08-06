function Get-EMOSAffectedGroups {
    <#
    .SYNOPSIS
        Finds all dynamic membership groups using the MemberOf rule operator.
    .DESCRIPTION
        Queries Microsoft Graph for all dynamic membership groups and filters
        those whose membershipRule contains the deprecated MemberOf() operator.
    .PARAMETER IncludeOwners
        Retrieve owner details for each affected group.
    .EXAMPLE
        Get-EMOSAffectedGroups
    .EXAMPLE
        Get-EMOSAffectedGroups -IncludeOwners | Export-Csv affected-groups.csv -NoTypeInformation
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [switch]$IncludeOwners
    )

    Write-Progress -Activity "EMOS Scan" -Status "Scanning dynamic groups..." -PercentComplete 10

    $allGroups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" `
        -Property "id,displayName,membershipRule,createdDateTime,renewedDateTime" `
        -All -ConsistencyLevel eventual -CountVariable groupCount

    Write-Verbose "Found $groupCount dynamic groups total. Filtering for MemberOf..."

    $affected = $allGroups | Where-Object { $_.MembershipRule -match $script:MEMBEROF_PATTERN }

    foreach ($group in $affected) {
        $owners = @()
        if ($IncludeOwners) {
            try {
                $owners = (Get-MgGroupOwner -GroupId $group.Id | Select-Object -ExpandProperty AdditionalProperties) |
                    ForEach-Object { $_['userPrincipalName'] ?? $_['displayName'] }
            }
            catch { Write-Warning "Could not retrieve owners for group $($group.DisplayName)" }
        }

        [PSCustomObject]@{
            ObjectType       = 'DynamicGroup'
            ObjectId         = $group.Id
            DisplayName      = $group.DisplayName
            MembershipRule   = $group.MembershipRule
            RuleComplexity   = Get-EMOSRuleComplexity -Rule $group.MembershipRule
            CreatedDateTime  = $group.CreatedDateTime
            Owners           = $owners -join '; '
            SuggestedAction  = Get-EMOSSuggestedAction -Rule $group.MembershipRule -ObjectType 'Group'
            DeadlineDays     = [int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays)
            BlastRadius      = ''   # populated by Invoke-EMOSReport
        }
    }

    Write-Progress -Activity "EMOS Scan" -Status "Groups done" -PercentComplete 33
}
