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

@description('Object ID granted Azure AI Search access for the sample apps. Leave empty to use the identity running the deployment.')
param searchDataPrincipalId string = ''

@description('Name of the APIM subscription created for the workshop agent app')
param agentSubscriptionName string = 'workshop-agent'

@description('Per-team APIM subscriptions for the multi-tenancy demo. productId must be free, standard, or premium.')
param teamSubscriptions array = [
  {
    name: 'rate-limit-tester'
    displayName: 'Rate Limit Tester'
    productId: 'free'
  }
  {
    name: 'member-services'
    displayName: 'Member Services'
    productId: 'standard'
  }
  {
    name: 'digital-banking'
    displayName: 'Digital Banking'
    productId: 'standard'
  }
  {
    name: 'lending-team'
    displayName: 'Lending Team'
    productId: 'premium'
  }
]

@description('Deployment SKU for gpt-4o. GlobalStandard has the widest default quota; use DataZoneStandard to keep processing within the US/EU data zone.')
@allowed([
  'Standard'
  'GlobalStandard'
  'DataZoneStandard'
])
param chatModelSku string = 'GlobalStandard'

@description('gpt-4o capacity per region, in thousands of tokens per minute (TPM)')
@minValue(1)
param chatModelCapacity int = 30

@description('Deployment SKU for text-embedding-ada-002')
@allowed([
  'Standard'
  'GlobalStandard'
  'DataZoneStandard'
])
param embeddingModelSku string = 'Standard'

@description('text-embedding-ada-002 capacity per region, in thousands of tokens per minute (TPM)')
@minValue(1)
param embeddingModelCapacity int = 30

var effectiveSearchDataPrincipalId = empty(searchDataPrincipalId) ? deployer().objectId : searchDataPrincipalId

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
    chatModelSku: chatModelSku
    chatModelCapacity: chatModelCapacity
    embeddingModelSku: embeddingModelSku
    embeddingModelCapacity: embeddingModelCapacity
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
    chatModelSku: chatModelSku
    chatModelCapacity: chatModelCapacity
    embeddingModelSku: embeddingModelSku
    embeddingModelCapacity: embeddingModelCapacity
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
    openaiPrimaryName: openaiPrimary.outputs.openaiName
    openaiSecondaryName: openaiSecondary.outputs.openaiName
    agentSubscriptionName: agentSubscriptionName
    teamSubscriptions: teamSubscriptions
  }
}

// ============================================================
// Module: RBAC (APIM -> OpenAI, app user -> AI Search)
// ============================================================
module roleAssignments './modules/role-assignments.bicep' = {
  name: 'role-assignments'
  params: {
    openaiPrimaryName: openaiPrimary.outputs.openaiName
    openaiSecondaryName: openaiSecondary.outputs.openaiName
    searchName: search.outputs.searchName
    apimPrincipalId: apim.outputs.principalId
    searchDataPrincipalId: effectiveSearchDataPrincipalId
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
output apimApiName string = apim.outputs.apiName
output apimAgentSubscriptionName string = apim.outputs.agentSubscriptionName
output apimProductIds array = apim.outputs.productIds
output apimTeamSubscriptionNames array = apim.outputs.teamSubscriptionNames
output appInsightsConnectionString string = monitoring.outputs.connectionString
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
output openaiPrimaryEndpoint string = openaiPrimary.outputs.endpoint
output openaiSecondaryEndpoint string = openaiSecondary.outputs.endpoint
output searchEndpoint string = search.outputs.endpoint
output searchName string = search.outputs.searchName
