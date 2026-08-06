function Get-EMOSRuleComplexity {
    <#
    .SYNOPSIS
        Returns a complexity score (Low/Medium/High) for a dynamic membership rule.
    #>
    param([string]$Rule)

    if ([string]::IsNullOrWhiteSpace($Rule)) { return 'Unknown' }

    $operatorCount = ([regex]::Matches($Rule, '-and|-or|-not') | Measure-Object).Count
    $memberOfCount = ([regex]::Matches($Rule, '(?i)\bmemberOf\s*\(') | Measure-Object).Count

    if ($memberOfCount -gt 2 -or $operatorCount -gt 5) { return 'High' }
    if ($memberOfCount -gt 1 -or $operatorCount -gt 2) { return 'Medium' }
    return 'Low'
}
