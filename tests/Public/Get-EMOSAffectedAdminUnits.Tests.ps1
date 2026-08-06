BeforeAll {
    . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"
    . "$root\EMOS\Private\Get-EMOSSuggestedAction.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedAdminUnits.ps1"

    $script:MEMBEROF_PATTERN     = [regex]'(?i)\bmemberOf\s*\('
    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'
}

Describe 'Get-EMOSAffectedAdminUnits' {

    Context 'Filtering — only MemberOf AUs returned' {
        BeforeEach {
            $mockAUs = @(
                New-MockAdminUnit -displayName 'MemberOf AU'  -membershipRule 'memberOf("g1")'
                New-MockAdminUnit -displayName 'Standard AU'  -membershipRule 'user.department -eq "HR"'
                New-MockAdminUnit -displayName 'Mixed AU'     -membershipRule 'memberOf("g2") -and user.city -eq "Lyon"'
            )
            $mockResponse = [PSCustomObject]@{
                value              = $mockAUs
                '@odata.nextLink'  = $null
            }
            Mock Invoke-MgGraphRequest { return $mockResponse }
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

    Context 'Pagination — follows nextLink' {
        BeforeEach {
            $page1 = [PSCustomObject]@{
                value             = @(New-MockAdminUnit -displayName 'AU Page 1' -membershipRule 'memberOf("g1")')
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/page2'
            }
            $page2 = [PSCustomObject]@{
                value             = @(New-MockAdminUnit -displayName 'AU Page 2' -membershipRule 'memberOf("g2")')
                '@odata.nextLink' = $null
            }

            $callCount = 0
            Mock Invoke-MgGraphRequest {
                $script:callCount++
                if ($script:callCount -eq 1) { return $page1 } else { return $page2 }
            }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Retrieves AUs from all pages' {
            $result = Get-EMOSAffectedAdminUnits
            $result.Count | Should -Be 2
        }
    }

    Context 'Output object shape' {
        BeforeEach {
            $au = New-MockAdminUnit -displayName 'Shape Test' -membershipRule 'memberOf("g1")'
            Mock Invoke-MgGraphRequest { [PSCustomObject]@{ value = @($au); '@odata.nextLink' = $null } }
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
            Mock Invoke-MgGraphRequest { [PSCustomObject]@{ value = @(); '@odata.nextLink' = $null } }
            Mock Write-Progress { }
            Mock Write-Verbose  { }
        }

        It 'Returns empty result' {
            @(Get-EMOSAffectedAdminUnits).Count | Should -Be 0
        }
    }
}
