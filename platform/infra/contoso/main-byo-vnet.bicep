import { contosoDeployTogglesType, resourceIdType } from 'common/types.bicep'

// param deployToggles baseDeployToggles
param contosoToggles contosoDeployTogglesType
param resourceIds resourceIdType

var deployAppService = contosoToggles.?appService ?? false
var deploySql = contosoToggles.?azureSql ?? false
var deployJumpBox = contosoToggles.jumpBox ?? false
var deploySearch = contosoToggles.searchService ?? false

@description('Optional. Location')
param location string = 'swedencentral'

@description('Optional. Deterministic token for resource names; auto-generated if not provided.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

@description('Optional. Base name to seed resource names; defaults to a 12-char token.')
param baseName string = substring(resourceToken, 0, 12)

@description('Required. Name or Resource ID of existing VNet (with subnets already created)')
param existingVNetName string

var existingVNetResourceId = contains(existingVNetName, '/')
  ? existingVNetName
  : resourceId('Microsoft.Network/virtualNetworks', existingVNetName)

var includeSqlSubnet = deploySql
var includeAppServiceSubnet = deployAppService

var includeJumpBoxAndBastionSubnet = deployJumpBox

//'192.168.0.0/24'
var baseAddressPrefix = vnet.properties.addressSpace.addressPrefixes[0]

var privateEndpointSubnetCidr = cidrSubnet(baseAddressPrefix, 3, 0)
var appServiceSubnetCidr = cidrSubnet(baseAddressPrefix, 3, 1)
var sqlSubnetCidr = cidrSubnet(baseAddressPrefix, 3, 2)
var jumpboxSubnetCidr = cidrSubnet(baseAddressPrefix, 3, 3)
var azureBastionSubnetCidr = cidrSubnet(baseAddressPrefix, 3, 4)

var byoDefaultSubnets = concat(
  [],
  includeJumpBoxAndBastionSubnet
    ? [
        {
          name: 'jumpbox-subnet'
          addressPrefix: jumpboxSubnetCidr
        }
        {
          name: 'AzureBastionSubnet'
          addressPrefix: azureBastionSubnetCidr
        }
      ]
    : [],
  includeAppServiceSubnet
    ? [
        {
          name: 'appservice-subnet'
          addressPrefix: appServiceSubnetCidr
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegation: 'Microsoft.Web/serverFarms'
        }
      ]
    : [],
  [
    {
      name: 'pe-subnet'
      addressPrefix: privateEndpointSubnetCidr
      privateEndpointNetworkPolicies: 'Disabled'
      serviceEndpoints: [
        {
          service: 'Microsoft.AzureCosmosDB'
        }
      ]
    }
  ],
  includeSqlSubnet
    ? [
        {
          name: 'sql-subnet'
          addressPrefix: sqlSubnetCidr
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      ]
    : []
)

// ===================================
// BYO VNET CONFIGURATION
// ===================================

resource vnet 'Microsoft.Network/virtualNetworks@2024-10-01' existing = {
  name: existingVNetName
}

// Reference the base AILZ infrastructure with existing VNet
// IMPORTANT: VNet and all subnets must already exist (deploy vnet-prerequisites.bicep first)
module baseInfra '../../../bicep/deploy/main.bicep' = {
  name: 'ailz-base-infrastructure'
  params: {
    deployToggles: {
      virtualNetwork: false // Don't create new VNet - use existing
      acaEnvironmentNsg: false
      agentNsg: true
      apiManagement: false
      apiManagementNsg: false
      appConfig: true
      appInsights: true
      applicationGateway: false
      applicationGatewayNsg: false
      applicationGatewayPublicIp: false
      bastionHost: true
      bastionNsg: true
      buildVm: false
      containerApps: false
      containerEnv: false
      containerRegistry: true
      cosmosDb: false
      devopsBuildAgentsNsg: false
      firewall: false
      groundingWithBingSearch: true
      jumpVm: true
      jumpboxNsg: true
      keyVault: true
      logAnalytics: true
      peNsg: true
      searchService: true
      storageAccount: true
      virtualNetwork: false
      wafPolicy: false
    }
    resourceIds: union(resourceIds, {
      virtualNetworkResourceId: existingVNetResourceId
    })
    location: location
    existingVNetSubnetsDefinition: {
      existingVNetName: existingVNetName
      useDefaultSubnets: false
      subnets: byoDefaultSubnets
    }
    aiSearchDefinition: deploySearch ? {
      name: 'search-${baseName}'
      sku: 'standard'
      replicaCount: 1
    } : {}

    // AILZ will use existing subnets (no subnet creation)
    // Subnets must already exist in the VNet:
    // - agent-subnet, pe-subnet, appgw-subnet, AzureBastionSubnet, AzureFirewallSubnet
    // - apim-subnet, jumpbox-subnet, aca-env-subnet, devops-agents-subnet
    // - sql-subnet (if deploySql=true), appservice-subnet (if deployAppService=true)
  }
}

// ===================================
// CONTOSO RESOURCES - AZURE SQL
// ===================================

module sqlServer 'br/public:avm/res/sql/server:0.9.0' = if (deploySql) {
  name: 'sql-${baseName}'
  params: {
    name: 'sql-${baseName}'
    location: location
    // Azure AD-only authentication (required by policy)
    administrators: {
      azureADOnlyAuthentication: true
      login: 'SQL Admins' // Azure AD group or user display name
      sid: '00000000-0000-0000-0000-000000000000' // TODO: Replace with your Azure AD group/user object ID
      principalType: 'Group' // or 'User'
      tenantId: subscription().tenantId
    }
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'

    databases: [
      {
        name: 'db-contoso'
        skuName: 'Basic'
        skuTier: 'Basic'
      }
    ]

    managedIdentities: {
      systemAssigned: true
    }
  }
  dependsOn: [
    baseInfra // Wait for subnets to be created
  ]
}

// SQL Private Endpoint
module sqlPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.9.0' = if (deploySql) {
  name: 'pe-sql-${baseName}'
  params: {
    name: 'pe-sql-${baseName}'
    location: location
    // Use AILZ private endpoint subnet (created by baseInfra with default subnets)
    subnetResourceId: '${baseInfra.outputs.virtualNetworkResourceId}/subnets/pe-subnet'

    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServer.outputs.resourceId
          groupIds: ['sqlServer']
        }
      }
    ]

    // TODO: Integrate with AILZ-managed Private DNS Zone if available
    customNetworkInterfaceName: 'nic-pe-sql-${baseName}'
  }
}

// ===================================
// CONTOSO RESOURCES - APP SERVICE
// ===================================

// App Service Plan
module serverfarm 'br/public:avm/res/web/serverfarm:0.5.0' = if (deployAppService) {
  name: 'serverfarmDeployment'
  params: {
    // Required parameters
    name: 'asp-${baseName}'
    // Non-required parameters
    kind: 'linux'
    zoneRedundant: false
    skuName: 'P1v3' // Premium V3 required for VNet integration
    skuCapacity: 1 // Minimum 2 workers required for zone redundancy
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'Contoso App Service Plan'
      Role: 'DeploymentValidation'
    }
  }
}

module website 'br/public:avm/res/web/site:0.19.4' = if (deployAppService) {
  name: 'siteDeployment'
  params: {
    // Required parameters
    kind: 'app'
    name: 'app-${baseName}'
    serverFarmResourceId: deployAppService ? serverfarm.outputs.resourceId : ''

    // Non-required parameters
    location: location
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: false
        name: 'scm'
      }
    ]
    httpsOnly: true

    // VNet Integration for outbound traffic
    virtualNetworkSubnetResourceId: deployAppService
      ? '${baseInfra.outputs.virtualNetworkResourceId}/subnets/appservice-subnet'
      : ''

    publicNetworkAccess: 'Disabled'
    scmSiteAlsoStopped: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'
      healthCheckPath: '/healthz'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnetcore'
        }
      ]
      minTlsVersion: '1.2'
      vnetRouteAllEnabled: true // Force all traffic through VNet
      http20Enabled: true
      // SQL Connection String (using managed identity)
      connectionStrings: deploySql
        ? [
            {
              name: 'DefaultConnection'
              connectionString: 'Server=tcp:sql-${baseName}.database.windows.net,1433;Database=db-contoso;Authentication=Active Directory Managed Identity;'
              type: 'SQLAzure'
            }
          ]
        : []
    }

    managedIdentities: {
      systemAssigned: true
    }
  }
  dependsOn: [
    baseInfra // Ensure subnet exists
    sqlPrivateEndpoint // Ensure SQL is accessible before app starts
  ]
}

// App Service Private Endpoint (for inbound HTTPS traffic)
module appServicePrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.9.0' = if (deployAppService) {
  name: 'pe-app-${baseName}'
  params: {
    name: 'pe-app-${baseName}'
    location: location
    subnetResourceId: '${baseInfra.outputs.virtualNetworkResourceId}/subnets/pe-subnet'

    privateLinkServiceConnections: [
      {
        name: 'appservice-connection'
        properties: {
          privateLinkServiceId: deployAppService ? website.outputs.resourceId : ''
          groupIds: ['sites']
        }
      }
    ]

    // TODO: Integrate with AILZ-managed Private DNS Zone if available
    customNetworkInterfaceName: 'nic-pe-app-${baseName}'
  }
}

// ===================================
// OUTPUTS
// ===================================

@description('The resource ID of the existing VNet being used')
output virtualNetworkResourceId string = baseInfra.outputs.virtualNetworkResourceId

@description('SQL Server resource ID')
output sqlServerResourceId string = deploySql ? sqlServer.outputs.resourceId : ''

@description('App Service resource ID')
output appServiceResourceId string = deployAppService ? website.outputs.resourceId : ''
