#############################################################################
# generate-test-data.ps1
# Sends 10 API requests per subscription to generate telemetry test data
# in App Insights customMetrics table via the APIM AI Gateway.
#
# Usage:
#   .\scripts\generate-test-data.ps1
#   .\scripts\generate-test-data.ps1 -GatewayUrl "https://my-apim.azure-api.net"
#############################################################################

param(
    [string]$GatewayUrl = "https://apim-macu-poc.azure-api.net",
    [int]$MaxTokens = 100,
    [int]$DelayMs = 500
)

# --- Subscription definitions (Product-scoped) ---
$subscriptions = @(
    @{ Name = "Lending Team (Standard)";    Key = "57cbd39636094719bd0a35597639734b"; Product = "Standard" }
    @{ Name = "Member Services (Standard)"; Key = "9f791938f43744748b70ed20fb5e5be2"; Product = "Standard" }
    @{ Name = "Digital Banking (Premium)";  Key = "9a68b70393954f26b909a2c1d69b8a3f"; Product = "Premium"  }
)

# --- 10 diverse credit-union-themed prompts ---
$prompts = @(
    "What are the current mortgage rates for a 30-year fixed loan?"
    "Explain the difference between a credit union and a bank."
    "What documents do I need to open a savings account?"
    "How does compound interest work on a certificate of deposit?"
    "What is the process for applying for an auto loan?"
    "Describe the benefits of a home equity line of credit."
    "What are the requirements for a small business loan?"
    "How do I set up direct deposit for my checking account?"
    "What fraud protection measures does MACU offer?"
    "Explain the advantages of a Roth IRA versus a traditional IRA."
)

$endpoint = "$GatewayUrl/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-01"

Write-Host "`n===== MACU AI Gateway - Test Data Generator =====" -ForegroundColor Cyan
Write-Host "Gateway : $GatewayUrl"
Write-Host "Model   : gpt-4o"
Write-Host "Requests: $($subscriptions.Count) subscriptions x $($prompts.Count) prompts = $($subscriptions.Count * $prompts.Count) total"
Write-Host "MaxTkns : $MaxTokens"
Write-Host ""

$grandTotal = 0
$startTime = Get-Date

foreach ($sub in $subscriptions) {
    Write-Host "========== $($sub.Name) [$($sub.Product)] ==========" -ForegroundColor Yellow
    $subTotal = 0

    for ($i = 0; $i -lt $prompts.Count; $i++) {
        $body = @{
            messages   = @(@{ role = "user"; content = $prompts[$i] })
            max_tokens = $MaxTokens
        } | ConvertTo-Json -Depth 3

        $response = Invoke-WebRequest -Method Post `
            -Uri $endpoint `
            -Headers @{
                "Content-Type"              = "application/json"
                "Ocp-Apim-Subscription-Key" = $sub.Key
            } `
            -Body $body -SkipHttpErrorCheck

        $status    = $response.StatusCode
        $consumed  = if ($response.Headers["x-tokens-consumed"])  { $response.Headers["x-tokens-consumed"][0]  } else { "N/A" }
        $remaining = if ($response.Headers["x-tokens-remaining"]) { $response.Headers["x-tokens-remaining"][0] } else { "N/A" }
        $region    = if ($response.Headers["x-backend-region"])   { $response.Headers["x-backend-region"][0]   } else { "N/A" }

        if ($consumed -ne "N/A") { $subTotal += [int]$consumed }

        $color = if ($status -eq 200) { "Green" } elseif ($status -eq 429) { "Red" } else { "Gray" }
        Write-Host ("  Req {0,2}: HTTP {1} | Tokens: {2,4} | Remaining: {3,6} | Region: {4}" -f `
            ($i + 1), $status, $consumed, $remaining, $region) -ForegroundColor $color

        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    }

    $grandTotal += $subTotal
    Write-Host "  >> Subtotal: $subTotal tokens" -ForegroundColor DarkCyan
    Write-Host ""
}

$elapsed = (Get-Date) - $startTime
Write-Host "===== COMPLETE =====" -ForegroundColor Cyan
Write-Host "Total tokens consumed : $grandTotal"
Write-Host "Elapsed time          : $($elapsed.ToString('mm\:ss'))"
Write-Host "Telemetry will appear in App Insights customMetrics in ~90 seconds.`n"
