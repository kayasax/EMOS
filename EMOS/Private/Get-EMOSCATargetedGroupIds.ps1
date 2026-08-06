function Get-EMOSCATargetedGroupIds {
    <#
    .SYNOPSIS
        Returns a list of group IDs targeted by any Conditional Access policy.
        Used for blast-radius enrichment.
    #>
    [OutputType([string[]])]
    param()

    $groupIds = [System.Collections.Generic.HashSet[string]]::new()

    try {
        $policies = Invoke-EMOSGraphRequest -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?`$select=id,displayName,conditions"

        foreach ($policy in $policies) {
            $includeGroups = $policy.conditions?.users?.includeGroups
            $excludeGroups = $policy.conditions?.users?.excludeGroups
            foreach ($g in @($includeGroups) + @($excludeGroups)) {
                if ($g) { [void]$groupIds.Add($g) }
            }
        }
    }
    catch {
        Write-Warning "Could not retrieve CA policies for blast-radius analysis: $_"
    }

    return [string[]]$groupIds
}
