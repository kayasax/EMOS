BeforeAll {
    $privatePath = "$PSScriptRoot\..\..\EMOS\Private"
    . "$privatePath\Get-EMOSSuggestedAction.ps1"
}

Describe 'Get-EMOSSuggestedAction' {

    Context 'Always returns a non-empty string' {
        It 'Returns non-empty for Group' {
            Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'Group' | Should -Not -BeNullOrEmpty
        }
        It 'Returns non-empty for AdminUnit' {
            Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'AdminUnit' | Should -Not -BeNullOrEmpty
        }
        It 'Returns non-empty for EMPolicy' {
            Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'EMPolicy' | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Group and AdminUnit share the same suggestion' {
        It 'Group and AdminUnit return the same text' {
            $g  = Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'Group'
            $au = Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'AdminUnit'
            $g | Should -Be $au
        }

        It 'Suggestion is the same regardless of memberOf count' {
            $single   = Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'Group'
            $multiple = Get-EMOSSuggestedAction -Rule 'memberOf("g1") -and memberOf("g2")' -ObjectType 'Group'
            $single | Should -Be $multiple
        }
    }

    Context 'EMPolicy has a distinct suggestion' {
        It 'EMPolicy suggestion differs from Group suggestion' {
            $g  = Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'Group'
            $em = Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'EMPolicy'
            $em | Should -Not -Be $g
        }
    }
}
