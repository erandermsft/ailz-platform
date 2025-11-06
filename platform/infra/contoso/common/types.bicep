import {deployTogglesType} from '../../../../bicep/infra/common/types.bicep'

// Re-export the base type so consumers can use it
@export()
type baseDeployToggles = deployTogglesType

// Define only Contoso-specific extensions
@export()
@description('Contoso-specific deployment toggles (use alongside baseDeployToggles).')
type contosoDeployTogglesType = {
  @description('Optional. Toggle to deploy App Service')
  appService: bool?

  @description('Optional. Toggle to deploy Azure SQL')
  sql: bool?
}
