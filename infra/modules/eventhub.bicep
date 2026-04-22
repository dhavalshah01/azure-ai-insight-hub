@description('Environment name prefix')
param environmentName string

@description('Azure region')
param location string

// Event Hub Namespace
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: 'evhns-${environmentName}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 4
  }
}

// Event Hub for App Insights logs
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: 'appinsights-logs'
  properties: {
    partitionCount: 4
    messageRetentionInDays: 3
  }
}

// Consumer group for log consumers
resource consumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  parent: eventHub
  name: 'log-consumer'
}

// Authorization rule for sending logs
resource sendRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  parent: eventHubNamespace
  name: 'appinsights-send'
  properties: {
    rights: [
      'Send'
    ]
  }
}

// Authorization rule for consumers to listen
resource listenRule 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  parent: eventHubNamespace
  name: 'log-listen'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

output namespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output sendRuleId string = sendRule.id
output listenRuleId string = listenRule.id
