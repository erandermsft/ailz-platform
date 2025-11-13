// Pre-create a resource group and VNet with all required subnets for BYO VNet scenario,
// then deploy the platform landing zone into that VNet via template spec.
// Deploy this BEFORE running main-byo-vnet.bicep
targetScope = 'subscription'

@description('Required. Location for the VNet')
param location string = 'swedencentral'

@description('Required. Resource group name to create for the BYO deployment.')
param resourceGroupName string

@description('Optional. VNet name')
param vnetName string = 'vnet-ailz-contoso'

@description('Optional. Tags applied to the resource group and all resources created by this template.')
param tags object = {}

// Ensure the resource group always carries the default SecurityControl tag while
// allowing callers to append or override additional tags.
var mergedTags = union(
  {
    SecurityControl: 'Ignore'
  },
  tags
)

// Create (or ensure) resource group at subscription scope so we can deploy child resources into it
resource targetRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: mergedTags
}

module byoVnet './modules/byo-vnet.bicep' = {
  name: 'byo-vnet'
  scope: targetRg
  params: {
    location: location
    vnetName: vnetName
    tags: mergedTags
  }
}

module ailz 'ts/PlatformSpecs:ts-contoso-ailz-byo-vnet:fa19020' = {
  scope: targetRg
  params: {
    contosoToggles: { appService: true, jumpBox: true,searchService:true }
    existingVNetName: byoVnet.outputs.vnetResourceId
    resourceIds: {}
  }
}

// resource umi 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' ={
//   scope: targetRg
//   location: location
//   name: 'aiworkload-umi'
// }
