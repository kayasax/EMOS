BeforeAll {
    # Load module private functions directly for unit testing
    $privatePath = "$PSScriptRoot\..\..\EMOS\Private"
    . "$privatePath\Get-EMOSRuleComplexity.ps1"

    # The module sets this constant; replicate it for isolated tests
    $script:MEMBEROF_PATTERN = [regex]'(?i)\bmemberOf\s*\('
}

Describe 'Get-EMOSRuleComplexity' {

    Context 'Null and empty input' {
        It 'Returns Unknown for null rule' {
            Get-EMOSRuleComplexity -Rule $null | Should -Be 'Unknown'
        }

        It 'Returns Unknown for empty string' {
            Get-EMOSRuleComplexity -Rule '' | Should -Be 'Unknown'
        }

        It 'Returns Unknown for whitespace-only string' {
            Get-EMOSRuleComplexity -Rule '   ' | Should -Be 'Unknown'
        }
    }

    Context 'Low complexity rules' {
        It 'Returns Low for a single memberOf with no boolean operators' {
            $rule = 'user.memberOf -any (group.objectId -in ["abc"])'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'Low'
        }

        It 'Returns Low for a rule with one operator and one memberOf' {
            $rule = 'memberOf("group1") -and user.department -eq "Sales"'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'Low'
        }

        It 'Returns Low for a simple rule with no memberOf at all' {
            $rule = 'user.department -eq "Finance"'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'Low'
        }
    }

    Context 'Medium complexity rules' {
        It 'Returns Medium for two memberOf operators' {
            $rule = 'memberOf("g1") -and memberOf("g2")'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'Medium'
        }

        It 'Returns Medium for one memberOf with 3 boolean operators' {
            $rule = 'memberOf("g1") -and user.a -eq "x" -and user.b -eq "y" -or user.c -eq "z"'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'Medium'
        }
    }

    Context 'High complexity rules' {
        It 'Returns High for three or more memberOf operators' {
            $rule = 'memberOf("g1") -and memberOf("g2") -and memberOf("g3")'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'High'
        }

        It 'Returns High for two memberOf with many boolean operators' {
            $rule = 'memberOf("g1") -and memberOf("g2") -and a -eq "x" -and b -eq "y" -or c -eq "z" -and d -eq "w"'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'High'
        }

        It 'Is case-insensitive for MemberOf casing' {
            $rule = 'MEMBEROF("g1") -and MemberOf("g2") -and memberOf("g3")'
            Get-EMOSRuleComplexity -Rule $rule | Should -Be 'High'
        }
    }
}
