BeforeAll {
    . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"
    . "$root\EMOS\Private\Get-EMOSSuggestedAction.ps1"
    . "$root\EMOS\Private\Invoke-EMOSGraphRequest.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedAdminUnits.ps1"

    $script:MEMBEROF_PATTERN = [regex]'(?i)\b(user|device)\.memberof\b|\bmemberOf\s*\('
    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'

    # Stub so Pester can mock the helper
    function Invoke-MgGraphRequest { throw "stub - must be mocked" }
}

Describe 'Get-EMOSAffectedAdminUnits' {

    Context 'Filtering — only MemberOf AUs returned' {
        BeforeEach {
            $mockAUs = @(
                New-MockAdminUnit -displayName 'MemberOf AU'  -membershipRule 'user.memberof -any (group.objectId -in [''g1''])'
                New-MockAdminUnit -displayName 'Standard AU'  -membershipRule 'user.department -eq "HR"'
                New-MockAdminUnit -displayName 'Mixed AU'     -membershipRule 'user.memberof -any (group.objectId -in [''g2''])'
            )
            $mockResponse = [PSCustomObject]@{
                value              = $mockAUs
                '@odata.nextLink'  = $null
            }
            Mock Invoke-EMOSGraphRequest { return $mockAUs }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns only AUs whose rule contains memberOf' {
            $result = Get-EMOSAffectedAdminUnits
            $result.Count | Should -Be 2
        }

        It 'Excludes AUs with no memberOf rule' {
            $result = Get-EMOSAffectedAdminUnits
            $result.DisplayName | Should -Not -Contain 'Standard AU'
        }
    }

    Context 'Pagination — helper returns all items to scanner' {
        BeforeEach {
            # Pagination is handled by Invoke-EMOSGraphRequest; scanner receives flat array
            $allAUs = @(
                New-MockAdminUnit -displayName 'AU Page 1' -membershipRule 'user.memberof -any (group.objectId -in [''g1''])'
                New-MockAdminUnit -displayName 'AU Page 2' -membershipRule 'user.memberof -any (group.objectId -in [''g2''])'
            )
            Mock Invoke-EMOSGraphRequest { return $allAUs }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Processes all items returned by the helper' {
            $result = Get-EMOSAffectedAdminUnits
            $result.Count | Should -Be 2
        }
    }

    Context 'Output object shape' {
        BeforeEach {
            $au = New-MockAdminUnit -displayName 'Shape Test' -membershipRule 'user.memberof -any (group.objectId -in [''g1''])'
            Mock Invoke-EMOSGraphRequest { return @($au) }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'ObjectType is DynamicAdminUnit' {
            (Get-EMOSAffectedAdminUnits)[0].ObjectType | Should -Be 'DynamicAdminUnit'
        }

        It 'Output has required properties' {
            $obj = (Get-EMOSAffectedAdminUnits)[0]
            foreach ($prop in @('ObjectType','ObjectId','DisplayName','MembershipRule','RuleComplexity','SuggestedAction','DeadlineDays')) {
                $obj.PSObject.Properties.Name | Should -Contain $prop
            }
        }
    }

    Context 'Empty tenant' {
        BeforeEach {
            Mock Invoke-EMOSGraphRequest { return @() }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns empty result' {
            @(Get-EMOSAffectedAdminUnits).Count | Should -Be 0
        }
    }
}



