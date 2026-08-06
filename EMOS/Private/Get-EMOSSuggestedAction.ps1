function Get-EMOSSuggestedAction {
    <#
    .SYNOPSIS
        Returns a suggested remediation action based on rule content and object type.
    #>
    param(
        [string]$Rule,
        [ValidateSet('Group','AdminUnit','EMPolicy')]
        [string]$ObjectType
    )

    $hasOtherOperators = $Rule -match '(?i)\b(user\.|device\.)'
    $memberOfOnly      = $Rule -notmatch '(?i)(user\.|device\.)' -and $Rule -match '(?i)memberOf'

    switch ($ObjectType) {
        'Group' {
            if ($memberOfOnly)      { return 'Replace-Rule or Convert-to-Assigned' }
            if ($hasOtherOperators) { return 'Replace memberOf clause with supported operator' }
            return 'Review and replace MemberOf'
        }
        'AdminUnit' {
            if ($memberOfOnly)      { return 'Replace-Rule or Convert-to-Assigned' }
            return 'Replace memberOf clause with supported operator'
        }
        'EMPolicy' {
            return 'Replace MemberOf with alternative assignment method'
        }
    }
}
