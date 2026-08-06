#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Local build script for EMOS.
.DESCRIPTION
    Supports Test, Build, Pack, and Publish tasks.
.PARAMETER Task
    Task to run: Test | Build | Pack | Publish (default: Test)
.PARAMETER NuGetApiKey
    PSGallery API key (for Publish task). Falls back to $env:PSGALLERY_API_KEY.
.EXAMPLE
    ./build.ps1
    ./build.ps1 -Task Build
    ./build.ps1 -Task Publish -NuGetApiKey "abc123"
#>
[CmdletBinding()]
param(
    [ValidateSet('Test','Build','Pack','Publish')]
    [string]$Task = 'Test',
    [string]$NuGetApiKey = $env:PSGALLERY_API_KEY
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ModuleName  = 'EMOS'
$ModulePath  = Join-Path $PSScriptRoot $ModuleName
$OutputPath  = Join-Path $PSScriptRoot 'output'
$TestResults = Join-Path $PSScriptRoot 'tests\TestResults'

function Invoke-Task-Test {
    Write-Host "`n=== TASK: Test ===" -ForegroundColor Cyan

    if (-not (Get-Module Pester -ListAvailable | Where-Object Version -ge '5.0')) {
        Write-Host "Installing Pester 5..." -ForegroundColor Yellow
        Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck -Scope CurrentUser
    }

    New-Item -ItemType Directory -Path $TestResults -Force | Out-Null

    $config = New-PesterConfiguration
    $config.Run.Path                         = './tests'
    $config.Run.PassThru                     = $true
    $config.Filter.ExcludeTag                = @('Integration')
    $config.Output.Verbosity                 = 'Detailed'
    $config.TestResult.Enabled               = $true
    $config.TestResult.OutputFormat          = 'NUnitXml'
    $config.TestResult.OutputPath            = "$TestResults\results.xml"
    $config.CodeCoverage.Enabled             = $true
    $config.CodeCoverage.Path                = @('./EMOS/Public/*.ps1','./EMOS/Private/*.ps1')
    $config.CodeCoverage.OutputPath          = "$TestResults\coverage.xml"
    $config.CodeCoverage.CoveragePercentTarget = 70

    $result = Invoke-Pester -Configuration $config

    if ($result.FailedCount -gt 0) {
        Write-Error "Tests failed: $($result.FailedCount) failures."
    }

    Write-Host "`nPassed: $($result.PassedCount) | Failed: $($result.FailedCount) | Skipped: $($result.SkippedCount)" -ForegroundColor $(if ($result.FailedCount -eq 0) { 'Green' } else { 'Red' })
}

function Invoke-Task-Build {
    Write-Host "`n=== TASK: Build ===" -ForegroundColor Cyan

    Invoke-Task-Test

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $dest = Join-Path $OutputPath $ModuleName

    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $ModulePath $dest -Recurse

    Write-Host "Built to: $dest" -ForegroundColor Green
}

function Invoke-Task-Pack {
    Write-Host "`n=== TASK: Pack ===" -ForegroundColor Cyan

    Invoke-Task-Build

    $manifest = Import-PowerShellDataFile "$ModulePath\$ModuleName.psd1"
    $version   = $manifest.ModuleVersion
    $nupkg     = Join-Path $OutputPath "$ModuleName.$version.nupkg"

    Register-PSRepository -Name LocalOutput -SourceLocation $OutputPath -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Publish-Module -Path (Join-Path $OutputPath $ModuleName) -Repository LocalOutput -Force
    Write-Host "Packed: $nupkg" -ForegroundColor Green
}

function Invoke-Task-Publish {
    Write-Host "`n=== TASK: Publish ===" -ForegroundColor Cyan

    if (-not $NuGetApiKey) {
        throw "No PSGallery API key. Set PSGALLERY_API_KEY or pass -NuGetApiKey."
    }

    Invoke-Task-Build

    $destModule = Join-Path $OutputPath $ModuleName
    Write-Host "Publishing $ModuleName to PSGallery..." -ForegroundColor Cyan
    Publish-Module -Path $destModule -NuGetApiKey $NuGetApiKey -Verbose
    Write-Host "Published!" -ForegroundColor Green
}

switch ($Task) {
    'Test'    { Invoke-Task-Test }
    'Build'   { Invoke-Task-Build }
    'Pack'    { Invoke-Task-Pack }
    'Publish' { Invoke-Task-Publish }
}
