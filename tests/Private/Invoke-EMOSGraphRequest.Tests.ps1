BeforeAll {
    $root = "$PSScriptRoot\..\.."
    . "$root\EMOS\Private\Invoke-EMOSGraphRequest.ps1"

    # Stub so Pester can mock it
    function Invoke-MgGraphRequest { throw "stub - must be mocked" }
}

Describe 'Invoke-EMOSGraphRequest' {

    Context 'Single-page response' {
        BeforeEach {
            $page = [PSCustomObject]@{
                value            = @('item1','item2','item3')
                '@odata.nextLink'= $null
            }
            Mock Invoke-MgGraphRequest { return $page }
        }

        It 'Returns all items from a single page' {
            $result = Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            $result.Count | Should -Be 3
        }

        It 'Calls Graph exactly once for a single page' {
            Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly
        }
    }

    Context 'Multi-page response (pagination)' {
        BeforeEach {
            $page1 = [PSCustomObject]@{
                value             = @('item1','item2')
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/test?$skiptoken=abc'
            }
            $page2 = [PSCustomObject]@{
                value             = @('item3','item4')
                '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/test?$skiptoken=def'
            }
            $page3 = [PSCustomObject]@{
                value             = @('item5')
                '@odata.nextLink' = $null
            }

            # Queue is scope-safe — no $script:counter leakage between It blocks
            $script:pageQueue = [System.Collections.Queue]::new()
            $script:pageQueue.Enqueue($page1)
            $script:pageQueue.Enqueue($page2)
            $script:pageQueue.Enqueue($page3)

            Mock Invoke-MgGraphRequest { $script:pageQueue.Dequeue() }
        }

        It 'Returns items from all pages as a flat array' {
            $result = Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            $result.Count | Should -Be 5
        }

        It 'Follows nextLink for each page' {
            # Re-seed queue for this It block (BeforeEach already did, but verify count)
            $result = Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            Should -Invoke Invoke-MgGraphRequest -Times 3 -Exactly
        }
    }

    Context '429 throttling — retry with Retry-After' {
        BeforeEach {
            $successPage = [PSCustomObject]@{ value = @('item1'); '@odata.nextLink' = $null }

            $script:throttleQueue = [System.Collections.Queue]::new()
            $script:throttleQueue.Enqueue({ throw [System.Exception]::new('429 Too Many Requests') })
            $script:throttleQueue.Enqueue({ return $successPage })

            Mock Invoke-MgGraphRequest { & ($script:throttleQueue.Dequeue()) }
            Mock Start-Sleep { }
        }

        It 'Retries after a 429 and returns data on success' {
            $result = Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            $result.Count | Should -Be 1
        }

        It 'Calls Graph twice: once throttled, once successful' {
            Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            Should -Invoke Invoke-MgGraphRequest -Times 2 -Exactly
        }

        It 'Sleeps between throttled requests' {
            Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            Should -Invoke Start-Sleep -Times 1
        }
    }

    Context '429 throttling — exhausted retries' {
        BeforeEach {
            Mock Invoke-MgGraphRequest {
                throw [System.Exception]::new('429 Too Many Requests')
            }
            Mock Start-Sleep { }
        }

        It 'Throws after MaxRetries is exhausted' {
            { Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -MaxRetries 2 } |
                Should -Throw
        }

        It 'Retries exactly MaxRetries times before giving up' {
            try { Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -MaxRetries 3 } catch { }
            # Initial attempt + 3 retries = 4 total calls
            Should -Invoke Invoke-MgGraphRequest -Times 4 -Exactly
        }
    }

    Context 'Non-429 errors are rethrown immediately' {
        BeforeEach {
            Mock Invoke-MgGraphRequest {
                throw [System.Exception]::new('Forbidden: Access denied')
            }
            Mock Start-Sleep { }
        }

        It 'Rethrows non-429 errors without retrying' {
            { Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' } |
                Should -Throw '*Forbidden*'
        }

        It 'Does not sleep on non-429 errors' {
            try { Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' } catch { }
            Should -Invoke Start-Sleep -Times 0
        }
    }

    Context 'Empty response' {
        BeforeEach {
            Mock Invoke-MgGraphRequest {
                [PSCustomObject]@{ value = @(); '@odata.nextLink' = $null }
            }
        }

        It 'Returns empty array when Graph returns no items' {
            $result = Invoke-EMOSGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test'
            @($result).Count | Should -Be 0
        }
    }
}
