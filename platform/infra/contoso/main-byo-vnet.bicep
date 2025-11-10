import { baseDeployToggles, contosoDeployTogglesType,resourceIdType } from 'common/types.bicep'

param deployToggles baseDeployToggles
param contosoToggles contosoDeployTogglesType
param resourceIds resourceIdType

var deployAppService = contosoToggles.?appService ?? false
var deploySql = contosoToggles.?azureSql ?? false

@description('Optional. Location')
param location string = 'swedencentral'

@description('Optional. Deterministic token for resource names; auto-generated if not provided.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

@description('Optional. Base name to seed resource names; defaults to a 12-char token.')
param baseName string = substring(resourceToken, 0, 12)

@description('Required. Name or Resource ID of existing VNet')
param existingVNetName string

// ===================================
// CONTOSO CUSTOM NSGS
// ===================================

// SQL Subnet NSG
module sqlNsg 'br/public:avm/res/network/network-security-group:0.5.0' = if (deploySql) {
  name: 'nsg-sql-${baseName}'
  params: {
    name: 'nsg-sql-${baseName}'
    location: location
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// App Service Subnet NSG
module appServiceNsg 'br/public:avm/res/network/network-security-group:0.5.0' = if (deployAppService) {
  name: 'nsg-appservice-${baseName}'
  params: {
    name: 'nsg-appservice-${baseName}'
    location: location
    securityRules: [
      {
        name: 'AllowAppServiceManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['454', '455']
          sourceAddressPrefix: 'AppServiceManagement'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ===================================
// CONTOSO CUSTOM SUBNETS
// ===================================

// All subnets for BYO VNet scenario (AILZ defaults + Contoso custom)
// Must provide ALL subnets upfront when useDefaultSubnets=false
var allSubnets = concat(
  [
    // AILZ Default Subnets (required for platform functionality)
    {
      name: 'agent-subnet'
      addressPrefix: '192.168.0.0/25'  // 128 IPs (192.168.0.0-127)
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.CognitiveServices']
    }
    {
      name: 'pe-subnet'
      addressPrefix: '192.168.0.128/26'  // 64 IPs (192.168.0.128-191) - MOVED to avoid conflict
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
      privateEndpointNetworkPolicies: 'Disabled'
    }
    {
      name: 'appgw-subnet'
      addressPrefix: '192.168.0.192/26'  // 64 IPs (192.168.0.192-255)
    }
    {
      name: 'AzureBastionSubnet'
      addressPrefix: '192.168.1.0/26'  // 64 IPs (192.168.1.0-63)
    }
    {
      name: 'AzureFirewallSubnet'
      addressPrefix: '192.168.1.192/26'  // 64 IPs (192.168.1.192-255) - MOVED
    }
    {
      name: 'apim-subnet'
      addressPrefix: '192.168.1.128/27'  // 32 IPs (192.168.1.128-159)
    }
    {
      name: 'jumpbox-subnet'
      addressPrefix: '192.168.1.160/28'  // 16 IPs (192.168.1.160-175)
    }
    {
      name: 'aca-env-subnet'
      addressPrefix: '192.168.1.176/28'  // 16 IPs (192.168.1.176-191)
      delegation: 'Microsoft.App/environments'
      serviceEndpoints: ['Microsoft.AzureCosmosDB']
    }
    {
      name: 'devops-agents-subnet'
      addressPrefix: '192.168.1.144/28'  // 16 IPs (192.168.1.144-159) - MOVED
    }
  ],
  // Contoso Custom Subnets (conditional based on toggles)
  deploySql ? [{
    name: 'sql-subnet'
    addressPrefix: '192.168.1.64/27'  // 32 IPs (192.168.1.64-95)
    networkSecurityGroupResourceId: sqlNsg!.outputs.resourceId
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }] : [],
  deployAppService ? [{
    name: 'appservice-subnet'
    addressPrefix: '192.168.1.96/27'  // 32 IPs (192.168.1.96-127)
    networkSecurityGroupResourceId: appServiceNsg!.outputs.resourceId
    delegation: 'Microsoft.Web/serverFarms'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }] : []
)

// ===================================
// BYO VNET CONFIGURATION
// ===================================

// Reference the base AILZ infrastructure with existing VNet
module baseInfra '../../../bicep/deploy/main.bicep' = {
  name: 'ailz-base-infrastructure'
  params: {
    deployToggles: union(deployToggles, {
      virtualNetwork: false  // Don't create new VNet
    })
    resourceIds: union(resourceIds, {
      virtualNetworkResourceId: contains(existingVNetName, '/') 
        ? existingVNetName  // Full resource ID provided
        : resourceId('Microsoft.Network/virtualNetworks', existingVNetName)  // Just name provided
    })
    location: location
    
    // Configure subnets for existing VNet
    // Use complete subnet list (AILZ defaults + Contoso custom) deployed upfront
    existingVNetSubnetsDefinition: {
      existingVNetName: existingVNetName
      useDefaultSubnets: false  // false = provide complete subnet list
      subnets: allSubnets  // All subnets (AILZ + Contoso) deployed together
    }
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
      login: 'SQL Admins'  // Azure AD group or user display name
      sid: '00000000-0000-0000-0000-000000000000'  // TODO: Replace with your Azure AD group/user object ID
      principalType: 'Group'  // or 'User'
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
    baseInfra  // Wait for subnets to be created
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
    zoneRedundant:false
    skuName: 'P1v3'  // Premium V3 required for VNet integration
    skuCapacity: 1  // Minimum 2 workers required for zone redundancy
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
    virtualNetworkSubnetResourceId: deployAppService ? '${baseInfra.outputs.virtualNetworkResourceId}/subnets/appservice-subnet' : ''
    
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
      vnetRouteAllEnabled: true  // Force all traffic through VNet
      http20Enabled: true
      // SQL Connection String (using managed identity)
      connectionStrings: deploySql ? [
        {
          name: 'DefaultConnection'
          connectionString: 'Server=tcp:sql-${baseName}.database.windows.net,1433;Database=db-contoso;Authentication=Active Directory Managed Identity;'
          type: 'SQLAzure'
        }
      ] : []
    }
    
    managedIdentities: {
      systemAssigned: true
    }
  }
  dependsOn: [
    baseInfra  // Ensure subnet exists
    sqlPrivateEndpoint  // Ensure SQL is accessible before app starts
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
