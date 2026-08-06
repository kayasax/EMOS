BeforeAll {
    . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"
    . "$root\EMOS\Private\Get-EMOSSuggestedAction.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedEMPolicies.ps1"

    $script:MEMBEROF_PATTERN     = [regex]'(?i)\bmemberOf\s*\('
    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'
}

Describe 'Get-EMOSAffectedEMPolicies' {

    Context 'Filtering — only MemberOf policies returned' {
        BeforeEach {
            $policies = @(
                New-MockEMPolicy -DisplayName 'MemberOf Policy' -RuleJson '"memberOf(\"g1\")"'
                New-MockEMPolicy -DisplayName 'No MemberOf'     -RuleJson '"user.department -eq \"HR\""'
                New-MockEMPolicy -DisplayName 'Mixed Policy'    -RuleJson '"memberOf(\"g2\") -and user.city -eq \"Paris\""'
            )
            $mockResponse = [PSCustomObject]@{ value = $policies; '@odata.nextLink' = $null }
            Mock Invoke-MgGraphRequest { return $mockResponse }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns only policies containing memberOf' {
            $result = Get-EMOSAffectedEMPolicies
            $result.Count | Should -Be 2
        }

        It 'Excludes policies with no memberOf expression' {
            $result = Get-EMOSAffectedEMPolicies
            $result.DisplayName | Should -Not -Contain 'No MemberOf'
        }
    }

    Context 'Policies with no automaticRequestSettings are skipped' {
        BeforeEach {
            $noAutoSettings = [PSCustomObject]@{
                id                       = [guid]::NewGuid().ToString()
                displayName              = 'Manual Policy'
                description              = ''
                automaticRequestSettings = $null
                accessPackage            = @{ id = 'pkg1'; displayName = 'Pkg' }
            }
            Mock Invoke-MgGraphRequest { [PSCustomObject]@{ value = @($noAutoSettings); '@odata.nextLink' = $null } }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Skips policies with null automaticRequestSettings' {
            @(Get-EMOSAffectedEMPolicies).Count | Should -Be 0
        }
    }

    Context 'Output object shape' {
        BeforeEach {
            $policy = New-MockEMPolicy -DisplayName 'Shape Test' -RuleJson '"memberOf(\"g1\")"' -PackageName 'Access Pkg A'
            Mock Invoke-MgGraphRequest { [PSCustomObject]@{ value = @($policy); '@odata.nextLink' = $null } }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'ObjectType is EMAutoAssignPolicy' {
            (Get-EMOSAffectedEMPolicies)[0].ObjectType | Should -Be 'EMAutoAssignPolicy'
        }

        It 'AccessPackageName is populated' {
            (Get-EMOSAffectedEMPolicies)[0].AccessPackageName | Should -Be 'Access Pkg A'
        }

        It 'BlastRadius is pre-populated as Entitlement Management' {
            (Get-EMOSAffectedEMPolicies)[0].BlastRadius | Should -Be 'Entitlement Management'
        }

        It 'Output has required properties' {
            $obj = (Get-EMOSAffectedEMPolicies)[0]
            foreach ($prop in @('ObjectType','ObjectId','DisplayName','AccessPackageName','MembershipRule','RuleComplexity','SuggestedAction','DeadlineDays','BlastRadius')) {
                $obj.PSObject.Properties.Name | Should -Contain $prop
            }
        }
    }
}
