# AI/ML Landing Zone — Bicep parameter examples

This page provides three complete examples of parameter files for deploying the AI/ML Landing Zone (Bicep AVM).

## Table of Contents

1. [Greenfield — full new and isolated deployment](#1-greenfield--full-new-and-isolated-deployment)
2. [Existing VNet — reuse an existing virtual network](#2-existing-vnet--reuse-an-existing-virtual-network)
3. [Platform Landing Zone — PDNS/PE managed by the platform](#3-platform-landing-zone--pdnspe-managed-by-the-platform)

---

## 1. Greenfield — full new and isolated deployment

Use this scenario for a **new environment from scratch**.
It creates all required resources — Virtual Network, Network Security Groups, Private Endpoints, Private DNS Zones, and the entire AI/ML stack (App Gateway, APIM, Firewall, AI services, etc.).
This is the default “everything on” template.

```bicep
using './main.bicep'

@description('Per-service deployment toggles.')
param deployToggles = {
  acaEnvironmentNsg: true
  agentNsg: true
  apiManagement: true
  apiManagementNsg: true
  appConfig: true
  appInsights: true
  applicationGateway: true
  applicationGatewayNsg: true
  applicationGatewayPublicIp: true
  bastionHost: true
  buildVm: true
  containerApps: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  devopsBuildAgentsNsg: true
  firewall: true
  groundingWithBingSearch: true
  jumpVm: true
  jumpboxNsg: true
  keyVault: true
  logAnalytics: true
  peNsg: true
  searchService: true
  storageAccount: true
  virtualNetwork: true
  wafPolicy: true
}

@description('Existing resource IDs (empty means create new).')
param resourceIds = {}

@description('Enable platform landing zone integration. When true, private DNS zones and private endpoints are managed by the platform landing zone.')
param flagPlatformLandingZone = false
```

---

## 2. Existing VNet — reuse an existing virtual network

Use this when you already have a **pre-existing VNet** and only need to add the AI/ML Landing Zone subnets and resources.
The deployment **does not create a new VNet**; instead, it creates required subnets and NSGs inside the specified VNet, while still deploying platform services like Cosmos DB, Storage, Key Vault, App Insights, Log Analytics, and Container Registry/Env.
**In this example, it is assumed that the existing VNet has the address space `192.168.0.0/22` (or equivalent prefixes consistently adjusted), since the subnets below follow this structure.**
Infra such as App Gateway, APIM, Firewall, Bastion, and Jumpbox is skipped.

```bicep
using './main.bicep'

@description('Deploy services while reusing an existing VNet; create only the needed subnets + NSGs.')
param deployToggles = {
  // Application and data services
  logAnalytics: true
  appInsights: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  keyVault: true
  storageAccount: true
  appConfig: true

  // Infra components not deployed in this scenario
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  firewall: false
  wafPolicy: false
  buildVm: false
  bastionHost: false
  jumpVm: false

  // NSGs for subnets created
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: false
  apiManagementNsg: false
  acaEnvironmentNsg: true
  jumpboxNsg: false
  devopsBuildAgentsNsg: true

  // VNet already exists
  virtualNetwork: false
}

@description('Reference to the existing VNet and subnets to create.')
param existingVNetSubnetsDefinition = {
  existingVNetName: 'your-existing-vnet-name'
  useDefaultSubnets: false
  subnets: [
    {
      name: 'agent-subnet'
      addressPrefix: '192.168.0.0/27'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
    }
    {
      name: 'pe-subnet'
      addressPrefix: '192.168.0.32/27'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
      privateEndpointNetworkPolicies: 'Disabled'
    }
    {
      name: 'aca-env-subnet'
      addressPrefix: '192.168.2.0/23'
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    {
      name: 'devops-agents-subnet'
      addressPrefix: '192.168.1.32/27'
    }
    // Other infra subnets (AppGW, Bastion, Firewall, Jumpbox, APIM) omitted here
  ]
}
```

---

## 3. Platform Landing Zone — PDNS/PE managed by the platform

Choose this scenario when your **platform landing zone already manages Private DNS Zones and Private Endpoints**.
The AI/ML Landing Zone consumes the existing DNS zones you provide and does not create new ones.
You still deploy platform services like Cosmos DB, Storage, Key Vault, App Insights, Log Analytics, and Container Registry/Env, but network infra such as App Gateway, APIM, Firewall, Bastion, and Jumpbox is skipped.

```bicep
using './main.bicep'

@description('Deploy core services while reusing platform-managed PDNS/PE.')
param deployToggles = {
  // Application and data services
  logAnalytics: true
  appInsights: true
  containerEnv: true
  containerRegistry: true
  cosmosDb: true
  keyVault: true
  storageAccount: true
  appConfig: true

  // Infra components managed by platform or excluded
  apiManagement: false
  applicationGateway: false
  applicationGatewayPublicIp: false
  firewall: false
  wafPolicy: false
  buildVm: false
  bastionHost: false
  jumpVm: false

  // NSGs still required for local subnets
  agentNsg: true
  peNsg: true
  applicationGatewayNsg: false
  apiManagementNsg: false
  acaEnvironmentNsg: true
  jumpboxNsg: false
  devopsBuildAgentsNsg: true

  // Workload VNet created if pattern requires isolation
  virtualNetwork: true
}

@description('Enable platform landing zone integration.')
param flagPlatformLandingZone = true

@description('Provide IDs of existing Private DNS Zones managed by the platform.')
param privateDnsZonesDefinition = {
  allowInternetResolutionFallback: false
  createNetworkLinks: false
  cognitiveservicesZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  openaiZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  aiServicesZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com'
  searchZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net'
  cosmosSqlZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
  blobZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  keyVaultZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
  appConfigZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azconfig.io'
  containerAppsZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.eastus2.azurecontainerapps.io'
  acrZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
  appInsightsZoneId: '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.applicationinsights.azure.com'
  tags: { ManagedBy: 'PlatformLZ' }
}
```
