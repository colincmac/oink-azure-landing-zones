targetScope = 'subscription'

// Parameters
param deployRegion string = deployment().location
param targetRgName string
param hubRgName string
param hubName string
param vnetSpokeName string
param vnetSpokePrefixes array = [
  '10.6.0.0/17'
]

param sharedRouteTableName string = 'RT_SHARED'
param defaultRouteTableName string = 'defaultRouteTable'

param sharedTags object = {
  version: '1.0.0'
  component: 'network'
  partOf: 'lz-apps-oink'
  channel: 'Digital'
  department: 'Retail Banking'
}
param defaultDiagSettingsWorkspaceId string

var common = json(loadTextContent('./common-values.json'))

var subnetConfigs = [
  {
    name: 'aks-nodes-system'
    addressPrefix: '10.6.0.0/22'
    nsgRules: json(loadTextContent('./nsg-rules/aks-nodes-system.json'))
    additionalProperties: {}
  }
  {
    name: 'aks-nodes-inscope-workers'
    addressPrefix: '10.6.8.0/22'
    nsgRules: json(loadTextContent('./nsg-rules/aks-nodes-pci-workers.json'))
    additionalProperties: {}
  }
  {
    name: 'aks-nodes-outofscope-workers'
    addressPrefix: '10.6.16.0/22'
    nsgRules: json(loadTextContent('./nsg-rules/aks-nodes-default-workers.json'))
    additionalProperties: {}
  }
  {
    name: 'aks-app-gateway'
    addressPrefix: '10.6.24.0/24'
    nsgRules: json(loadTextContent('./nsg-rules/aks-app-gateway.json'))
    additionalProperties: {}
  }
  {
    name: 'aks-ingress-lb'
    addressPrefix: '10.6.25.0/28'
    nsgRules: json(loadTextContent('./nsg-rules/aks-ingress-lb.json'))
    additionalProperties: {}
  }
  {
    name: 'services-pe'
    addressPrefix: '10.6.127.0/24'
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
