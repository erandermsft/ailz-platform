module ailz 'ts/PlatformSpecs:ts-contoso-ailz:v20251110-893574a2a8472bb2cb0ce100edcc7d1e8423a580' = {
  name: 'ailz'
  params: {
    location: 'swedencentral'
    resourceIds: {}
    contosoToggles: { appService: true, azureSql: false }
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
      virtualNetwork: true
      wafPolicy: false
    }
  }
  
}



// module ailz 'br:envacrtkkzfewrtdpby.azurecr.io/bicep/platform/contoso:v20251106-1c361a2' = {
//   name: 'ailz'
//   params: {
//     location: 'swedencentral'
//     resourceIds: {}
//     contosoToggles: { appService: false, sql: false }
//     deployToggles: {
//       acaEnvironmentNsg: false
//       agentNsg: true
//       apiManagement: false
//       apiManagementNsg: false
//       appConfig: true
//       appInsights: true
//       applicationGateway: false
//       applicationGatewayNsg: false
//       applicationGatewayPublicIp: false
//       bastionHost: true
//       bastionNsg: true
//       buildVm: false
//       containerApps: false
//       containerEnv: false
//       containerRegistry: true
//       cosmosDb: false
//       devopsBuildAgentsNsg: false
//       firewall: false
//       groundingWithBingSearch: true
//       jumpVm: true
//       jumpboxNsg: true
//       keyVault: true
//       logAnalytics: true
//       peNsg: true
//       searchService: false
//       storageAccount: true
//       virtualNetwork: true
//       wafPolicy: false
//     }
//   }
  
// }
