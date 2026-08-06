BeforeAll {
    . "$PSScriptRoot\..\Helpers\GraphMocks.ps1"

    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Get-EMOSRuleComplexity.ps1"
    . "$root\EMOS\Private\Get-EMOSSuggestedAction.ps1"
    . "$root\EMOS\Private\Get-EMOSCATargetedGroupIds.ps1"
    . "$root\EMOS\Private\Export-EMOSHtmlReport.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedGroups.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedAdminUnits.ps1"
    . "$root\EMOS\Public\Get-EMOSAffectedEMPolicies.ps1"
    . "$root\EMOS\Public\Invoke-EMOSReport.ps1"

    $script:MEMBEROF_PATTERN = [regex]'(?i)\b(user|device)\.memberof\b|\bmemberOf\s*\('
    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'

    $script:TempOutput = Join-Path $env:TEMP "EMOS-Test-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempOutput -Force | Out-Null
}

AfterAll {
    Remove-Item $script:TempOutput -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-EMOSReport' {

    Context 'Clean tenant — no MemberOf usage' {
        BeforeEach {
            Mock Get-EMOSAffectedGroups    { return @() }
            Mock Get-EMOSAffectedAdminUnits{ return @() }
            Mock Get-EMOSAffectedEMPolicies{ return @() }
            Mock Get-EMOSCATargetedGroupIds{ return @() }
        }

        It 'Returns nothing (or empty) when no findings exist' {
            $result = Invoke-EMOSReport -OutputPath $script:TempOutput
            @($result).Count | Should -Be 0
        }

        It 'Creates output directory if it does not exist' {
            $newDir = Join-Path $script:TempOutput 'subdir-that-does-not-exist'
            Invoke-EMOSReport -OutputPath $newDir -NoHtml
            Test-Path $newDir | Should -Be $true
        }
    }

    Context 'Tenant with findings' {
        BeforeEach {
            # Clean any leftover reports from previous It block
            Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*' | Remove-Item -Force -ErrorAction SilentlyContinue
            $fakeGroup = [PSCustomObject]@{
                ObjectType     = 'DynamicGroup'; ObjectId = 'g1'; DisplayName = 'MemberOf Group'
                MembershipRule = 'memberOf("g1")'; RuleComplexity = 'Low'; Owners = ''
                SuggestedAction= 'Replace-Rule or Convert-to-Assigned'; DeadlineDays = 89; BlastRadius = ''
            }
            $fakeAU = [PSCustomObject]@{
                ObjectType     = 'DynamicAdminUnit'; ObjectId = 'au1'; DisplayName = 'MemberOf AU'
                MembershipRule = 'memberOf("au1")'; RuleComplexity = 'Low'; Description = ''
                SuggestedAction= 'Replace-Rule or Convert-to-Assigned'; DeadlineDays = 89; BlastRadius = ''
            }

            Mock Get-EMOSAffectedGroups    { return @($fakeGroup) }
            Mock Get-EMOSAffectedAdminUnits{ return @($fakeAU) }
            Mock Get-EMOSAffectedEMPolicies{ return @() }
            Mock Get-EMOSCATargetedGroupIds{ return @() }
            Mock Write-Host { }
        }

        It 'Returns all findings as a flat array' {
            $result = Invoke-EMOSReport -OutputPath $script:TempOutput
            @($result).Count | Should -Be 2
        }

        It 'Creates a CSV file' {
            Invoke-EMOSReport -OutputPath $script:TempOutput
            $csv = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.csv'
            $csv.Count | Should -Be 1
        }

        It 'Creates a JSON file' {
            Invoke-EMOSReport -OutputPath $script:TempOutput
            $json = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.json'
            $json.Count | Should -Be 1
        }

        It 'Creates an HTML file' {
            Invoke-EMOSReport -OutputPath $script:TempOutput
            $html = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.html'
            $html.Count | Should -Be 1
        }

        It 'Does not create HTML file when -NoHtml is specified' {
            Invoke-EMOSReport -OutputPath $script:TempOutput -NoHtml
            $html = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.html'
            $html.Count | Should -Be 0
        }

        It 'CSV contains the correct number of rows' {
            Invoke-EMOSReport -OutputPath $script:TempOutput
            $csv  = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.csv' | Select-Object -Last 1
            $rows = Import-Csv $csv.FullName
            $rows.Count | Should -Be 2
        }

        It 'JSON is valid and parses to an array' {
            Invoke-EMOSReport -OutputPath $script:TempOutput
            $json = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.json' | Select-Object -Last 1
            $parsed = Get-Content $json.FullName | ConvertFrom-Json
            @($parsed).Count | Should -Be 2
        }

        It 'HTML file is not empty and contains EMOS branding' {
            Invoke-EMOSReport -OutputPath $script:TempOutput
            $html    = Get-ChildItem $script:TempOutput -Filter 'EMOS-Report-*.html' | Select-Object -Last 1
            $content = Get-Content $html.FullName -Raw
            $content | Should -Match 'EMOS'
        }
    }

    Context 'Blast-radius tagging' {
        BeforeEach {
            $groupId  = 'ca-targeted-group'
            $fakeGroup = [PSCustomObject]@{
                ObjectType     = 'DynamicGroup'; ObjectId = $groupId; DisplayName = 'CA Group'
                MembershipRule = 'memberOf("g1")'; RuleComplexity = 'Low'; Owners = ''
                SuggestedAction= 'Replace-Rule or Convert-to-Assigned'; DeadlineDays = 89; BlastRadius = ''
            }
            Mock Get-EMOSAffectedGroups    { return @($fakeGroup) }
            Mock Get-EMOSAffectedAdminUnits{ return @() }
            Mock Get-EMOSAffectedEMPolicies{ return @() }
            Mock Get-EMOSCATargetedGroupIds{ return @($groupId) }
            Mock Write-Host { }
        }

        It 'Tags groups targeted by CA policy with ConditionalAccess blast radius' {
            $result = Invoke-EMOSReport -OutputPath $script:TempOutput -NoHtml
            ($result | Where-Object ObjectId -eq 'ca-targeted-group').BlastRadius | Should -Be 'ConditionalAccess'
        }
    }
}

