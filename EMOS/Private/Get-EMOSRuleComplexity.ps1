function Get-EMOSRuleComplexity {
    <#
    .SYNOPSIS
        Returns a complexity score (Low/Medium/High) for a MemberOf dynamic rule.
    .NOTES
        MemberOf cannot be combined with other attribute rules (user.*, device.*).
        Complexity is therefore determined solely by the number of memberOf() calls
        — each represents one group whose membership must be replicated or replaced.
    #>
    param([string]$Rule)

    if ([string]::IsNullOrWhiteSpace($Rule)) { return 'Unknown' }

    $memberOfCount = ([regex]::Matches($Rule, '(?i)\bmemberOf\s*\(') | Measure-Object).Count

    if ($memberOfCount -ge 3) { return 'High' }
    if ($memberOfCount -eq 2) { return 'Medium' }
    return 'Low'
}
