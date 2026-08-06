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

    Context 'Low complexity — single memberOf' {
        It 'Returns Low for a single memberOf call' {
            Get-EMOSRuleComplexity -Rule 'memberOf("group-a")' | Should -Be 'Low'
        }

        It 'Is case-insensitive' {
            Get-EMOSRuleComplexity -Rule 'MEMBEROF("group-a")' | Should -Be 'Low'
        }
    }

    Context 'Medium complexity — two memberOf calls' {
        It 'Returns Medium for two memberOf operators' {
            Get-EMOSRuleComplexity -Rule 'memberOf("g1") -and memberOf("g2")' | Should -Be 'Medium'
        }
    }

    Context 'High complexity — three or more memberOf calls' {
        It 'Returns High for three memberOf operators' {
            Get-EMOSRuleComplexity -Rule 'memberOf("g1") -and memberOf("g2") -and memberOf("g3")' | Should -Be 'High'
        }

        It 'Returns High for four memberOf operators' {
            Get-EMOSRuleComplexity -Rule 'memberOf("g1") -and memberOf("g2") -and memberOf("g3") -and memberOf("g4")' | Should -Be 'High'
        }

        It 'Is case-insensitive for all MemberOf variants' {
            Get-EMOSRuleComplexity -Rule 'MEMBEROF("g1") -and MemberOf("g2") -and memberOf("g3")' | Should -Be 'High'
        }
    }
}
