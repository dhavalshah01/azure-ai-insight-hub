@description('Log Analytics Workspace resource ID')
param workspaceId string

@description('Event Hub authorization rule ID for sending')
param eventHubAuthRuleId string

@description('Event Hub name')
param eventHubName string

@description('Environment name')
param environmentName string

// Reference existing Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'log-${environmentName}'
}

// Diagnostic setting: Export to Event Hub
resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'export-to-eventhub'
  scope: logAnalytics
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthRuleId
    eventHubName: eventHubName
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
