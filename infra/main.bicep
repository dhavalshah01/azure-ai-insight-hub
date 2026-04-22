targetScope = 'resourceGroup'

@description('Environment name prefix for all resources')
param environmentName string

@description('Primary Azure region')
param location string

@description('Secondary Azure region for multi-region OpenAI')
param secondaryLocation string

@description('APIM publisher email')
param apimPublisherEmail string

@description('APIM publisher name')
param apimPublisherName string

// ============================================================
// Module: Monitoring (App Insights + Log Analytics)
// ============================================================
module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    environmentName: environmentName
    location: location
  }
}

// ============================================================
// Module: Azure OpenAI (Primary - East US)
// ============================================================
module openaiPrimary './modules/openai.bicep' = {
  name: 'openai-primary'
  params: {
    environmentName: environmentName
    location: location
    isPrimary: true
  }
}

// ============================================================
// Module: Azure OpenAI (Secondary - West US)
// ============================================================
module openaiSecondary './modules/openai.bicep' = {
  name: 'openai-secondary'
  params: {
    environmentName: environmentName
    location: secondaryLocation
    isPrimary: false
  }
}

// ============================================================
// Module: Azure AI Search (for RAG pipeline)
// ============================================================
module search './modules/search.bicep' = {
  name: 'search'
  params: {
    environmentName: environmentName
    location: location
  }
}

// ============================================================
// Module: API Management (AI Gateway)
// ============================================================
module apim './modules/apim.bicep' = {
  name: 'apim'
  params: {
    environmentName: environmentName
    location: location
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    appInsightsId: monitoring.outputs.appInsightsId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
  }
}

// ============================================================
// Module: Observability Workbook Dashboard
// ============================================================
module workbook './modules/workbook.bicep' = {
  name: 'workbook'
  params: {
    environmentName: environmentName
    location: location
    appInsightsId: monitoring.outputs.appInsightsId
  }
}

// ============================================================
// Outputs
// ============================================================
output apimGatewayUrl string = apim.outputs.gatewayUrl
output apimName string = apim.outputs.apimName
output apimPrincipalId string = apim.outputs.principalId
output appInsightsConnectionString string = monitoring.outputs.connectionString
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
output openaiPrimaryEndpoint string = openaiPrimary.outputs.endpoint
output openaiSecondaryEndpoint string = openaiSecondary.outputs.endpoint
output searchEndpoint string = search.outputs.endpoint
