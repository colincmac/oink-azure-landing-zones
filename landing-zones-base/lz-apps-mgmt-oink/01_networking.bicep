targetScope = 'subscription'

// Parameters
param deployRegion string = deployment().location
param targetRgName string
param hubRgName string
param hubName string
param vnetSpokeName string
param vnetSpokePrefixes array = [
  '10.2.0.0/19'
]

param sharedRouteTableName string = 'RT_SHARED'
param defaultRouteTableName string = 'defaultRouteTable'

param sharedTags object = {
  version: '1.0.0'
  component: 'networking'
  partOf: 'lz-apps-mgmt-oink'
  channel: 'Digital'
  department: 'Retail Banking'
}
param defaultDiagSettingsWorkspaceId string
var common = json(loadTextContent('./common.json'))

var subnetConfigs = [
  {
    name: 'utility-mgmt-ops'
    addressPrefix: '10.2.0.0/24'
    nsgRules: json(loadTextContent('./nsg-rules/utility-mgmt-ops.json'))
    additionalProperties: {}
  }
  {
    name: 'utility-acr-agents'
    addressPrefix: '10.2.2.128/25'
    nsgRules: json(loadTextContent('./nsg-rules/utility-acr-agents.json'))
    additionalProperties: {}
  }
  {
    name: 'utility-image-builder'
    addressPrefix: '10.2.3.0/25'
    nsgRules: json(loadTextContent('./nsg-rules/utility-image-builder.json'))
    additionalProperties: {}
  }
  {
    name: 'utility-mgmt-agents'
    addressPrefix: '10.2.2.0/25'
    nsgRules: json(loadTextContent('./nsg-rules/utility-mgmt-agents.json'))
    additionalProperties: {}
  }
  {
    name: 'services-pe'
    addressPrefix: '10.2.31.0/24'
    nsgRules: json(loadTextContent('./nsg-rules/services-pe.json'))
    additionalProperties: {
      privateEndpointNetworkPolicies: 'Disabled'
    }
  }
]

var subnets = [for config in subnetConfigs: {
  name: config.name
  properties: union({
    addressPrefix: config.addressPrefix
    networkSecurityGroup: {
      id: resourceId(subscription().subscriptionId, targetRgName, 'Microsoft.Network/networkSecurityGroups', '${config.name}-NSG')
    }
  }, config.additionalProperties)
}]

module rg '../../common-bicep/resource-group/rg.bicep' = {
  name: targetRgName
  params: {
    rgName: targetRgName
    location: deployRegion
    tags: sharedTags
  }
}

// resource aksKvUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
//   name: empty(aksCustomKeyVaultRoleGuid) ? guid(subscription().id, 'AKS Key Vault User') : aksCustomKeyVaultRoleGuid
//   scope: subscription()
//   properties: {
//     assignableScopes: [
//       subscription().id
//     ]
//     description: 'Allows an AKS cluster to list & read secrets, keys, and certificates.'
//     permissions: [
//       {
//         actions: []
//         dataActions: [
//           'Microsoft.KeyVault/vaults/secrets/getSecret/action'
//           'Microsoft.KeyVault/vaults/secrets/readMetadata/action'
//           'Microsoft.KeyVault/vaults/certificates/read'
//           'Microsoft.KeyVault/vaults/keys/read'
//         ]
//         notActions: []
//         notDataActions: []
//       }
//     ]
//     roleName: 'AKS Key Vault User'
//   }
// }

module subnetNSGs '../../common-bicep/networking/nsg.bicep' = [for config in subnetConfigs: {
  name: '${config.name}-NSG'
  scope: resourceGroup(rg.name)
  dependsOn: [
    rg
  ]
  params: {
    nsgName: '${config.name}-NSG'
    location: deployRegion
    securityRules: config.nsgRules
    tags: union(sharedTags, common.networkingTeamTags)
    defaultWorkspaceId: defaultDiagSettingsWorkspaceId
  }
}]

module networkingConnectivity '../modules/vwanSpokeVnet.bicep' = {
  name: 'appsMgmtNetworking'
  dependsOn: [
    rg
    subnetNSGs
  ]
  params: {
    sharedTags: sharedTags
    deployRegion: deployRegion
    defaultDiagSettingsWorkspaceId: defaultDiagSettingsWorkspaceId
    spokeVNETaddPrefixes: vnetSpokePrefixes
    spokeSubnets: subnets
    targetRgName: targetRgName
    hubRgName: hubRgName
    hubName: hubName
    vnetName: vnetSpokeName
    defaultRouteTableName: defaultRouteTableName
    sharedRouteTableName: sharedRouteTableName
    hubPrivateDnsToLink: [
      'privatelink${environment().suffixes.acrLoginServer}'
      'privatelink.agentsvc.azure-automation.net'
      'privatelink.monitor.azure.com'
      'privatelink.ods.opinsights.azure.com'
      'privatelink.oms.opinsights.azure.com'
      'privatelink.vaultcore.azure.net'
      'privatelink.blob.${environment().suffixes.storage}'
      'privatelink.file.${environment().suffixes.storage}'
      'privatelink.table.${environment().suffixes.storage}'
      'privatelink.queue.${environment().suffixes.storage}'
      'secure.colinmac.dev'
      'privatelink.eastus2.azmk8s.io'
      'privatelink.documents.azure.com'
      'privatelink.redis.cache.windows.net'
      'privatelink${environment().suffixes.sqlServerHostname}'
    ]
  }
}
