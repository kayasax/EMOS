function Connect-EMOS {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with the scopes required by EMOS.
    .DESCRIPTION
        Establishes a Microsoft Graph session using one of several auth flows.
        If a session already exists with sufficient scopes, it is reused.

        Supported auth flows:
          - Interactive    : browser pop-up (default for human admins)
          - DeviceCode     : for non-interactive / SSH terminals
          - Certificate    : app-only via thumbprint or path (for CI/CD pipelines)
          - ClientSecret   : app-only via secret (less secure; prefer certificate)
          - ManagedIdentity: system- or user-assigned Azure managed identity

    .PARAMETER TenantId
        Entra tenant ID or domain. Required for app-only flows.
    .PARAMETER ClientId
        App registration client ID. Required for app-only flows.
    .PARAMETER CertificateThumbprint
        Certificate thumbprint in the local machine/user store. App-only.
    .PARAMETER CertificatePath
        Path to a PFX certificate file. App-only.
    .PARAMETER ClientSecret
        App registration client secret (SecureString). App-only.
    .PARAMETER ManagedIdentity
        Connect using the Azure managed identity of the current host.
    .PARAMETER UseDeviceCode
        Use device-code flow instead of interactive browser.
    .PARAMETER Force
        Re-authenticate even if a valid session already exists.
    .EXAMPLE
        # Interactive (human admin, most common)
        Connect-EMOS

    .EXAMPLE
        # Device code (SSH / headless terminal)
        Connect-EMOS -TenantId "contoso.onmicrosoft.com" -UseDeviceCode

    .EXAMPLE
        # App-only with certificate (CI/CD recommended)
        Connect-EMOS -TenantId "contoso.onmicrosoft.com" -ClientId "abc..." -CertificateThumbprint "DEF123..."

    .EXAMPLE
        # App-only with client secret
        $secret = Read-Host "Client secret" -AsSecureString
        Connect-EMOS -TenantId "contoso.onmicrosoft.com" -ClientId "abc..." -ClientSecret $secret

    .EXAMPLE
        # Azure managed identity (Azure Automation, GitHub Actions with OIDC)
        Connect-EMOS -ManagedIdentity
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        # --- App-only shared params ---
        [Parameter(ParameterSetName = 'Certificate',     Mandatory)]
        [Parameter(ParameterSetName = 'CertificatePath', Mandatory)]
        [Parameter(ParameterSetName = 'ClientSecret',    Mandatory)]
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'DeviceCode')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'Certificate',     Mandatory)]
        [Parameter(ParameterSetName = 'CertificatePath', Mandatory)]
        [Parameter(ParameterSetName = 'ClientSecret',    Mandatory)]
        [string]$ClientId,

        # --- Auth flow params ---
        [Parameter(ParameterSetName = 'Certificate',     Mandatory)]
        [string]$CertificateThumbprint,

        [Parameter(ParameterSetName = 'CertificatePath', Mandatory)]
        [string]$CertificatePath,

        [Parameter(ParameterSetName = 'ClientSecret',    Mandatory)]
        [System.Security.SecureString]$ClientSecret,

        [Parameter(ParameterSetName = 'ManagedIdentity', Mandatory)]
        [switch]$ManagedIdentity,

        [Parameter(ParameterSetName = 'DeviceCode',      Mandatory)]
        [switch]$UseDeviceCode,

        [switch]$Force
    )

    $requiredScopes = @(
        'Group.Read.All'
        'AdministrativeUnit.Read.All'
        'EntitlementManagement.Read.All'
        'Policy.Read.All'
        'Application.Read.All'
    )

    # Reuse existing session if scopes are sufficient and -Force not set
    if (-not $Force) {
        $ctx = Get-MgContext -ErrorAction SilentlyContinue
        if ($ctx) {
            $missing = $requiredScopes | Where-Object { $_ -notin $ctx.Scopes }
            if (-not $missing) {
                Write-Host "Reusing existing Graph session: $($ctx.Account ?? $ctx.AppName) | Tenant: $($ctx.TenantId)" -ForegroundColor Green
                Write-Host "Days until MemberOf retirement: $([int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays))" -ForegroundColor Yellow
                return
            }
            Write-Verbose "Existing session missing scopes: $($missing -join ', '). Reconnecting..."
        }
    }

    Write-Host "Connecting to Microsoft Graph ($($PSCmdlet.ParameterSetName) flow)..." -ForegroundColor Cyan

    $connectParams = @{}
    if ($TenantId) { $connectParams['TenantId'] = $TenantId }

    switch ($PSCmdlet.ParameterSetName) {

        'Interactive' {
            $connectParams['Scopes'] = $requiredScopes
        }

        'DeviceCode' {
            $connectParams['Scopes']        = $requiredScopes
            $connectParams['UseDeviceCode'] = $true
        }

        'Certificate' {
            $connectParams['ClientId']              = $ClientId
            $connectParams['CertificateThumbprint'] = $CertificateThumbprint
            # App-only: no delegated scopes
        }

        'CertificatePath' {
            if (-not (Test-Path $CertificatePath)) {
                throw "Certificate file not found: $CertificatePath"
            }
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
            $connectParams['ClientId']    = $ClientId
            $connectParams['Certificate'] = $cert
        }

        'ClientSecret' {
            $connectParams['ClientId']              = $ClientId
            $connectParams['ClientSecretCredential'] = [System.Net.NetworkCredential]::new('', $ClientSecret)
        }

        'ManagedIdentity' {
            $connectParams['Identity'] = $true
        }
    }

    Connect-MgGraph @connectParams -NoWelcome

    $ctx = Get-MgContext
    $identity = $ctx.Account ?? $ctx.AppName ?? "Managed Identity"
    Write-Host "Connected as: $identity | Tenant: $($ctx.TenantId)" -ForegroundColor Green
    Write-Host "Days until MemberOf retirement: $([int](($script:EMOS_RETIREMENT_DATE - (Get-Date)).TotalDays))" -ForegroundColor Yellow
}

function Disconnect-EMOS {
    <#
    .SYNOPSIS
        Disconnects the current Microsoft Graph session.
    #>
    [CmdletBinding()]
    param()
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
}

