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


var sqlNsgProvided = length(trim(sqlNsgResourceId)) > 0
var appServiceNsgProvided = length(trim(appServiceNsgResourceId)) > 0

resource sqlNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = if (deploySql && !sqlNsgProvided) {
  name: 'nsg-sql-${vnetName}'
  location: location
  properties: {
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

resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = if (deployAppService && !appServiceNsgProvided) {
  name: 'nsg-appservice-${vnetName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppServiceManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '454'
            '455'
          ]
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

var sqlSubnetNsgId = deploySql ? (sqlNsgProvided ? sqlNsgResourceId : sqlNsg.id) : ''
var appServiceSubnetNsgId = deployAppService ? (appServiceNsgProvided ? appServiceNsgResourceId : appServiceNsg.id) : ''



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
            addressPrefix: '192.168.1.64/27'  // 32 IPs (192.168.1.64-95)
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
            addressPrefix: '192.168.0.128/26'  // 64 IPs (192.168.0.128-191)
          }
        }
        {
          name: 'AzureBastionSubnet'
          properties: {
            addressPrefix: '192.168.0.192/26'  // 64 IPs (192.168.0.192-255)
          }
        }
        {
          name: 'devops-agents-subnet'
          properties: {
            addressPrefix: '192.168.1.128/28'  // 16 IPs (192.168.1.128-143)
          }
        }
        {
          name: 'apim-subnet'
          properties: {
            addressPrefix: '192.168.1.160/27'  // 32 IPs (192.168.1.160-191)
          }
        }
        {
          name: 'jumpbox-subnet'
          properties: {
            addressPrefix: '192.168.1.96/28'  // 16 IPs (192.168.1.96-111)
          }
        }
        {
          name: 'aca-env-subnet'
          properties: {
            addressPrefix: '192.168.1.112/28'  // 16 IPs (192.168.1.112-127)
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
            addressPrefix: '192.168.1.0/26'  // 64 IPs (192.168.1.0-63)
          }
        }
      ],
      // Contoso Custom Subnets (conditional)
      deploySql ? [
        {
          name: 'sql-subnet'
          properties: {
            addressPrefix: '192.168.2.0/27'  // 32 IPs (192.168.2.0-31)
            privateEndpointNetworkPolicies: 'Disabled'
            privateLinkServiceNetworkPolicies: 'Enabled'
            networkSecurityGroup: sqlSubnetNsgId != '' ? {
              id: sqlSubnetNsgId
            } : null
          }
        }
      ] : [],
      deployAppService ? [
        {
          name: 'appservice-subnet'
          properties: {
            addressPrefix: '192.168.2.32/27'  // 32 IPs (192.168.2.32-63)
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
            networkSecurityGroup: appServiceSubnetNsgId != '' ? {
              id: appServiceSubnetNsgId
            } : null
          }
        }
      ] : []
    )
  }
}

output vnetResourceId string = vnet.id
output vnetName string = vnet.name
