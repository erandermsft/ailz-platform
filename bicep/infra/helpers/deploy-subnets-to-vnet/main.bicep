// Subnet deployment to existing VNet 
targetScope = 'resourceGroup'

@description('Required. Subnet configuration array.')
param subnets array

@description('Required. Existing Virtual Network name or Resource ID. When using Resource ID, the component should be deployed to the target resource group scope.')
param existingVNetName string

// Parse Resource ID to extract VNet name (supports both name and Resource ID formats)
var vnetIdSegments = split(existingVNetName, '/')
var vnetName = length(vnetIdSegments) > 1 ? last(vnetIdSegments) : existingVNetName

// Reference existing VNet (assumes component is deployed to correct scope)
resource existingVNet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

// Deploy each subnet to the existing VNet
resource deployedSubnets 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [for (subnet, index) in subnets: {
  name: subnet.name
  parent: existingVNet
  properties: {
    addressPrefix: subnet.?addressPrefix
    addressPrefixes: subnet.?addressPrefixes
    applicationGatewayIPConfigurations: subnet.?applicationGatewayIPConfigurations
    defaultOutboundAccess: subnet.?defaultOutboundAccess
    delegations: subnet.?delegation != null ? [
      {
        name: '${subnet.name}-delegation'
        properties: {
          serviceName: subnet.delegation
        }
      }
    ] : []
    natGateway: subnet.?natGatewayResourceId != null ? {
      id: subnet.natGatewayResourceId
    } : null
    networkSecurityGroup: subnet.?networkSecurityGroupResourceId != null ? {
      id: subnet.networkSecurityGroupResourceId
    } : null
    privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: subnet.?privateLinkServiceNetworkPolicies
    routeTable: subnet.?routeTableResourceId != null ? {
      id: subnet.routeTableResourceId
    } : null
    serviceEndpointPolicies: subnet.?serviceEndpointPolicies
    serviceEndpoints: subnet.?serviceEndpoints
    sharingScope: subnet.?sharingScope
  }
}]

@description('Array of deployed subnet resource IDs.')
output subnetResourceIds array = [for (subnet, index) in subnets: deployedSubnets[index].id]

@description('The resource ID of the parent Virtual Network.')
output virtualNetworkResourceId string = existingVNet.id

@description('Array of subnet names.')
output subnetNames array = [for (subnet, index) in subnets: deployedSubnets[index].name]
