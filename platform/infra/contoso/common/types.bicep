import { deployTogglesType, resourceIdsType, existingVNetSubnetsDefinitionType, kSAISearchDefinitionType } from '../../../../bicep/infra/common/types.bicep'

// Re-export the base type so consumers can use it
@export()
type baseDeployToggles = deployTogglesType
@export()
type resourceIdType = resourceIdsType

@export()
type baseExistingVNetSubnetsDefinitionType = existingVNetSubnetsDefinitionType

@export()
type basekSAISearchDefinitionType = kSAISearchDefinitionType

// Define only Contoso-specific extensions
@export()
@description('Contoso-specific deployment toggles (use alongside baseDeployToggles).')
type contosoDeployTogglesType = {
  @description('Optional. Toggle to deploy App Service with VNet integration')
  appService: bool?

  @description('Optional. Toggle to deploy Azure SQL Server with private endpoint')
  azureSql: bool?

  @description('Optional. Toggle to deploy a jumpbox into the vnet')
  jumpBox: bool?

  @description('Optional. Toggle to deploy an Azure AI Search instance')
  searchService: bool?
}
