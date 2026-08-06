function Invoke-EMOSReport {
    <#
    .SYNOPSIS
        Runs the full EMOS scan and generates a remediation report.
    .DESCRIPTION
        Aggregates results from all three scanners (groups, AUs, EM policies),
        enriches with blast-radius data, and exports HTML + CSV + JSON reports.
    .PARAMETER OutputPath
        Directory where report files are saved. Defaults to an EMOS-Reports folder
        in the user's home directory ($HOME/EMOS-Reports).
    .PARAMETER IncludeOwners
        Retrieve owner/admin details (slower but richer output).
    .PARAMETER PassThru
        Return the findings array to the pipeline (default: suppressed to keep console clean).
    .PARAMETER NoHtml
        Skip HTML report generation.
    .PARAMETER Show
        Automatically open the HTML report in the default browser after generation.
    .EXAMPLE
        Invoke-EMOSReport
    .EXAMPLE
        Invoke-EMOSReport -IncludeOwners -Show
    .EXAMPLE
        $findings = Invoke-EMOSReport -PassThru
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = (Join-Path $HOME 'EMOS-Reports'),
        [switch]$IncludeOwners,
        [switch]$NoHtml,
        [switch]$Show,
        [switch]$PassThru
    )

    $timestamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
    $deadlineDays = [int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays)

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    Write-Host "`nEMOS - Entra MemberOf Scanner" -ForegroundColor Cyan
    Write-Host "Retirement deadline: $($script:EMOS_RETIREMENT_DATE.ToString('yyyy-MM-dd')) ($deadlineDays days remaining)" -ForegroundColor $(if ($deadlineDays -lt 30) { 'Red' } elseif ($deadlineDays -lt 90) { 'Yellow' } else { 'Green' })
    Write-Host ("-" * 60)

    # Run all three scanners
    $groups     = Get-EMOSAffectedGroups -IncludeOwners:$IncludeOwners
    $aus        = Get-EMOSAffectedAdminUnits
    $emPolicies = Get-EMOSAffectedEMPolicies

    # Blast-radius enrichment for groups
    $caGroupIds = Get-EMOSCATargetedGroupIds
    foreach ($g in $groups) {
        $tags = @()
        if ($caGroupIds -contains $g.ObjectId) { $tags += 'ConditionalAccess' }
        if ($g.HasLicenses) { $tags += 'Licensing' }
        $g.BlastRadius = $tags -join ', '
    }

    $allFindings = @($groups) + @($aus) + @($emPolicies)

    # Summary
    Write-Host "`nScan complete:" -ForegroundColor Cyan
    Write-Host "  Dynamic groups with MemberOf : $($groups.Count)"     -ForegroundColor $(if ($groups.Count)     { 'Red' } else { 'Green' })
    Write-Host "  Dynamic AUs with MemberOf    : $($aus.Count)"        -ForegroundColor $(if ($aus.Count)        { 'Red' } else { 'Green' })
    Write-Host "  EM policies with MemberOf    : $($emPolicies.Count)" -ForegroundColor $(if ($emPolicies.Count) { 'Red' } else { 'Green' })
    Write-Host "  TOTAL                        : $($allFindings.Count)"

    if ($allFindings.Count -eq 0) {
        Write-Host "`nNo MemberOf usage found. Tenant is compliant." -ForegroundColor Green
        return
    }

    # Export files
    $csvPath  = Join-Path $OutputPath "EMOS-Report-$timestamp.csv"
    $jsonPath = Join-Path $OutputPath "EMOS-Report-$timestamp.json"
    $htmlPath = Join-Path $OutputPath "EMOS-Report-$timestamp.html"

    $allFindings | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    $allFindings | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8

    if (-not $NoHtml) {
        Export-EMOSHtmlReport -Findings $allFindings -OutputPath $htmlPath -DeadlineDays $deadlineDays
    }

    # Print paths at the end, after the findings scroll
    Write-Host "`n--- Reports ---" -ForegroundColor Cyan
    Write-Host "CSV  : $csvPath"  -ForegroundColor Green
    Write-Host "JSON : $jsonPath" -ForegroundColor Green
    if (-not $NoHtml) {
        Write-Host "HTML : $htmlPath" -ForegroundColor Green
        if ($Show) { Start-Process $htmlPath }
    }

    if ($PassThru) { return $allFindings }
}
