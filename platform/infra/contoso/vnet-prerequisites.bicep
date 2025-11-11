// Pre-create VNet with all required subnets for BYO VNet scenario
// Deploy this BEFORE running main-byo-vnet.bicep
targetScope = 'resourceGroup'

@description('Required. Location for the VNet')
param location string = 'swedencentral'

@description('Optional. VNet name')
param vnetName string = 'vnet-ailz-contoso'

@description('Optional. Deploy SQL subnet')
param deploySql bool = true

@description('Optional. Deploy App Service subnet')
param deployAppService bool = true

@description('Optional. NSG resource ID for SQL subnet')
param sqlNsgResourceId string = ''

@description('Optional. NSG resource ID for App Service subnet')
param appServiceNsgResourceId string = ''



resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/22'  // 1024 IPs total
      ]
    }
    subnets: concat(
      [
        // AILZ Default Subnets
          {
          name: 'agent-subnet'
          properties: {
            addressPrefix: '192.168.0.0/25'  // 128 IPs (192.168.0.0-127)
            delegations: [
              {
                name: 'Microsoft.App.environments'
                properties: {
                  serviceName: 'Microsoft.App/environments'
                }
              }
            ]
            serviceEndpoints: [
              {
                service: 'Microsoft.CognitiveServices'
              }
            ]
          }
        }
        {
          name: 'pe-subnet'
          properties: {
            addressPrefix: '192.168.0.128/26'  // 64 IPs (192.168.0.128-191)
            privateEndpointNetworkPolicies: 'Disabled'
            serviceEndpoints: [
              {
                service: 'Microsoft.AzureCosmosDB'
              }
            ]
          }
        }
        {
          name: 'appgw-subnet'
          properties: {
            addressPrefix: '192.168.0.192/26'  // 64 IPs (192.168.0.192-255)
          }
        }
        {
          name: 'AzureBastionSubnet'
          properties: {
            addressPrefix: '192.168.1.0/26'  // 64 IPs (192.168.1.0-63)
          }
        }
        {
          name: 'devops-agents-subnet'
          properties: {
            addressPrefix: '192.168.1.112/28'  // 16 IPs (192.168.1.112-127)
          }
        }
        {
          name: 'apim-subnet'
          properties: {
            addressPrefix: '192.168.1.128/27'  // 32 IPs (192.168.1.128-159)
          }
        }
        {
          name: 'jumpbox-subnet'
          properties: {
            addressPrefix: '192.168.1.160/28'  // 16 IPs (192.168.1.160-175)
          }
        }
        {
          name: 'aca-env-subnet'
          properties: {
            addressPrefix: '192.168.1.176/28'  // 16 IPs (192.168.1.176-191)
            delegations: [
              {
                name: 'Microsoft.App.environments'
                properties: {
                  serviceName: 'Microsoft.App/environments'
                }
              }
            ]
            serviceEndpoints: [
              {
                service: 'Microsoft.AzureCosmosDB'
              }
            ]
          }
        }
        {
          name: 'AzureFirewallSubnet'
          properties: {
            addressPrefix: '192.168.1.192/26'  // 64 IPs (192.168.1.192-255)
          }
        }
      ],
      // Contoso Custom Subnets (conditional)
      deploySql ? [
        {
          name: 'sql-subnet'
          properties: {
            addressPrefix: '192.168.1.64/27'  // 32 IPs (192.168.1.64-95)
            privateEndpointNetworkPolicies: 'Disabled'
            privateLinkServiceNetworkPolicies: 'Enabled'
            networkSecurityGroup: !empty(sqlNsgResourceId) ? {
              id: sqlNsgResourceId
            } : null
          }
        }
      ] : [],
      deployAppService ? [
        {
          name: 'appservice-subnet'
          properties: {
            addressPrefix: '192.168.1.96/27'  // 32 IPs (192.168.1.96-127)
            privateEndpointNetworkPolicies: 'Disabled'
            privateLinkServiceNetworkPolicies: 'Enabled'
            delegations: [
              {
                name: 'Microsoft.Web.serverFarms'
                properties: {
                  serviceName: 'Microsoft.Web/serverFarms'
                }
              }
            ]
            networkSecurityGroup: !empty(appServiceNsgResourceId) ? {
              id: appServiceNsgResourceId
            } : null
          }
        }
      ] : []
    )
  }
}

output vnetResourceId string = vnet.id
output vnetName string = vnet.name
