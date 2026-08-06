function Get-EMOSSuggestedAction {
    <#
    .SYNOPSIS
        Returns a suggested remediation action based on object type.
    .NOTES
        MemberOf cannot be combined with other attribute rules, so the suggestion
        is uniform per object type — the only variable is how many groups to replicate.
    #>
    param(
        [string]$Rule,
        [ValidateSet('Group','AdminUnit','EMPolicy')]
        [string]$ObjectType
    )

    switch ($ObjectType) {
        'Group'     { return 'Replace memberOf with supported rule operators or convert to Assigned membership' }
        'AdminUnit' { return 'Replace memberOf with supported rule operators or convert to Assigned membership' }
        'EMPolicy'  { return 'Replace memberOf with supported operators or plan alternative assignment method' }
    }
}
