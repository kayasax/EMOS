BeforeAll {
    $privatePath = "$PSScriptRoot\..\..\EMOS\Private"
    . "$privatePath\Get-EMOSSuggestedAction.ps1"
}

Describe 'Get-EMOSSuggestedAction' {

    Context 'Group object type' {
        It 'Suggests Replace-Rule or Convert-to-Assigned when only memberOf is present' {
            $result = Get-EMOSSuggestedAction -Rule 'memberOf("group1")' -ObjectType 'Group'
            $result | Should -Be 'Replace-Rule or Convert-to-Assigned'
        }

        It 'Suggests replacing memberOf clause when mixed with user attributes' {
            $result = Get-EMOSSuggestedAction -Rule 'memberOf("g1") -and user.department -eq "Sales"' -ObjectType 'Group'
            $result | Should -Be 'Replace memberOf clause with supported operator'
        }

        It 'Returns generic review message for unrecognised mixed rule' {
            $result = Get-EMOSSuggestedAction -Rule 'memberOf("g1") -and device.something -eq "x"' -ObjectType 'Group'
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'AdminUnit object type' {
        It 'Suggests Replace-Rule or Convert-to-Assigned when only memberOf is present' {
            $result = Get-EMOSSuggestedAction -Rule 'memberOf("au1")' -ObjectType 'AdminUnit'
            $result | Should -Be 'Replace-Rule or Convert-to-Assigned'
        }

        It 'Suggests replacing clause when mixed with user attributes' {
            $result = Get-EMOSSuggestedAction -Rule 'memberOf("au1") -and user.city -eq "Paris"' -ObjectType 'AdminUnit'
            $result | Should -Be 'Replace memberOf clause with supported operator'
        }
    }

    Context 'EMPolicy object type' {
        It 'Always suggests alternative assignment method' {
            $result = Get-EMOSSuggestedAction -Rule 'memberOf("g1")' -ObjectType 'EMPolicy'
            $result | Should -Be 'Replace MemberOf with alternative assignment method'
        }

        It 'Returns same suggestion regardless of rule complexity' {
            $rule   = 'memberOf("g1") -and memberOf("g2") -and user.department -eq "HR"'
            $result = Get-EMOSSuggestedAction -Rule $rule -ObjectType 'EMPolicy'
            $result | Should -Be 'Replace MemberOf with alternative assignment method'
        }
    }

    Context 'Output is never null or empty' {
        It 'Always returns a non-empty string for any valid input' {
            foreach ($type in @('Group','AdminUnit','EMPolicy')) {
                $result = Get-EMOSSuggestedAction -Rule 'memberOf("x")' -ObjectType $type
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}
