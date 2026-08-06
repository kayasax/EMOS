# EMOS.psm1 - Entra MemberOf Scanner
# Dot-source all public and private functions

$Private = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
$Public  = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1"  -ErrorAction SilentlyContinue

foreach ($file in @($Private + $Public)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import function $($file.FullName): $_"
    }
}

# Module-level constants
$script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'

# Real MemberOf rule syntax used by Entra ID:
#   user.memberof -any (group.objectId -in ['id1', 'id2'])
#   device.memberof -any (group.objectId -in ['id1'])
# Also handles the older docs-style variant: memberOf("id")
$script:MEMBEROF_PATTERN = [regex]'(?i)\b(user|device)\.memberof\b|\bmemberOf\s*\('

Export-ModuleMember -Function $Public.BaseName
