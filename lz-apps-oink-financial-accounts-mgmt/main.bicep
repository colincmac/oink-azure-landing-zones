targetScope = 'subscription'
param location string = deployment().location
param deployRgName string
param dnsRgName string
param appInsightsName string
param keyVaultName string
param cosmosDbAccountName string
param identityName string
@allowed([
  'Staging'
  'Prod'
])
param deployEnv string

param storageAccountName string
param privateEndpointSubnetId string
param kvPrivateEndpointName string = '${keyVaultName}-pvt-ep'

param aksCustomKeyVaultRoleGuid string

var keyVaultDnsName = 'privatelink.vaultcore.azure.net'

var common = json(loadTextContent('./common.json'))

var commonTags = union(common.tags, {
  environment: deployEnv
})

resource rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: deployRgName
  location: location
  tags: commonTags
}

resource monitorMgmtRg 'Microsoft.Resources/resourceGroups@2020-06-01' existing = {
  name: common.monitorMgmtRgName
}

resource appsMgmtRg 'Microsoft.Resources/resourceGroups@2020-06-01' existing = {
  name: common.appsMgmtRgName
}

module vault '../common-bicep/keyvault/keyvault.bicep' = {
  name: keyVaultName
  scope: rg
  params: {
    location: location
    name: keyVaultName
    tenantId: subscription().tenantId
    tags: union(commonTags, {
      component: 'secrets'
    })
  }
}

module kvPrivateEndpoint '../common-bicep/connectivity/privateendpoint.bicep' = {
  name: kvPrivateEndpointName
  scope: rg
  dependsOn: [
    vault
  ]
  params: {
    location: location
    groupIds: [
      'Vault'
    ]
    privateEndpointName: kvPrivateEndpointName
    privatelinkConnName: '${kvPrivateEndpointName}-conn'
    resourceId: vault.outputs.keyvaultId
    subnetid: privateEndpointSubnetId
  }
}

module kvPrivateEndpointDNSSetting '../common-bicep/connectivity/privateEndpointDNSGroup.bicep' = {
  name: 'vault-pvtep-dns'
  scope: rg
  dependsOn: [
    kvPrivateEndpoint
  ]
  params: {
    privateDNSZoneId: resourceId(subscription().subscriptionId, dnsRgName, 'Microsoft.Network/privateDnsZones', keyVaultDnsName)
    privateEndpointName: kvPrivateEndpoint.name
    dnsZoneConfigName: replace(keyVaultDnsName, '.', '-')
  }
}

module identity '../common-bicep/identity/userassigned.bicep' = {
  name: identityName
  scope: rg
  params: {
    identityName: identityName
    location: location
    tags: union(commonTags, {
      component: 'identity'
    })
  }
}

// TODO: debug role assignment in cosmos
// module cosmosRole '../common-bicep/identity/cosmosSqlRoles.bicep' = {
//   name: 'cosmos-db-data-contributor'
//   scope: appsMgmtRg
//   dependsOn: [
//     identity
//   ]
//   params: {
//     roleDefinitionId: '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor
//     cosmosAccountName: cosmosDbAccountName
//     principalId: identity.outputs.principalId
//   }
// }

module keyVaultSecretsUser '../common-bicep/identity/keyVaultRoles.bicep' = {
  name: 'aksKeyVaultSecretUserRole'
  scope: rg
  params: {
    principalId: identity.outputs.principalId
    roleGuid: aksCustomKeyVaultRoleGuid // Custom AKS Key Vault User role
    keyVaultName: keyVaultName
  }
}

// module storage 'modules/storage.bicep' = {
//   name: storageAccountName
//   scope: rg
//   params: {
//     location: location
//     privateEndpointSubnetId: privateEndpointSubnetId
//     storageAccountName: storageAccountName
//     tags: union(commonTags, {
//       component: 'storage'
//     })
//     dnsRg: dnsRgName
//   }
// }

// module appInsights '../common-bicep/monitoring/appInsights.bicep' = {
//   name: appInsightsName
//   scope: rg
//   params: {
//     appInsightsName: appInsightsName
//     location: location
//     tags: union(commonTags, {
//       component: 'monitoring'
//     })
//     aiWorkSpaceId: common.workspaceId
//     publicNetworkAccessForIngestion: 'Enabled'
//     publicNetworkAccessForQuery: 'Enabled'
//     keyVaultName: keyVaultName
//   }
// }

// module appInsightsPls '../common-bicep/monitoring/appInsightsPrivateLink.bicep' = {
//   name: 'appInsights-privatelink-scope'
//   scope: monitorMgmtRg
//   params: {
//     appInsightsId: appInsights.outputs.provisionedResourceId
//     appInsightsName: appInsightsName
//     plsName: common.monitorMgmtPlsName
//   }
// }
