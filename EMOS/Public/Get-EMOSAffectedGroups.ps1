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

    # ConsistencyLevel: eventual required for groupTypes/any() filter
    $allGroups = Invoke-EMOSGraphRequest `
        -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=groupTypes/any(c:c eq 'DynamicMembership')&`$select=id,displayName,membershipRule,createdDateTime&`$count=true" `
        -Headers @{ ConsistencyLevel = 'eventual' }

    Write-Verbose "Found $($allGroups.Count) dynamic groups. Filtering for MemberOf..."

    $affected = $allGroups | Where-Object { $_.membershipRule -match $script:MEMBEROF_PATTERN }

    foreach ($group in $affected) {
        $owners = @()
        if ($IncludeOwners) {
            try {
                $ownerItems = Invoke-EMOSGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)/owners?`$select=userPrincipalName,displayName"
                $owners = $ownerItems | ForEach-Object { $_.userPrincipalName ?? $_.displayName }
            }
            catch { Write-Warning "Could not retrieve owners for group $($group.displayName)" }
        }

        $hasLicenses = $false
        try {
            $licenses = Invoke-EMOSGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)/assignedLicenses"
            $hasLicenses = @($licenses).Count -gt 0
        }
        catch { }

        [PSCustomObject]@{
            ObjectType       = 'DynamicGroup'
            ObjectId         = $group.id
            DisplayName      = $group.displayName
            MembershipRule   = $group.membershipRule
            RuleComplexity   = Get-EMOSRuleComplexity -Rule $group.membershipRule
            CreatedDateTime  = $group.createdDateTime
            Owners           = $owners -join '; '
            HasLicenses      = $hasLicenses
            SuggestedAction  = Get-EMOSSuggestedAction -Rule $group.membershipRule -ObjectType 'Group'
            DeadlineDays     = [int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays)
            BlastRadius      = ''   # populated by Invoke-EMOSReport
        }
    }

    Write-Progress -Activity "EMOS Scan" -Status "Groups done" -PercentComplete 33
}
