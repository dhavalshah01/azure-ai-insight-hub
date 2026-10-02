@description('Primary Azure OpenAI account name')
param openaiPrimaryName string

@description('Secondary Azure OpenAI account name')
param openaiSecondaryName string

@description('Azure AI Search service name')
param searchName string

@description('Principal ID of the APIM system-assigned managed identity')
param apimPrincipalId string

@description('Principal ID that needs Azure AI Search index and data access (the user running the agent apps)')
param searchDataPrincipalId string

// Built-in role definition IDs
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
var searchServiceContributorRoleId = '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'

resource openaiPrimary 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: openaiPrimaryName
}

resource openaiSecondary 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: openaiSecondaryName
}

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: searchName
}

// APIM managed identity -> Azure OpenAI (keyless calls from the gateway)
resource apimOpenaiPrimaryRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openaiPrimary.id, apimPrincipalId, cognitiveServicesOpenAIUserRoleId)
  scope: openaiPrimary
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource apimOpenaiSecondaryRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openaiSecondary.id, apimPrincipalId, cognitiveServicesOpenAIUserRoleId)
  scope: openaiSecondary
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// App user -> Azure AI Search (create the index, upload and query documents)
resource searchServiceContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, searchDataPrincipalId, searchServiceContributorRoleId)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchServiceContributorRoleId)
    principalId: searchDataPrincipalId
  }
}

resource searchIndexDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, searchDataPrincipalId, searchIndexDataContributorRoleId)
  scope: search
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: searchDataPrincipalId
  }
}
