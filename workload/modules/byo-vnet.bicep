// Deploys the BYO virtual network with required subnets in the target resource group.
// This module exists so the parent subscription-scoped template can create the RG first,
// then hydrate the VNet prior to calling the platform template spec.
targetScope = 'resourceGroup'

@description('Required. Azure region for the VNet.')
param location string

@description('Required. Name of the virtual network to deploy.')
param vnetName string

@description('Optional. Tags applied to the VNet resource.')
param tags object = {}

@description('Optional. Address prefixes for the VNet address space.')
param addressPrefixes array = [
  '192.168.0.0/24'
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
  // }
  }
}

@description('The name of the deployed VNet.')
output vnetName string = vnet.name

@description('Resource ID of the deployed VNet.')
output vnetResourceId string = vnet.id
