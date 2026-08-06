function Connect-EMOS {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with the scopes required by EMOS.
    .DESCRIPTION
        Wraps Connect-MgGraph with the minimum required permission scopes.
        If already connected with sufficient scopes, re-uses the existing session.
    .PARAMETER TenantId
        The Entra tenant ID or domain. Optional if already signed in.
    .PARAMETER ClientId
        App registration client ID for service-principal auth.
    .PARAMETER UseDeviceCode
        Use device code flow (useful in non-interactive environments).
    .EXAMPLE
        Connect-EMOS
    .EXAMPLE
        Connect-EMOS -TenantId "contoso.onmicrosoft.com" -UseDeviceCode
    #>
    [CmdletBinding()]
    param(
        [string]$TenantId,
        [string]$ClientId,
        [switch]$UseDeviceCode
    )

    $requiredScopes = @(
        'Group.Read.All'
        'AdministrativeUnit.Read.All'
        'EntitlementManagement.Read.All'
        'Policy.Read.All'
        'Application.Read.All'   # for blast-radius CA policy correlation
    )

    $connectParams = @{ Scopes = $requiredScopes }
    if ($TenantId)      { $connectParams['TenantId']      = $TenantId }
    if ($ClientId)      { $connectParams['ClientId']      = $ClientId }
    if ($UseDeviceCode) { $connectParams['UseDeviceCode'] = $true }

    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph @connectParams -NoWelcome

    $ctx = Get-MgContext
    Write-Host "Connected as: $($ctx.Account) | Tenant: $($ctx.TenantId)" -ForegroundColor Green
    Write-Host "Days until MemberOf retirement: $((($script:EMOS_RETIREMENT_DATE) - (Get-Date)).Days)" -ForegroundColor Yellow
}
