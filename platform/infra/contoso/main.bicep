import { baseDeployToggles, contosoDeployTogglesType,resourceIdType,baseExistingVNetSubnetsDefinitionType } from 'common/types.bicep'

param deployToggles baseDeployToggles
param contosoToggles contosoDeployTogglesType
param resourceIds resourceIdType

var deployAppService = contosoToggles.?appService ?? false
@description('Optional. Location')
param location string = 'swedencentral'

@description('Optional.  Deterministic token for resource names; auto-generated if not provided.')
param resourceToken string = toLower(uniqueString(subscription().id, resourceGroup().name, location))

@description('Optional.  Base name to seed resource names; defaults to a 12-char token.')
param baseName string = substring(resourceToken, 0, 12)


param subnets baseExistingVNetSubnetsDefinitionType 

// Reference the platform team's published base AILZ infrastructure from ACR
// This includes all template spec references for wrappers (published by CI/CD)
// 
// IMPORTANT: Update bicepconfig.json with your actual ACR registry name
// 
// For local development: Comment this out and uncomment the local reference below
module baseInfra 'br/ContosoACR:bicep/ailz/base:latest' = {
  name: 'ailz-base-infrastructure'
  params: {
    deployToggles: deployToggles
     resourceIds: resourceIds
     existingVNetSubnetsDefinition: subnets
     location: location
  }

  
}

// For local development: Uncomment this and comment out the ACR reference above
// module baseInfra '../../../bicep/deploy/main.bicep' = {
//   name: 'ailz-base-infrastructure'
//   params: {
//     deployToggles: deployToggles
//   }
// }

// Contoso-specific resources below. Re-use Wrapper pattern?
module serverfarm 'br/public:avm/res/web/serverfarm:0.5.0' = if (deployAppService) {
  name: 'serverfarmDeployment'
  params: {
    // Required parameters
    name: 'appsvc-${baseName}'
    // Non-required parameters
    reserved: true
    skuName: 'FC1'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
    zoneRedundant: false
  }
}
module website 'br/public:avm/res/web/site:0.19.4' = if (deployAppService) {
  name: 'siteDeployment'
  params: {
    // Required parameters
    kind: 'app'
    name: baseName
    serverFarmResourceId: serverfarm.outputs.resourceId
    // Non-required parameters
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: false
        name: 'scm'
      }
    ]
    httpsOnly: true
    outboundVnetRouting: {
      allTraffic: true
      contentShareTraffic: true
      imagePullTraffic: true
    }
    publicNetworkAccess: 'Disabled'
    scmSiteAlsoStopped: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'
      healthCheckPath: '/healthz'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnetcore'
        }
      ]
      minTlsVersion: '1.2'
    }
  }
}
