import {deployTogglesType} from '../../ailz/common/types.bicep'

// Another approach would be to import the ones we want to expose as our own type, and then add our new deployment options to it
// Pros: We can remove toggles that we currently dont allow, such as AppGW and APIM
// Cons: Might be harder to keep up to date over time as upstream changes?

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
