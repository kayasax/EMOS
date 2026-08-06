function Invoke-EMOSGraphRequest {
    <#
    .SYNOPSIS
        Wraps Invoke-MgGraphRequest with automatic pagination and 429 retry logic.
    .DESCRIPTION
        Issues a GET to the Microsoft Graph API. Automatically follows @odata.nextLink
        to retrieve all pages, and retries on HTTP 429 (throttling) by honouring the
        Retry-After response header. All pages are returned as a single flat array.
    .PARAMETER Uri
        The initial Graph API URI (relative or absolute).
    .PARAMETER MaxRetries
        Maximum number of retry attempts on 429. Default: 5.
    .OUTPUTS
        Array of value items across all pages.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [hashtable]$Headers = @{},

        [ValidateRange(1, 10)]
        [int]$MaxRetries = 5
    )

    $results   = [System.Collections.Generic.List[object]]::new()
    $currentUri = $Uri
    $pageNumber  = 0

    do {
        $pageNumber++
        $attempt = 0
        $response = $null

        while ($attempt -le $MaxRetries) {
            try {
                Write-Verbose "EMOS Graph GET (page $pageNumber, attempt $($attempt+1)): $currentUri"
                $response = Invoke-MgGraphRequest -Method GET -Uri $currentUri -OutputType PSObject -Headers $Headers
                break   # success — exit retry loop
            }
            catch {
                # Detect 429 — check message (works without Graph SDK loaded)
                $is429 = $_.Exception.Message -match '429|Too\s+Many\s+Requests'

                # Also check response status if available (live Graph SDK path)
                if (-not $is429) {
                    try {
                        $statusCode = $_.Exception.Response.StatusCode.value__
                        if ($statusCode -eq 429) { $is429 = $true }
                    }
                    catch { }
                }

                if ($is429 -and $attempt -lt $MaxRetries) {
                    $retryAfter = 30   # safe default

                    # Try to read Retry-After from the exception response headers
                    try {
                        $raHeader = $_.Exception.Response.Headers.GetValues('Retry-After') | Select-Object -First 1
                        if ($raHeader -and [int]::TryParse($raHeader, [ref]$null)) {
                            $retryAfter = [int]$raHeader
                        }
                    }
                    catch { }

                    $attempt++
                    Write-Warning "EMOS: Graph throttled (429). Waiting ${retryAfter}s before retry $attempt/$MaxRetries..."
                    Start-Sleep -Seconds $retryAfter
                }
                else {
                    # Non-429 or exhausted retries — rethrow
                    throw
                }
            }
        }

        if ($null -eq $response) {
            throw "EMOS: Graph request failed after $MaxRetries retries: $currentUri"
        }

        # Collect this page's items
        if ($null -ne $response.value) {
            $results.AddRange([object[]]$response.value)
        }
        else {
            # Single-object response (no .value wrapper)
            $results.Add($response)
        }

        $currentUri = $response.'@odata.nextLink'

    } while ($currentUri)

    Write-Verbose "EMOS Graph: retrieved $($results.Count) item(s) across $pageNumber page(s) from $Uri"
    return $results.ToArray()
}
