@description('Environment name prefix')
param environmentName string

@description('Azure region')
param location string

@description('Is this the primary deployment?')
param isPrimary bool

@description('Deployment SKU for the gpt-4o chat model')
param chatModelSku string

@description('Capacity for the gpt-4o chat model, in thousands of tokens per minute')
param chatModelCapacity int

@description('Deployment SKU for the text-embedding-ada-002 model')
param embeddingModelSku string

@description('Capacity for the text-embedding-ada-002 model, in thousands of tokens per minute')
param embeddingModelCapacity int

var suffix = isPrimary ? 'primary' : 'secondary'

// Azure OpenAI Account
resource openai 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: 'aoai-${environmentName}-${suffix}'
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: 'aoai-${environmentName}-${suffix}'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true  // Enforce keyless access via Entra ID
  }
}

// GPT-4o Deployment
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openai
  name: 'gpt-4o'
  sku: {
    name: chatModelSku
    capacity: chatModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-11-20'
    }
  }
}

// Embeddings Deployment (needed for semantic caching + RAG)
resource embeddingsDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openai
  name: 'text-embedding-ada-002'
  sku: {
    name: embeddingModelSku
    capacity: embeddingModelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-ada-002'
      version: '2'
    }
  }
  dependsOn: [gpt4oDeployment]  // Serial deployment to avoid conflicts
}

output endpoint string = openai.properties.endpoint
output openaiId string = openai.id
output openaiName string = openai.name
output principalId string = openai.identity.principalId
