BeforeAll {
    . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"
    . "$root\EMOS\Private\Get-EMOSSuggestedAction.ps1"
    . "$root\EMOS\Private\Invoke-EMOSGraphRequest.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedEMPolicies.ps1"

    $script:MEMBEROF_PATTERN = [regex]'(?i)\b(user|device)\.memberof\b|\bmemberOf\s*\('
    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'

    function Invoke-MgGraphRequest { throw "stub - must be mocked" }
}

Describe 'Get-EMOSAffectedEMPolicies' {

    Context 'Filtering — only MemberOf policies returned' {
        BeforeEach {
            $policies = @(
                New-MockEMPolicy -DisplayName 'MemberOf Policy' -MembershipRule "user.memberof -any (group.objectId -in ['g1'])"
                New-MockEMPolicy -DisplayName 'No MemberOf'     -MembershipRule 'user.department -eq "HR"'
                New-MockEMPolicy -DisplayName 'Mixed Policy'    -MembershipRule "user.memberof -any (group.objectId -in ['g2'])"
            )
            Mock Invoke-EMOSGraphRequest { return $policies }
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

    Context 'Policies with no attributeRuleMembers are skipped' {
        BeforeEach {
            $noMemberOfPolicy = [PSCustomObject]@{
                id                     = [guid]::NewGuid().ToString()
                displayName            = 'Manual Policy'
                description            = ''
                allowedTargetScope     = 'allMemberUsers'
                specificAllowedTargets = @()   # no attributeRuleMembers
                automaticRequestSettings = [PSCustomObject]@{ requestAccessForAllowedTargets = $true }
                accessPackage          = [PSCustomObject]@{ id = 'pkg1'; displayName = 'Pkg' }
            }
            Mock Invoke-EMOSGraphRequest { return @($noMemberOfPolicy) }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Skips policies with no attributeRuleMembers' {
            @(Get-EMOSAffectedEMPolicies).Count | Should -Be 0
        }
    }

    Context 'Output object shape' {
        BeforeEach {
            $policy = New-MockEMPolicy -DisplayName 'Shape Test' -RuleJson '"user.memberof -any (group.objectId -in ['g1'])"' -PackageName 'Access Pkg A'
            Mock Invoke-EMOSGraphRequest { return @($policy) }
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




