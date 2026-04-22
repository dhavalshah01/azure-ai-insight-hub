@description('Environment name prefix')
param environmentName string

@description('Azure region')
param location string

@description('Application Insights resource ID')
param appInsightsId string

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid('macu-ai-observability-${environmentName}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'MACU AI Platform - Observability Dashboard'
    category: 'workbook'
    sourceId: appInsightsId
    serializedData: '''
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "# MACU AI Platform - Observability Dashboard\\n\\nEnd-to-end monitoring for the AI Gateway and RAG pipeline."
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "requests | where name contains 'openai' | summarize count(), avg(duration) by bin(timestamp, 5m) | render timechart",
        "size": 1,
        "title": "AI Gateway Request Volume & Latency",
        "timeContext": { "durationMs": 86400000 }
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "customMetrics | where name == 'Total Tokens' | summarize sum(value) by bin(timestamp, 1h) | render columnchart",
        "size": 1,
        "title": "Token Consumption Over Time",
        "timeContext": { "durationMs": 86400000 }
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "dependencies | where name == 'rag-pipeline' | summarize P50=percentile(duration, 50), P90=percentile(duration, 90), P99=percentile(duration, 99) by bin(timestamp, 15m) | render timechart",
        "size": 1,
        "title": "RAG Pipeline Latency (P50/P90/P99)",
        "timeContext": { "durationMs": 86400000 }
      }
    }
  ]
}
'''
  }
}
