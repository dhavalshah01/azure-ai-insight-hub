@description('Environment name prefix')
param environmentName string

@description('Azure region')
param location string

@description('Publisher email for APIM')
param publisherEmail string

@description('Publisher name for APIM')
param publisherName string

@description('Application Insights resource ID')
param appInsightsId string

@description('Application Insights instrumentation key')
@secure()
param appInsightsInstrumentationKey string

@description('Primary Azure OpenAI account name (also its custom subdomain)')
param openaiPrimaryName string

@description('Secondary Azure OpenAI account name (also its custom subdomain)')
param openaiSecondaryName string

@description('Name of the APIM subscription created for the workshop agent app')
param agentSubscriptionName string

@description('Team subscriptions for the multi-tenancy demo. productId must be free, standard, or premium.')
param teamSubscriptions array

// Display names must match the context.Product.Name checks in policies/ai-gateway-api.xml
var products = [
  {
    id: 'free'
    displayName: 'Free'
    description: 'Sandbox tier - 500 tokens per minute per subscription. Use it to demonstrate throttling (HTTP 429).'
  }
  {
    id: 'standard'
    displayName: 'Standard'
    description: 'Default tier - 5,000 tokens per minute per subscription.'
  }
  {
    id: 'premium'
    displayName: 'Premium'
    description: 'Priority tier - 200,000 tokens per minute per subscription.'
  }
]

var openaiPrimaryUrl = 'https://${openaiPrimaryName}.openai.azure.com'
var openaiSecondaryUrl = 'https://${openaiSecondaryName}.openai.azure.com'

// API Management Instance
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: 'apim-${environmentName}'
  location: location
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Connect APIM to Application Insights
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

// Diagnostic settings — log all API requests to App Insights
resource apimDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    // Required for azure-openai-emit-token-metric to send token metrics to Application Insights
    metrics: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: ['x-ms-client-request-id', 'traceparent']
        body: { bytes: 1024 }
      }
      response: {
        headers: ['x-ms-request-id']
        body: { bytes: 1024 }
      }
    }
    backend: {
      request: {
        headers: ['traceparent']
        body: { bytes: 1024 }
      }
      response: {
        headers: []
        body: { bytes: 1024 }
      }
    }
  }
}

// Named values referenced by policies/ai-gateway-api.xml
resource openaiPrimaryUrlNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'openai-primary-url'
  properties: {
    displayName: 'openai-primary-url'
    value: openaiPrimaryUrl
    secret: false
  }
}

resource openaiSecondaryUrlNamedValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'openai-secondary-url'
  properties: {
    displayName: 'openai-secondary-url'
    value: openaiSecondaryUrl
    secret: false
  }
}

// Service-wide policy (W3C trace propagation)
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2024-05-01' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'xml'
    value: loadTextContent('../../policies/ai-gateway-global.xml')
  }
}

// Azure OpenAI API exposed through the AI Gateway
resource openaiApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'azure-openai-api'
  properties: {
    displayName: 'Azure OpenAI API'
    path: 'openai'
    protocols: ['https']
    serviceUrl: '${openaiPrimaryUrl}/openai'
    subscriptionRequired: true
  }
}

resource chatCompletionsOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: openaiApi
  name: 'chat-completions'
  properties: {
    displayName: 'Chat Completions'
    method: 'POST'
    urlTemplate: '/deployments/{deployment-id}/chat/completions'
    templateParameters: [
      {
        name: 'deployment-id'
        type: 'string'
        required: true
      }
    ]
  }
}

resource embeddingsOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: openaiApi
  name: 'embeddings'
  properties: {
    displayName: 'Embeddings'
    method: 'POST'
    urlTemplate: '/deployments/{deployment-id}/embeddings'
    templateParameters: [
      {
        name: 'deployment-id'
        type: 'string'
        required: true
      }
    ]
  }
}

// API-level AI governance policy (auth, caching, token limits, load balancing, metrics)
resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: openaiApi
  name: 'policy'
  properties: {
    format: 'xml'
    value: loadTextContent('../../policies/ai-gateway-api.xml')
  }
  dependsOn: [
    openaiPrimaryUrlNamedValue
    openaiSecondaryUrlNamedValue
  ]
}

// API-scoped subscription used by the sample agent apps
resource agentSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: agentSubscriptionName
  properties: {
    displayName: 'Workshop Agent'
    scope: '/apis/${openaiApi.name}'
    state: 'active'
  }
}

// Tiered products (Free / Standard / Premium) that drive the token limits in the API policy
resource tierProducts 'Microsoft.ApiManagement/service/products@2024-05-01' = [
  for product in products: {
    parent: apim
    name: product.id
    properties: {
      displayName: product.displayName
      description: product.description
      state: 'published'
      subscriptionRequired: true
      approvalRequired: false
    }
  }
]

resource tierProductApis 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = [
  for (product, i) in products: {
    parent: tierProducts[i]
    name: openaiApi.name
  }
]

// Product-scoped team subscriptions, so context.Product is set when the policy runs
resource teamSubscriptionResources 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = [
  for team in teamSubscriptions: {
    parent: apim
    name: team.name
    properties: {
      displayName: team.displayName
      scope: '/products/${team.productId}'
      state: 'active'
    }
    dependsOn: [
      tierProductApis
    ]
  }
]

output gatewayUrl string = apim.properties.gatewayUrl
output apimName string = apim.name
output principalId string = apim.identity.principalId
output apiName string = openaiApi.name
output agentSubscriptionName string = agentSubscription.name
output productIds array = [for product in products: product.id]
output teamSubscriptionNames array = [for (team, i) in teamSubscriptions: teamSubscriptionResources[i].name]
