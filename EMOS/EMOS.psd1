@{
    RootModule        = 'EMOS.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Loic Michel'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 Loic Michel. MIT License.'
    Description       = 'Entra MemberOf Scanner (EMOS) - Discovers all Entra ID resources using the deprecated MemberOf dynamic rule operator and generates a prioritized remediation report before the November 3, 2026 retirement deadline.'
    PowerShellVersion = '7.0'

    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
    )

    FunctionsToExport = @(
        'Connect-EMOS'
        'Disconnect-EMOS'
        'Get-EMOSAffectedGroups'
        'Get-EMOSAffectedAdminUnits'
        'Get-EMOSAffectedEMPolicies'
        'Invoke-EMOSReport'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Entra', 'MicrosoftGraph', 'DynamicGroups', 'Compliance', 'Security', 'MemberOf')
            LicenseUri   = 'https://github.com/kayasax/EMOS/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/kayasax/EMOS'
            ReleaseNotes = 'Initial release - scan dynamic groups, AUs, and EM policies for MemberOf usage.'
        }
    }
}
