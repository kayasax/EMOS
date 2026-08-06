# Pester configuration for EMOS
# Run with: Invoke-Pester -Configuration (Import-PowerShellDataFile ./pester.config.psd1)
# Or:       ./build.ps1 -Task Test

[PesterConfiguration]@{
    Run = @{
        Path     = './tests'
        PassThru = $true
    }
    Filter = @{
        # Use -Tag Integration to include live Graph tests
        ExcludeTag = @('Integration')
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    TestResult = @{
        Enabled      = $true
        OutputFormat = 'NUnitXml'
        OutputPath   = './tests/TestResults/results.xml'
    }
    CodeCoverage = @{
        Enabled               = $true
        Path                  = './EMOS/Public/*.ps1', './EMOS/Private/*.ps1'
        OutputPath            = './tests/TestResults/coverage.xml'
        OutputFormat          = 'JaCoCo'
        CoveragePercentTarget = 70
    }
}
