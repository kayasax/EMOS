BeforeAll {
    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"

    $script:MEMBEROF_PATTERN = [regex]'(?i)\b(user|device)\.memberof\b|\bmemberOf\s*\('
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

    Context 'Real Entra syntax: user.memberof -any (group.objectId -in [...])' {
        It 'Returns Low for one group ID' {
            Get-EMOSRuleComplexity -Rule "user.memberof -any (group.objectId -in ['2409120030000681'])" |
                Should -Be 'Low'
        }

        It 'Returns Medium for two group IDs' {
            Get-EMOSRuleComplexity -Rule "user.memberof -any (group.objectId -in ['2409120030000681', '2409120030000682'])" |
                Should -Be 'Medium'
        }

        It 'Returns High for three group IDs' {
            Get-EMOSRuleComplexity -Rule "user.memberof -any (group.objectId -in ['id1', 'id2', 'id3'])" |
                Should -Be 'High'
        }

        It 'Works for device.memberof syntax' {
            Get-EMOSRuleComplexity -Rule "device.memberof -any (group.objectId -in ['id1', 'id2'])" |
                Should -Be 'Medium'
        }

        It 'Is case-insensitive' {
            Get-EMOSRuleComplexity -Rule "user.MemberOf -any (group.objectId -in ['id1'])" |
                Should -Be 'Low'
        }
    }

    Context 'Legacy docs syntax: memberOf("id")' {
        It 'Returns Low for single legacy call' {
            Get-EMOSRuleComplexity -Rule 'memberOf("group-a")' | Should -Be 'Low'
        }
    }
}
