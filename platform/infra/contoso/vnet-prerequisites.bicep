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

@description('Optional. NSG resource ID applied to subnets without dedicated NSGs')
param defaultSubnetNsgResourceId string = ''

@description('Required. Existing VNet name')
param existingVNetNameOnly string

@description('Required. Resource group of existing VNet')
param existingVNetResourceGroupName string

@description('Optional. Subscription ID of existing VNet (defaults to current)')
param existingVNetSubscriptionId string = subscription().subscriptionId

@description('Optional. Include Jumpbox and Azure Bastion subnets')
param includeJumpBoxAndBastionSubnet bool = false

param baseName string

var baseAddressPrefix = vnet.properties.addressSpace.addressPrefixes[0]

var privateEndpointSubnetCidr = cidrSubnet(baseAddressPrefix, 27, 0)
var appServiceSubnetCidr = cidrSubnet(baseAddressPrefix, 27, 1)
var sqlSubnetCidr = cidrSubnet(baseAddressPrefix, 27, 2)
var jumpboxSubnetCidr = cidrSubnet(baseAddressPrefix, 27, 3)
var azureBastionSubnetCidr = cidrSubnet(baseAddressPrefix, 27, 4)

var sqlNsgProvided = length(trim(sqlNsgResourceId)) > 0
var appServiceNsgProvided = length(trim(appServiceNsgResourceId)) > 0
var defaultSubnetNsgProvided = length(trim(defaultSubnetNsgResourceId)) > 0

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

module peNsg 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: 'nsg-${uniqueString('pensg')}'
  params: {
    name: 'nsg-pe-${baseName}'
    location: location
    enableTelemetry: false
  }
}
module bastionNsg 'br/public:avm/res/network/network-security-group:0.5.1' = {
  params: {
    name: 'nsg-bastion-${baseName}'
    location: location
    enableTelemetry: false
    // Required security rules for Azure Bastion
    securityRules: [
      {
        name: 'Allow-GatewayManager-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          description: 'Allow Azure Bastion control plane traffic'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-Internet-HTTPS-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          protocol: 'Tcp'
          description: 'Allow HTTPS traffic from Internet for user sessions'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-Internet-HTTPS-Alt-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          protocol: 'Tcp'
          description: 'Allow alternate HTTPS traffic from Internet'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '4443'
        }
      }
      {
        name: 'Allow-BastionHost-Communication-Inbound'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 130
          protocol: 'Tcp'
          description: 'Allow Bastion host-to-host communication'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['8080', '5701']
        }
      }
      {
        name: 'Allow-SSH-RDP-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 100
          protocol: '*'
          description: 'Allow SSH and RDP to target VMs'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['22', '3389']
        }
      }
      {
        name: 'Allow-AzureCloud-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 110
          protocol: 'Tcp'
          description: 'Allow Azure Cloud communication'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-BastionHost-Communication-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 120
          protocol: 'Tcp'
          description: 'Allow Bastion host-to-host communication'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: ['8080', '5701']
        }
      }
      {
        name: 'Allow-GetSessionInformation-Outbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 130
          protocol: '*'
          description: 'Allow session and certificate validation'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

module jumpboxNsg 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: 'm-nsg-jumpbox'
  params: {
    name: 'nsg-jumpbox-${baseName}'
    location: location
    enableTelemetry: false
  }
}

var sqlSubnetNsgId = deploySql ? (sqlNsgProvided ? sqlNsgResourceId : sqlNsg.id) : ''
var appServiceSubnetNsgId = deployAppService ? (appServiceNsgProvided ? appServiceNsgResourceId : appServiceNsg.id) : ''
var byoDefaultSubnets = concat(
  [],
  includeJumpBoxAndBastionSubnet
    ? [
        {
          name: 'jumpbox-subnet'
          addressPrefix: jumpboxSubnetCidr
          networkSecurityGroupResourceId: jumpboxNsg.outputs.resourceId
        }
        {
          name: 'AzureBastionSubnet'
          addressPrefix: azureBastionSubnetCidr
          networkSecurityGroupResourceId: bastionNsg.outputs.resourceId
        }
      ]
    : [],
  deployAppService
    ? [
        {
          name: 'appservice-subnet'
          addressPrefix: appServiceSubnetCidr
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegation: 'Microsoft.Web/serverFarms'
          networkSecurityGroupResourceId: appServiceSubnetNsgId
        }
      ]
    : [],
  [
    {
      name: 'pe-subnet'
      addressPrefix: privateEndpointSubnetCidr
      privateEndpointNetworkPolicies: 'Disabled'
      networkSecurityGroupResourceId: peNsg.outputs.resourceId
    }
  ],
  deploySql
    ? [
        {
          name: 'sql-subnet'
          addressPrefix: sqlSubnetCidr
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          networkSecurityGroupResourceId: sqlSubnetNsgId
        }
      ]
    : []
)

// ===================================
// BYO VNET CONFIGURATION
// ===================================

resource vnet 'Microsoft.Network/virtualNetworks@2024-10-01' existing = {
  name: existingVNetNameOnly
  scope: resourceGroup(existingVNetSubscriptionId, existingVNetResourceGroupName)
}

module byoSubnets '../../../bicep/infra/helpers/deploy-subnets-to-vnet/main.bicep' = {
  name: 'byo-default-subnets'
  params: {
    existingVNetName: vnet.id
    subnets: byoDefaultSubnets
  }
}

output vnetResourceId string = vnet.id
output vnetName string = vnet.name
output peNsgResourceId string = peNsg.outputs.resourceId
