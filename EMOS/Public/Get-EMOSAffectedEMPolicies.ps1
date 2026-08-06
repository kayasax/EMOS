function Get-EMOSAffectedEMPolicies {
    <#
    .SYNOPSIS
        Finds Entitlement Management auto-assignment policies using MemberOf.
    .DESCRIPTION
        Queries Microsoft Graph Entitlement Management for auto-assignment policies
        whose filter expression contains the deprecated MemberOf() operator.
    .EXAMPLE
        Get-EMOSAffectedEMPolicies
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-Progress -Activity "EMOS Scan" -Status "Scanning Entitlement Management policies..." -PercentComplete 65

    $policies = Invoke-EMOSGraphRequest -Uri "https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies?`$expand=accessPackage&`$select=id,displayName,description,allowedTargetScope,specificAllowedTargets,automaticRequestSettings,accessPackage"

    Write-Verbose "Found $($policies.Count) assignment policies. Filtering for auto-assign with MemberOf..."

    foreach ($policy in $policies) {
        # MemberOf rule lives in specificAllowedTargets[].membershipRule
        # where @odata.type is #microsoft.graph.attributeRuleMembers
        $memberOfTargets = @($policy.specificAllowedTargets | Where-Object {
            $_.'@odata.type' -eq '#microsoft.graph.attributeRuleMembers' -and
            $_.membershipRule -match $script:MEMBEROF_PATTERN
        })

        if ($memberOfTargets.Count -eq 0) { continue }

        $ruleText = ($memberOfTargets | ForEach-Object { $_.membershipRule }) -join ' | '

        [PSCustomObject]@{
            ObjectType        = 'EMAutoAssignPolicy'
            ObjectId          = $policy.id
            DisplayName       = $policy.displayName
            Description       = $policy.description
            AccessPackageId   = $policy.accessPackage.id
            AccessPackageName = $policy.accessPackage.displayName
            MembershipRule    = $ruleText
            RuleComplexity    = Get-EMOSRuleComplexity -Rule $ruleText
            SuggestedAction   = Get-EMOSSuggestedAction -Rule $ruleText -ObjectType 'EMPolicy'
            DeadlineDays      = [int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays)
            BlastRadius       = 'Entitlement Management'
        }
    }

    Write-Progress -Activity "EMOS Scan" -Status "EM policies done" -PercentComplete 80
}
