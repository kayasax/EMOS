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

        $apId = if ($f.PSObject.Properties['AccessPackageId']) { $f.AccessPackageId } else { '' }

        # Direct Entra portal links per object type
        $portalLink = switch ($f.ObjectType) {
            'DynamicGroup' {
                "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/DynamicMembership/groupId/$($f.ObjectId)"
            }
            'DynamicAdminUnit' {
                "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AdministrativeUnitEditMenuBlade/~/DynamicMembership/objectId/$($f.ObjectId)"
            }
            'EMAutoAssignPolicy' {
                "https://entra.microsoft.com/#view/Microsoft_AAD_ELM/AccessPackageMenuBlade/~/Policies/accessPackageId/$apId"
            }
            default { '#' }
        }

        # Action varies by type
        $groupCount = ([regex]::Matches($f.MembershipRule ?? '', "'[^']+'") | Measure-Object).Count
        $actionTag = switch ($f.ObjectType) {
            'DynamicGroup' {
                if ($f.RuleComplexity -eq 'Low') {
                    "<span class='action-tag'>Replace rule</span> or <span class='action-tag'>Convert to Assigned</span>"
                } else {
                    "<span class='action-tag action-hard'>Replace $($f.RuleComplexity) rule</span> — $groupCount group$(if($groupCount -ne 1){'s'}) to replicate"
                }
            }
            'DynamicAdminUnit' {
                if ($f.RuleComplexity -eq 'Low') {
                    "<span class='action-tag'>Replace rule</span> or <span class='action-tag'>Convert to Assigned</span>"
                } else {
                    "<span class='action-tag action-hard'>Replace $($f.RuleComplexity) rule</span> — $groupCount group$(if($groupCount -ne 1){'s'}) to replicate"
                }
            }
            'EMAutoAssignPolicy' {
                "<span class='action-tag action-hard'>Update auto-assignment filter</span>"
            }
            default { $f.SuggestedAction }
        }
        $portalLabel = switch ($f.ObjectType) {
            'EMAutoAssignPolicy' { '→ Edit policy' }
            'DynamicGroup' { '→ Edit rule' }
            'DynamicAdminUnit' { '→ Edit rule' }
            default { '→ Edit in portal' }
        }
        $action = "$actionTag <a href='$portalLink' target='_blank' class='portal-link'>$portalLabel</a>"

        $blastCell = if ($f.BlastRadius) {
            $badges = $f.BlastRadius.Split(',') | ForEach-Object { "<span class='badge blast'>$($_.Trim())</span>" }
            $badges -join ' '
        } else { '<span style="color:#bdc3c7">—</span>' }

        # Store raw ObjectType in a hidden span so DataTables can search/filter on it
        "<tr>
          <td><span class='dt-type' style='display:none'>$($f.ObjectType)</span>$typeIcon<br><small>$(($f.ObjectType -replace 'Dynamic','').ToUpper())</small></td>
          <td><a href='$portalLink' target='_blank' class='obj-link'>$($f.DisplayName)</a><br><small class='obj-id'>$($f.ObjectId)</small></td>
          <td><code>$rule</code></td>
          <td data-order='$(if($f.RuleComplexity -eq 'High'){3}elseif($f.RuleComplexity -eq 'Medium'){2}else{1})'><span class='$complexityClass'>$($f.RuleComplexity)</span></td>
          <td>$action</td>
          <td>$blastCell</td>
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
  * { box-sizing: border-box; }
  body { font-family: Segoe UI, sans-serif; margin: 0; background: #f4f6f9; color: #2c3e50; }
  header { background: #2c3e50; color: white; padding: 20px 40px; }
  header h1 { margin: 0; font-size: 1.6em; }
  header p  { margin: 4px 0 0; opacity: 0.8; }
  .deadline { display: inline-block; background: $urgencyColor; color: white; padding: 6px 14px; border-radius: 20px; font-weight: bold; margin-top: 10px; }
  .container { padding: 24px 40px; }
  .summary { display: flex; gap: 16px; margin-bottom: 24px; flex-wrap: wrap; }
  .card { background: white; border-radius: 8px; padding: 16px 24px; box-shadow: 0 2px 8px rgba(0,0,0,.08); min-width: 130px; text-align: center; }
  .card h2 { font-size: 2em; margin: 0; color: #c0392b; }
  .card p  { margin: 4px 0 0; font-size: .82em; color: #7f8c8d; }
  .card .tip { font-size: .72em; color: #aab; margin-top: 2px; }
  .toolbar { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; flex-wrap: wrap; }
  .toolbar label { font-size: .85em; color: #7f8c8d; }
  .toolbar select, .toolbar input { border: 1px solid #ddd; border-radius: 6px; padding: 6px 10px; font-size: .9em; }
  .toolbar input[type=search] { width: 280px; }
  #findings-clear { font-size: .82em; color: #3498db; cursor: pointer; text-decoration: underline; }
  table.dataTable { width: 100% !important; border-collapse: collapse; background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,.08); }
  table.dataTable thead th { background: #34495e !important; color: white; padding: 11px 14px; font-size: .82em; text-transform: uppercase; letter-spacing: .05em; border: none !important; }
  table.dataTable thead th.sorting:after,
  table.dataTable thead th.sorting_asc:after,
  table.dataTable thead th.sorting_desc:after { opacity: .7; }
  table.dataTable tbody td { padding: 10px 14px; border-bottom: 1px solid #ecf0f1 !important; font-size: .88em; vertical-align: top; }
  table.dataTable tbody tr:last-child td { border-bottom: none !important; }
  table.dataTable tbody tr:hover td { background: #f8f9fa; }
  .dataTables_info, .dataTables_paginate { margin-top: 10px; font-size: .85em; }
  code { background: #f0f0f0; padding: 2px 5px; border-radius: 4px; font-size: .78em; word-break: break-all; display: block; max-width: 340px; }
  .obj-id { color: #aab; font-size: .78em; }
  .obj-link { color: #2980b9; text-decoration: none; font-weight: 600; }
  .obj-link:hover { text-decoration: underline; }
  .complexity-high { color: #c0392b; font-weight: bold; }
  .complexity-med  { color: #e67e22; font-weight: bold; }
  .complexity-low  { color: #27ae60; }
  .action-tag { display: inline-block; background: #eaf4fb; color: #2980b9; border-radius: 4px; padding: 2px 7px; font-size: .82em; margin: 1px; }
  .action-tag.action-hard { background: #fdedec; color: #c0392b; }
  .portal-link { color: #2980b9; font-size: .82em; text-decoration: none; margin-left: 4px; }
  .portal-link:hover { text-decoration: underline; }
  .badge { padding: 2px 8px; border-radius: 10px; font-size: .78em; font-weight: bold; white-space: nowrap; }
  .badge.blast { background: #fadbd8; color: #c0392b; }
  footer { padding: 16px 40px; font-size: .8em; color: #95a5a6; border-top: 1px solid #ecf0f1; margin-top: 20px; }
  [title] { cursor: help; border-bottom: 1px dotted #bbb; }
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
    <div class="card"><h2>$caTargeted</h2><p title="Groups targeted by Conditional Access policies. Stale membership may cause access enforcement gaps.">CA-targeted ⓘ</p></div>
    <div class="card"><h2>$blastCount</h2><p title="Objects whose stale membership could impact CA policy enforcement, EM access package assignments, or AU-scoped admin roles. Licensing impact is detected separately.">Blast radius ⓘ</p><div class="tip">wider impact risk</div></div>
  </div>

  <div class="toolbar">
    <label>Type:</label>
    <select id="filter-type">
      <option value="">All</option>
      <option value="DynamicGroup">👥 Dynamic Groups</option>
      <option value="DynamicAdminUnit">🏢 Admin Units</option>
      <option value="EMAutoAssignPolicy">📦 EM Policies</option>
    </select>
    <label>Complexity:</label>
    <select id="filter-complexity">
      <option value="">All</option>
      <option value="High">High</option>
      <option value="Medium">Medium</option>
      <option value="Low">Low</option>
    </select>
    <label>Blast Radius:</label>
    <select id="filter-blast">
      <option value="">All</option>
      <option value="with">With blast radius</option>
      <option value="ConditionalAccess">CA-targeted</option>
      <option value="Licensing">Licensing</option>
      <option value="Entitlement Management">EM Policy</option>
      <option value="none">None</option>
    </select>
    <label>Search:</label>
    <input type="search" id="filter-search" placeholder="Filter by name, ID, or rule…">
    <span id="findings-clear" onclick="clearFilters()">Clear filters</span>
  </div>

  <table id="findings" class="display" style="width:100%">
    <thead><tr>
      <th>Type</th><th>Name / ID</th><th>Rule</th><th>Complexity</th><th>Suggested Action</th>
      <th title="Blast radius: the broader impact if membership becomes stale. CA = Conditional Access, EM = Entitlement Management.">Blast Radius ⓘ</th>
    </tr></thead>
    <tbody>$($rows -join "`n")</tbody>
  </table>
</div>
<footer>
  EMOS v0.1.0 · <a href="https://github.com/kayasax/EMOS">github.com/kayasax/EMOS</a> ·
  <a href="https://learn.microsoft.com/entra/identity/users/groups-dynamic-rule-member-of">Microsoft retirement docs</a>
  &nbsp;·&nbsp; Click any name to open directly in Entra portal
</footer>

<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script>
var table;
`$(document).ready(function() {
  table = `$('#findings').DataTable({
    pageLength: 25,
    order: [[3, 'desc']],
    columnDefs: [
      { orderable: false, targets: [1, 2, 4, 5] },
      { type: 'num', targets: 3 }
    ],
    language: {
      search: '',
      searchPlaceholder: '',
      lengthMenu: 'Show _MENU_',
      info: '_START_–_END_ of _TOTAL_ findings',
      infoFiltered: ' (filtered from _MAX_)',
      paginate: { previous: '‹', next: '›' }
    },
    dom: 'tip'   // table, info, pagination — search handled by custom toolbar
  });

  `$('#filter-type').on('change', function() {
    // Search the hidden .dt-type span text in column 0
    table.column(0).search(this.value, false, false).draw();
  });
  `$('#filter-complexity').on('change', function() {
    // Search the visible span text in column 3
    table.column(3).search(this.value, false, false).draw();
  });
  `$('#filter-blast').on('change', function() {
    var val = this.value;
    if (val === 'with') {
      table.column(5).search('^(?!—$).+', true, false).draw();
    } else if (val === 'none') {
      table.column(5).search('^—$', true, false).draw();
    } else {
      table.column(5).search(val, false, false).draw();
    }
  });
  `$('#filter-search').on('input', function() {
    table.search(this.value).draw();
  });
});

function clearFilters() {
  `$('#filter-type').val('');
  `$('#filter-complexity').val('');
  `$('#filter-blast').val('');
  `$('#filter-search').val('');
  table.column(5).search('').draw();
  table.search('').columns().search('').draw();
}
</script>
</body>
</html>
"@

    $html | Set-Content -Path $OutputPath -Encoding UTF8
}
