function Get-EMOSRuleComplexity {
    <#
    .SYNOPSIS
        Returns a complexity score (Low/Medium/High) for a MemberOf dynamic rule.
    .NOTES
        Real Entra ID syntax: user.memberof -any (group.objectId -in ['id1', 'id2', ...])
        Complexity = number of group IDs listed — each is one group whose membership
        must be replicated or replaced.
    #>
    param([string]$Rule)

    if ([string]::IsNullOrWhiteSpace($Rule)) { return 'Unknown' }

    # Count group IDs in the -in ['id1', 'id2', ...] list
    # Matches anything in single quotes inside the brackets
    $groupIdCount = ([regex]::Matches($Rule, "'[^']+'" ) | Measure-Object).Count

    # Fallback: count legacy memberOf("id") call style
    if ($groupIdCount -eq 0) {
        $groupIdCount = ([regex]::Matches($Rule, '(?i)\bmemberOf\s*\(') | Measure-Object).Count
    }

    if ($groupIdCount -ge 3) { return 'High' }
    if ($groupIdCount -eq 2) { return 'Medium' }
    return 'Low'
}
