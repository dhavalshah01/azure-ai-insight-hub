# Lab — Demo Per-Team Token Limits with the Gateway Demo App

This lab runs a small web app that calls the APIM AI Gateway directly. You choose a **product** (Free, Standard, or Premium) and a **team subscription** in the browser, send requests, and watch the gateway apply each tier's token limit live.

- The app reads products, subscriptions, and subscription keys from a local `.env` file.
- Keys stay on the Node.js server. The browser never receives them.
- Each request goes to the gateway's chat completions endpoint with the selected subscription's key in the `Ocp-Apim-Subscription-Key` header.

## How the Demo Works

| Subscription | Product | Token limit |
|--------------|---------|-------------|
| `rate-limit-tester` | Free | 500 tokens per minute |
| `member-services` | Standard | 5,000 tokens per minute |
| `digital-banking` | Standard | 5,000 tokens per minute |
| `lending-team` | Premium | 200,000 tokens per minute |

- APIM decides the tier from the subscription key, not from the app. The key belongs to a subscription that is scoped to a product, and the API policy (`policies/ai-gateway-api.xml`) applies that product's token limit.
- The product and limit values in `.env` are labels for the UI. They must match what is configured in APIM and the policy.
- Each subscription has its own token counter, so one team being throttled doesn't affect the others.

## Prerequisites

- The infrastructure is deployed (README Steps 6–8), including the products and team subscriptions.
- Node.js 18 or later (Node.js 24 if your network uses a TLS-inspection proxy or VPN).
- A PowerShell window where these variables from README Step 5 and Step 7 are set: `$RESOURCE_GROUP`, `$APIM_NAME`, `$APIM_GATEWAY_URL`, and `$AZURE_SUBSCRIPTION_ID`.

## Steps

### Step 1 — Install the Dependencies

1. Move to the app folder:

```powershell
Set-Location .\src\gateway-demo-app
```

2. Install the packages:

```powershell
npm install
```

   - If PowerShell reports `npm.ps1 cannot be loaded because running scripts is disabled on this system`, run `npm.cmd install` instead.

### Step 2 — Create the `.env` File

The `.env` file has three parts:

- **Gateway settings** — `APIM_GATEWAY_URL`, `CHAT_MODEL`, `OPENAI_API_VERSION`, and `PORT`.
- **Products** — `PRODUCTS` lists the product IDs. Each product has `PRODUCT_<ID>_DISPLAY_NAME` and `PRODUCT_<ID>_TPM`.
- **Subscriptions** — `SUBSCRIPTIONS` lists the APIM subscription names. Each one has `SUBSCRIPTION_<NAME>_DISPLAY_NAME`, `SUBSCRIPTION_<NAME>_PRODUCT`, and `SUBSCRIPTION_<NAME>_KEY`.

In variable names, the ID or name is in upper case with `-` replaced by `_`. For example, `rate-limit-tester` becomes `SUBSCRIPTION_RATE_LIMIT_TESTER_KEY`.

1. Copy the example file:

```powershell
Copy-Item .env.example .env
```

2. Fill in the gateway URL and the primary key of each team subscription. This script reads the keys from APIM and writes them directly into `.env`, without showing them on screen:

```powershell
$envText = (Get-Content .env -Raw).Replace('https://apim-<environmentName>.azure-api.net', $APIM_GATEWAY_URL)

foreach ($name in 'rate-limit-tester', 'member-services', 'digital-banking', 'lending-team') {
  $key = az rest `
    --method post `
    --uri "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ApiManagement/service/$APIM_NAME/subscriptions/$name/listSecrets?api-version=2024-05-01" `
    --query primaryKey `
    --output tsv
  $variable = "SUBSCRIPTION_$($name.ToUpper().Replace('-', '_'))_KEY="
  $envText = $envText.Replace($variable, "$variable$key")
}

[IO.File]::WriteAllText("$PWD\.env", $envText, (New-Object Text.UTF8Encoding($false)))
```

   - To fill in the keys by hand instead, copy each subscription's primary key from **Azure portal → API Management → Subscriptions → … → Show/hide keys**.

3. Confirm that `.env` is ignored by Git:

```powershell
git check-ignore -v .env
```

   - The output should show the `.env` rule from `.gitignore`.

> **Security:** `.env` contains subscription keys. Never commit it or share it in screenshots.

### Step 3 — Start the App

1. If your network uses a TLS-inspection proxy or VPN, tell Node.js to trust the Windows certificate store (Node.js 24):

```powershell
$env:NODE_USE_SYSTEM_CA = "1"
```

2. Start the app:

```powershell
npm start
```

3. Check the console output. Every subscription should show `key=configured`:

```text
Gateway demo app running at http://localhost:8100
APIM gateway: https://apim-<environmentName>.azure-api.net
  rate-limit-tester      product=free       key=configured
  member-services        product=standard   key=configured
  digital-banking        product=standard   key=configured
  lending-team           product=premium    key=configured
```

4. Open `http://localhost:8100` in your browser.

### Step 4 — Tour the UI

- **1. Choose a product** — Select Free, Standard, or Premium. The subscription list shows only that product's teams.
- **2. Choose a subscription** — Select the team whose key is used for the requests.
- **3. Send requests** — Edit the prompt, set **Max tokens** and **Burst size**, then select **Send 1 request** or **Run burst**. Select **Stop** to end a burst early.
- **Make every prompt unique** — Adds a request ID to each prompt so the APIM response cache doesn't answer it. Keep it selected for rate-limit demos.
- **Token budget** — Remaining tokens this minute for the selected team, as reported by the gateway's `x-tokens-remaining` header, plus counts of successful, throttled, and failed requests.
- **Team overview** — All teams side by side. Select a row to switch to that team.
- **Request log** — Every request with status, tokens consumed, remaining tokens, the backend region chosen by the load balancer, latency, and the trace ID.
- **Last response** — The model's answer, or the gateway's error message.

### Step 5 — Run the Demo

1. **Throttle the Free tier**
   1. Select **Free**, then **Rate Limit Tester**.
   2. Set **Burst size** to `5` and select **Run burst**.
   3. Point out the results:
      - The first request or two return `200`, and the budget drops toward `0` of `500`.
      - The next requests return `429` in a few milliseconds. The gateway rejects them before they reach Azure OpenAI, so they cost nothing.
      - The red banner counts down until the token counter resets.
      - **Last response** shows the policy's message: *Your team has exceeded its token rate limit*.

2. **Show that teams are isolated**
   1. While Free is still throttled, select **Standard**, then **Member Services**.
   2. Select **Run burst**.
   3. All requests return `200`. The **Team overview** shows Rate Limit Tester as *Throttled* and Member Services as *Available* at the same time.

3. **Show the Premium tier**
   1. Select **Premium**, then **Lending Team**.
   2. Set **Burst size** to `10` and select **Run burst**.
   3. All requests return `200`, and the remaining budget stays near `200,000`.

4. **Show the reset**
   1. Wait until the Free tier's countdown banner disappears (about 60 seconds).
   2. Select **Free**, then **Rate Limit Tester**, and select **Send 1 request**. It returns `200` again.

5. **Optional — show multi-region load balancing**
   - In the **Request log**, the **Region** column alternates between `eastus` and `westus`. The policy sends about 70% of requests to the primary region and 30% to the secondary region.

### Step 6 — Show the Telemetry in Application Insights

Every request through the gateway is logged to Application Insights. The policy also emits token metrics with the team, model, and backend region as dimensions.

- Request logs appear within 1–3 minutes. Token metrics can take up to 5 minutes.
- Token metrics need two settings that the Bicep deployment applies: `metrics: true` on the APIM Application Insights diagnostic, and **Custom metrics (Preview) → With dimensions** on Application Insights (**Usage and estimated costs**). If token queries return no rows, confirm both settings and send new requests; metrics sent before the settings were enabled are not recorded.

1. In the Azure portal, open the Application Insights resource (`appi-<environmentName>`) and select **Logs**.
2. Show requests, throttling, and latency per team:

```kusto
requests
| where timestamp > ago(1h)
| extend Team = tostring(customDimensions["Subscription Name"])
| summarize Requests = count(), Succeeded = countif(resultCode == "200"), Throttled = countif(resultCode == "429"), AvgLatencyMs = round(avg(duration), 0) by Team
| order by Requests desc
```

   - Throttled requests have a latency of a few milliseconds, because the gateway rejects them without calling Azure OpenAI.

3. Show token consumption per team (the basis for chargeback):

```kusto
customMetrics
| where timestamp > ago(1h) and name in ("Prompt Tokens", "Completion Tokens", "Total Tokens")
| extend Team = tostring(customDimensions.TenantName)
| summarize Tokens = sum(valueSum) by Team, name
| evaluate pivot(name, sum(Tokens))
```

4. Show how traffic is split between the regions:

```kusto
customMetrics
| where timestamp > ago(1h) and name == "Total Tokens"
| extend Region = tostring(customDimensions.BackendRegion)
| summarize Tokens = sum(valueSum), Calls = sum(valueCount) by Region
```

5. Trace a single request end to end:
   1. Copy a **Trace ID** from the app's **Request log**.
   2. Run this query, replacing the ID:

```kusto
let traceId = "<trace-id>";
let op = toscalar(requests | where tostring(customDimensions["Request Id"]) == traceId | project operation_Id);
union requests, dependencies
| where operation_Id == op
| project timestamp, itemType, name, target, resultCode, duration
| order by timestamp asc
```

   3. The result shows the gateway request and the backend call to Azure OpenAI. The dependency `target` shows which regional endpoint served it, matching the **Region** column in the app.

6. Optionally, open **Metrics**, set the namespace to `macu-ai-gateway`, choose the **Total Tokens** metric, and select **Apply splitting** by **TenantName** for a token chart per team.

### Step 7 — Add or Change a Team (Optional)

1. Create the subscription in APIM first. To keep it in Bicep, add it to the `teamSubscriptions` parameter and re-run the deployment.
2. Add the subscription name to `SUBSCRIPTIONS` in `.env`.
3. Add its `DISPLAY_NAME`, `PRODUCT`, and `KEY` variables.
4. Restart the app (`Ctrl+C`, then `npm start`).

- If you move a team to a different product in APIM, update its `SUBSCRIPTION_<NAME>_PRODUCT` value too. Otherwise the UI shows the wrong tier label, even though APIM applies the correct limit.
- To add a new product, add it in Bicep and in the policy's token-limit `choose` block, then add it to `PRODUCTS` in `.env` with its `DISPLAY_NAME` and `TPM`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Configuration error: ... is not set in .env` when starting | Complete Step 2. The app stops at startup if the gateway URL, products, or subscriptions are missing. |
| `..._PRODUCT must be one of: free, standard, premium` | The subscription's `PRODUCT` value must match an ID in `PRODUCTS`. |
| Subscription shows **key missing** | Set its `SUBSCRIPTION_<NAME>_KEY` value in `.env` and restart the app. |
| `HTTP 401: Access denied due to invalid subscription key` | The key is wrong or was regenerated. Run the Step 2 script again. |
| Free tier never returns `429` | Confirm the subscription is scoped to `/products/free` (README Step 8). An API-scoped subscription always gets the Standard limit. Also keep **Make every prompt unique** selected, because cached answers don't use tokens. |
| `Could not reach the APIM gateway: SELF_SIGNED_CERT_IN_CHAIN` | Set `$env:NODE_USE_SYSTEM_CA = "1"` in the same window before `npm start` (Node.js 24). |
| `EADDRINUSE` on port 8100 | Change `PORT` in `.env`, or stop the process that uses the port. |
