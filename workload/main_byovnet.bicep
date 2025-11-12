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
var mergedTags = union({
  SecurityControl: 'Ignore'
}, tags)

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



module ailz 'ts/PlatformSpecs:ts-contoso-ailz-byo-vnet:24a3146' = {
  scope: targetRg
  params: {
    contosoToggles: {}
     deployToggles: {
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
  
    existingVNetName: byoVnet.outputs.vnetResourceId
    resourceIds: {} 
  }

}
