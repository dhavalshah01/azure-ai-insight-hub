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

output gatewayUrl string = apim.properties.gatewayUrl
output apimName string = apim.name
output principalId string = apim.identity.principalId
