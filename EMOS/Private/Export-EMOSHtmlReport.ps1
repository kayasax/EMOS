function Export-EMOSHtmlReport {
    <#
    .SYNOPSIS
        Generates a self-contained HTML remediation dashboard with sortable/filterable table.
    #>
    param(
        [PSCustomObject[]]$Findings,
        [string]$OutputPath,
        [int]$DeadlineDays
    )

    Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

    $urgencyColor = if ($DeadlineDays -lt 30) { '#c0392b' } elseif ($DeadlineDays -lt 90) { '#e67e22' } else { '#27ae60' }
    $generatedAt  = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $caTargeted   = @($Findings | Where-Object { $_.BlastRadius -like '*ConditionalAccess*' }).Count
    $blastCount   = @($Findings | Where-Object { $_.BlastRadius -ne '' }).Count

    $rows = foreach ($f in $Findings) {
        $blastBadge = if ($f.BlastRadius) { "<span class='badge blast'>$($f.BlastRadius)</span>" } else { '' }
        $complexityClass = switch ($f.RuleComplexity) {
            'High'   { 'complexity-high' }
            'Medium' { 'complexity-med' }
            default  { 'complexity-low' }
        }
        $typeIcon = switch ($f.ObjectType) {
            'DynamicGroup'       { '👥' }
            'DynamicAdminUnit'   { '🏢' }
            'EMAutoAssignPolicy' { '📦' }
            default              { '❓' }
        }
        $rule = [System.Web.HttpUtility]::HtmlEncode($f.MembershipRule ?? '')
        "<tr>
          <td>$typeIcon $($f.ObjectType)</td>
          <td><strong>$($f.DisplayName)</strong><br><small class='obj-id'>$($f.ObjectId)</small></td>
          <td><code>$rule</code></td>
          <td><span class='$complexityClass'>$($f.RuleComplexity)</span></td>
          <td>$($f.SuggestedAction)</td>
          <td>$blastBadge</td>
        </tr>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>EMOS Report - $generatedAt</title>
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<style>
  body { font-family: Segoe UI, sans-serif; margin: 0; background: #f4f6f9; color: #2c3e50; }
  header { background: #2c3e50; color: white; padding: 20px 40px; }
  header h1 { margin: 0; font-size: 1.6em; }
  header p  { margin: 4px 0 0; opacity: 0.8; }
  .deadline { display: inline-block; background: $urgencyColor; color: white; padding: 6px 14px; border-radius: 20px; font-weight: bold; margin-top: 10px; }
  .container { padding: 30px 40px; }
  .summary { display: flex; gap: 20px; margin-bottom: 30px; flex-wrap: wrap; }
  .card { background: white; border-radius: 8px; padding: 20px 30px; box-shadow: 0 2px 8px rgba(0,0,0,.08); min-width: 160px; text-align: center; }
  .card h2 { font-size: 2.4em; margin: 0; color: #c0392b; }
  .card p  { margin: 4px 0 0; font-size: .85em; color: #7f8c8d; }
  table.dataTable { width: 100% !important; border-collapse: collapse; background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,.08); }
  table.dataTable thead th { background: #34495e; color: white; padding: 12px 16px; font-size: .85em; text-transform: uppercase; letter-spacing: .05em; border-bottom: none; }
  table.dataTable thead th.sorting:after,
  table.dataTable thead th.sorting_asc:after,
  table.dataTable thead th.sorting_desc:after { color: #aab; }
  table.dataTable tbody td { padding: 12px 16px; border-bottom: 1px solid #ecf0f1; font-size: .9em; vertical-align: top; }
  table.dataTable tbody tr:last-child td { border-bottom: none; }
  table.dataTable tbody tr:hover td { background: #f8f9fa; }
  .dataTables_wrapper .dataTables_filter input { border: 1px solid #ddd; border-radius: 4px; padding: 5px 10px; margin-left: 6px; }
  .dataTables_wrapper .dataTables_length select { border: 1px solid #ddd; border-radius: 4px; padding: 4px 8px; }
  .dataTables_wrapper { margin-bottom: 20px; }
  code { background: #f0f0f0; padding: 2px 6px; border-radius: 4px; font-size: .8em; word-break: break-all; }
  .obj-id { color: #95a5a6; font-size: .8em; }
  .complexity-high { color: #c0392b; font-weight: bold; }
  .complexity-med  { color: #e67e22; font-weight: bold; }
  .complexity-low  { color: #27ae60; }
  .badge { padding: 3px 10px; border-radius: 12px; font-size: .8em; font-weight: bold; }
  .badge.blast { background: #fadbd8; color: #c0392b; }
  footer { padding: 20px 40px; font-size: .8em; color: #95a5a6; }
</style>
</head>
<body>
<header>
  <h1>🔍 EMOS — Entra MemberOf Scanner Report</h1>
  <p>Generated: $generatedAt</p>
  <span class="deadline">⏰ $DeadlineDays days until retirement (Nov 3, 2026)</span>
</header>
<div class="container">
  <div class="summary">
    <div class="card"><h2>$($Findings.Count)</h2><p>Total findings</p></div>
    <div class="card"><h2>$(@($Findings | Where-Object ObjectType -eq 'DynamicGroup').Count)</h2><p>Dynamic Groups</p></div>
    <div class="card"><h2>$(@($Findings | Where-Object ObjectType -eq 'DynamicAdminUnit').Count)</h2><p>Admin Units</p></div>
    <div class="card"><h2>$(@($Findings | Where-Object ObjectType -eq 'EMAutoAssignPolicy').Count)</h2><p>EM Policies</p></div>
    <div class="card"><h2>$caTargeted</h2><p>CA-targeted</p></div>
    <div class="card"><h2>$blastCount</h2><p>With blast radius</p></div>
  </div>
  <table id="findings" class="display">
    <thead><tr>
      <th>Type</th><th>Name / ID</th><th>Rule</th><th>Complexity</th><th>Suggested Action</th><th>Blast Radius</th>
    </tr></thead>
    <tbody>$($rows -join "`n")</tbody>
  </table>
</div>
<footer>
  EMOS v0.1.0 · <a href="https://github.com/kayasax/EMOS">github.com/kayasax/EMOS</a> ·
  <a href="https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-member-of">Microsoft retirement docs</a>
</footer>
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script>
  \$(document).ready(function() {
    \$('#findings').DataTable({
      pageLength: 25,
      order: [[3, 'desc']],  // sort by Complexity desc by default
      columnDefs: [
        { orderable: false, targets: [1, 2] }  // Name/Rule columns not sortable (too long)
      ],
      language: {
        search: 'Filter:',
        lengthMenu: 'Show _MENU_ findings',
        info: 'Showing _START_ to _END_ of _TOTAL_ findings',
        infoFiltered: '(filtered from _MAX_ total)'
      }
    });
  });
</script>
</body>
</html>
"@

    $html | Set-Content -Path $OutputPath -Encoding UTF8
}
