BeforeAll {
    . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

    # Load all module functions
    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"
    . "$root\EMOS\Private\Get-EMOSSuggestedAction.ps1"
    . "$root\EMOS\Private\Invoke-EMOSGraphRequest.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedGroups.ps1"

    $script:MEMBEROF_PATTERN     = [regex]'(?i)\bmemberOf\s*\('
    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'

    # Stubs so Pester can mock them
    function Invoke-MgGraphRequest { throw "stub - must be mocked" }
}

Describe 'Get-EMOSAffectedGroups' {

    Context 'Filtering — only MemberOf groups are returned' {
        BeforeEach {
            $mockGroups = @(
                New-MockGroup -DisplayName 'MemberOf Group'  -MembershipRule 'memberOf("group-a")'
                New-MockGroup -DisplayName 'Standard Group'  -MembershipRule 'user.department -eq "Sales"'
                New-MockGroup -DisplayName 'Mixed Group'     -MembershipRule 'memberOf("group-b") -and user.city -eq "Paris"'
                New-MockGroup -DisplayName 'Case Insensitive'-MembershipRule 'MEMBEROF("group-c")'
            )

            Mock Invoke-EMOSGraphRequest { return $mockGroups }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns only groups whose rule contains memberOf' {
            $result = Get-EMOSAffectedGroups
            $result.Count | Should -Be 3
        }

        It 'Excludes groups with no memberOf in their rule' {
            $result = Get-EMOSAffectedGroups
            $result.DisplayName | Should -Not -Contain 'Standard Group'
        }

        It 'Is case-insensitive when matching memberOf' {
            $result = Get-EMOSAffectedGroups
            $result.DisplayName | Should -Contain 'Case Insensitive'
        }
    }

    Context 'Output object shape' {
        BeforeEach {
            $mockGroups = @(New-MockGroup -DisplayName 'Shape Test' -MembershipRule 'memberOf("g1")')
            Mock Invoke-EMOSGraphRequest { return $mockGroups }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Output contains required properties' {
            $result = Get-EMOSAffectedGroups
            $obj    = $result[0]

            $obj.PSObject.Properties.Name | Should -Contain 'ObjectType'
            $obj.PSObject.Properties.Name | Should -Contain 'ObjectId'
            $obj.PSObject.Properties.Name | Should -Contain 'DisplayName'
            $obj.PSObject.Properties.Name | Should -Contain 'MembershipRule'
            $obj.PSObject.Properties.Name | Should -Contain 'RuleComplexity'
            $obj.PSObject.Properties.Name | Should -Contain 'SuggestedAction'
            $obj.PSObject.Properties.Name | Should -Contain 'DeadlineDays'
            $obj.PSObject.Properties.Name | Should -Contain 'BlastRadius'
        }

        It 'ObjectType is always DynamicGroup' {
            $result = Get-EMOSAffectedGroups
            $result[0].ObjectType | Should -Be 'DynamicGroup'
        }

        It 'DeadlineDays is a positive integer before the retirement date' {
            $result = Get-EMOSAffectedGroups
            $result[0].DeadlineDays | Should -BeGreaterThan 0
        }

        It 'RuleComplexity is one of Low/Medium/High/Unknown' {
            $result = Get-EMOSAffectedGroups
            $result[0].RuleComplexity | Should -BeIn @('Low','Medium','High','Unknown')
        }
    }

    Context 'Empty tenant — no dynamic groups' {
        BeforeEach {
            Mock Invoke-EMOSGraphRequest { return @() }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns empty result when no dynamic groups exist' {
            $result = Get-EMOSAffectedGroups
            @($result).Count | Should -Be 0
        }
    }

    Context 'Tenant has dynamic groups but none use MemberOf' {
        BeforeEach {
            $noMemberOf = @(
                New-MockGroup -MembershipRule 'user.department -eq "Engineering"'
                New-MockGroup -MembershipRule 'user.jobTitle -contains "Manager"'
            )
            Mock Invoke-EMOSGraphRequest { return $noMemberOf }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns empty result when no groups use MemberOf' {
            $result = Get-EMOSAffectedGroups
            @($result).Count | Should -Be 0
        }
    }

    Context '-IncludeOwners switch' {
        BeforeEach {
            $grp = New-MockGroup -MembershipRule 'memberOf("g1")'
            Mock Invoke-EMOSGraphRequest {
                param($Uri)
                if ($Uri -match '/owners') {
                    return @([PSCustomObject]@{ userPrincipalName = 'owner@contoso.com'; displayName = 'Owner' })
                }
                return @($grp)
            }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Populates Owners field when -IncludeOwners is specified' {
            $result = Get-EMOSAffectedGroups -IncludeOwners
            $result[0].Owners | Should -Be 'owner@contoso.com'
        }

        It 'Owners field is empty string when -IncludeOwners is not specified' {
            $result = Get-EMOSAffectedGroups
            $result[0].Owners | Should -Be ''
        }
    }
}
