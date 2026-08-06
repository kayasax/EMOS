function Get-EMOSRuleComplexity {
    <#
    .SYNOPSIS
        Returns a complexity score (Low/Medium/High) for a dynamic membership rule.
    #>
    param([string]$Rule)

    if ([string]::IsNullOrWhiteSpace($Rule)) { return 'Unknown' }

    $operatorCount = ([regex]::Matches($Rule, '-and|-or|-not') | Measure-Object).Count
    $memberOfCount = ([regex]::Matches($Rule, '(?i)\bmemberOf\s*\(') | Measure-Object).Count

    # Weighted complexity: each memberOf clause counts double (harder to replace)
    $score = ($memberOfCount * 2) + $operatorCount

    if ($score -ge 8) { return 'High' }
    if ($score -ge 4) { return 'Medium' }
    return 'Low'
}
