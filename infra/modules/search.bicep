@description('Environment name prefix')
param environmentName string

@description('Azure region')
param location string

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: 'srch-${environmentName}'
  location: location
  sku: {
    name: 'basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    semanticSearch: 'standard'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
}

output endpoint string = 'https://${search.name}.search.windows.net'
output searchId string = search.id
output searchName string = search.name
