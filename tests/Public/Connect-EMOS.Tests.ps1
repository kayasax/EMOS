BeforeAll {
    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Public\Connect-EMOS.ps1"

    $script:EMOS_RETIREMENT_DATE = [datetime]'2026-11-03'

    # Spy implementation — captures every call to Connect-MgGraph
    $script:connectCalls = [System.Collections.Generic.List[hashtable]]::new()

    function Connect-MgGraph {
        [CmdletBinding()]
        param(
            [string[]]$Scopes,
            [string]$TenantId,
            [string]$ClientId,
            [string]$CertificateThumbprint,
            [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
            [object]$ClientSecretCredential,
            [switch]$UseDeviceCode,
            [switch]$Identity,
            [switch]$NoWelcome
        )
        $script:connectCalls.Add(@{
            Scopes                = $Scopes
            TenantId              = $TenantId
            ClientId              = $ClientId
            CertificateThumbprint = $CertificateThumbprint
            Certificate           = $Certificate
            UseDeviceCode         = $UseDeviceCode.IsPresent
            Identity              = $Identity.IsPresent
        })
    }

    function Disconnect-MgGraph { $script:disconnectCalled = $true }
    function Get-MgContext      { return $null }
    function Write-Host         { }
    function Write-Verbose      { }
}

Describe 'Connect-EMOS' {

    Context 'Session reuse — existing session with sufficient scopes' {
        BeforeEach {
            $script:connectCalls.Clear()
            $fullCtx = [PSCustomObject]@{
                Account  = 'admin@contoso.com'
                TenantId = 'tenant-123'
                AppName  = $null
                Scopes   = @('Group.Read.All','AdministrativeUnit.Read.All','EntitlementManagement.Read.All','Policy.Read.All','Application.Read.All')
            }
            Mock Get-MgContext { return $fullCtx }
        }

        It 'Does not call Connect-MgGraph when scopes are sufficient' {
            Connect-EMOS
            $script:connectCalls.Count | Should -Be 0
        }

        It 'Does call Connect-MgGraph when -Force is specified' {
            Connect-EMOS -Force
            $script:connectCalls.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Session reuse — missing scopes triggers reconnect' {
        BeforeEach {
            $script:connectCalls.Clear()
            $partialCtx = [PSCustomObject]@{
                Account  = 'admin@contoso.com'
                TenantId = 'tenant-123'
                AppName  = $null
                Scopes   = @('Group.Read.All')   # 4 required scopes missing
            }
            Mock Get-MgContext { return $partialCtx }
        }

        It 'Reconnects when required scopes are missing' {
            Connect-EMOS
            $script:connectCalls.Count | Should -Be 1
        }
    }

    Context 'Interactive flow — no existing session' {
        BeforeEach {
            $script:connectCalls.Clear()
            Mock Get-MgContext { return $null }
        }

        It 'Calls Connect-MgGraph with required scopes' {
            Connect-EMOS
            $script:connectCalls.Count          | Should -Be 1
            $script:connectCalls[0].Scopes      | Should -Contain 'Group.Read.All'
            $script:connectCalls[0].Scopes      | Should -Contain 'EntitlementManagement.Read.All'
        }

        It 'Does not pass UseDeviceCode or Identity in interactive mode' {
            Connect-EMOS
            $script:connectCalls[0].UseDeviceCode | Should -Be $false
            $script:connectCalls[0].Identity      | Should -Be $false
        }
    }

    Context 'DeviceCode flow' {
        BeforeEach {
            $script:connectCalls.Clear()
            Mock Get-MgContext { return $null }
        }

        It 'Passes UseDeviceCode=true to Connect-MgGraph' {
            Connect-EMOS -UseDeviceCode -TenantId 'contoso.onmicrosoft.com'
            $script:connectCalls[0].UseDeviceCode | Should -Be $true
        }

        It 'Passes TenantId to Connect-MgGraph' {
            Connect-EMOS -UseDeviceCode -TenantId 'contoso.onmicrosoft.com'
            $script:connectCalls[0].TenantId | Should -Be 'contoso.onmicrosoft.com'
        }
    }

    Context 'Certificate flow (app-only)' {
        BeforeEach {
            $script:connectCalls.Clear()
            Mock Get-MgContext { return $null }
        }

        It 'Passes CertificateThumbprint and ClientId' {
            Connect-EMOS -TenantId 'contoso.onmicrosoft.com' -ClientId 'app-123' -CertificateThumbprint 'ABCDEF'
            $script:connectCalls[0].CertificateThumbprint | Should -Be 'ABCDEF'
            $script:connectCalls[0].ClientId              | Should -Be 'app-123'
        }

        It 'Does not pass delegated Scopes (app-only)' {
            Connect-EMOS -TenantId 'contoso.onmicrosoft.com' -ClientId 'app-123' -CertificateThumbprint 'ABCDEF'
            $script:connectCalls[0].Scopes | Should -BeNullOrEmpty
        }
    }

    Context 'ManagedIdentity flow' {
        BeforeEach {
            $script:connectCalls.Clear()
            Mock Get-MgContext { return $null }
        }

        It 'Passes Identity=true to Connect-MgGraph' {
            Connect-EMOS -ManagedIdentity
            $script:connectCalls[0].Identity | Should -Be $true
        }
    }
}

Describe 'Disconnect-EMOS' {
    BeforeEach {
        $script:disconnectCalled = $false
    }

    It 'Calls Disconnect-MgGraph' {
        Disconnect-EMOS
        $script:disconnectCalled | Should -Be $true
    }
}

Describe 'Connect-EMOS' {

    Context 'Session reuse — existing session with sufficient scopes' {
        BeforeEach {
            Mock Get-MgContext {
                [PSCustomObject]@{
                    Account  = 'admin@contoso.com'
                    TenantId = 'tenant-123'
                    AppName  = $null
                    Scopes   = @('Group.Read.All','AdministrativeUnit.Read.All','EntitlementManagement.Read.All','Policy.Read.All','Application.Read.All')
                }
            }
            Mock Connect-MgGraph { }
            Mock Write-Host { }
        }

        It 'Does not call Connect-MgGraph when scopes are sufficient' {
            Connect-EMOS
            Should -Invoke Connect-MgGraph -Times 0
        }

        It 'Calls Connect-MgGraph when -Force is specified' {
            # After reconnect, Get-MgContext must return a valid context
            Mock Get-MgContext {
                [PSCustomObject]@{ Account = 'admin@contoso.com'; TenantId = 'tenant-123'; AppName = $null; Scopes = @() }
            }
            Connect-EMOS -Force
            Should -Invoke Connect-MgGraph -Times 1
        }
    }

    Context 'Session reuse — existing session with missing scopes' {
        BeforeEach {
            Mock Get-MgContext {
                [PSCustomObject]@{
                    Account  = 'admin@contoso.com'
                    TenantId = 'tenant-123'
                    AppName  = $null
                    Scopes   = @('Group.Read.All')   # missing 4 scopes
                }
            }
            Mock Connect-MgGraph { }
            Mock Write-Host { }
            Mock Write-Verbose { }
        }

        It 'Reconnects when required scopes are missing' {
            Connect-EMOS
            Should -Invoke Connect-MgGraph -Times 1
        }
    }

    Context 'Interactive flow (default)' {
        BeforeEach {
            Mock Get-MgContext { return $null }   # always "not connected" — triggers reconnect
            Mock Connect-MgGraph { }
            Mock Write-Host { }
        }

        It 'Passes required scopes to Connect-MgGraph' {
            Connect-EMOS
            Should -Invoke Connect-MgGraph -ParameterFilter {
                $Scopes -contains 'Group.Read.All'
            }
        }
    }

    Context 'DeviceCode flow' {
        BeforeEach {
            Mock Get-MgContext { return $null }
            Mock Connect-MgGraph { }
            Mock Write-Host { }
        }

        It 'Passes UseDeviceCode to Connect-MgGraph' {
            Connect-EMOS -UseDeviceCode -TenantId 'contoso.onmicrosoft.com'
            Should -Invoke Connect-MgGraph -ParameterFilter { $UseDeviceCode -eq $true }
        }
    }

    Context 'Certificate flow (app-only)' {
        BeforeEach {
            Mock Get-MgContext { return $null }
            Mock Connect-MgGraph { }
            Mock Write-Host { }
        }

        It 'Passes CertificateThumbprint and ClientId to Connect-MgGraph' {
            Connect-EMOS -TenantId 'contoso.onmicrosoft.com' -ClientId 'app-123' -CertificateThumbprint 'ABCDEF'
            Should -Invoke Connect-MgGraph -ParameterFilter {
                $CertificateThumbprint -eq 'ABCDEF' -and $ClientId -eq 'app-123'
            }
        }

        It 'Does NOT pass delegated Scopes in certificate (app-only) flow' {
            Connect-EMOS -TenantId 'contoso.onmicrosoft.com' -ClientId 'app-123' -CertificateThumbprint 'ABCDEF'
            Should -Invoke Connect-MgGraph -ParameterFilter { -not $Scopes }
        }
    }

    Context 'ManagedIdentity flow' {
        BeforeEach {
            Mock Get-MgContext { return $null }
            Mock Connect-MgGraph { }
            Mock Write-Host { }
        }

        It 'Passes -Identity to Connect-MgGraph' {
            Connect-EMOS -ManagedIdentity
            Should -Invoke Connect-MgGraph -ParameterFilter { $Identity -eq $true }
        }
    }
}

Describe 'Disconnect-EMOS' {
    BeforeEach {
        Mock Disconnect-MgGraph { }
        Mock Write-Host { }
    }

    It 'Calls Disconnect-MgGraph' {
        Disconnect-EMOS
        Should -Invoke Disconnect-MgGraph -Times 1
    }
}
