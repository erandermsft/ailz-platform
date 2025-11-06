import { baseDeployToggles, contosoDeployTogglesType } from 'common/types.bicep'

param deployToggles baseDeployToggles
param contosoToggles contosoDeployTogglesType

var deployAppService = contosoToggles.?appService ?? false

module inner '../ailz/main.bicep' = {
  params: {
    deployToggles: deployToggles
  }
}

module serverfarm 'br/public:avm/res/web/serverfarm:0.5.0' = if (deployAppService) {
  name: 'serverfarmDeployment'
  params: {
    // Required parameters
    name: 'wsffcp001'
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
    name: 'wswaf001'
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
