targetScope = 'subscription'

// Parameters
param deployRegion string = deployment().location
param targetRgName string
param vnetName string
param spokeVNETaddPrefixes array
param spokeSubnets array
param hubPrivateDnsToLink array
param hubRgName string = 'lz-connectivity-001'
param hubName string = 'primary-eastus2'
param sharedRouteTableName string = 'RT_SHARED'
param defaultRouteTableName string = 'Default'
param sharedTags object = {}
param defaultDiagSettingsWorkspaceId string = ''

resource targetRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: targetRgName
}

resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
}

resource hub 'Microsoft.Network/virtualHubs@2021-05-01' existing = {
  name: hubName
  scope: hubRg
}

module vnetspoke '../../common-bicep/networking/vnet.bicep' = {
  scope: targetRg
  name: vnetName
  params: {
    location: deployRegion
    vnetAddressPrefixes: spokeVNETaddPrefixes
    vnetName: vnetName
    subnets: spokeSubnets
    tags: sharedTags
    defaultWorkspaceId: defaultDiagSettingsWorkspaceId
  }
}

module lznetworkingConnection '../../common-bicep/networking/vwanConnection.bicep' = {
  scope: hubRg
  name: '${vnetName}_connection'
  dependsOn: [
    vnetspoke
  ]
  params: {
    associatedRouteTableId: '${hub.id}/hubRouteTables/${sharedRouteTableName}'
    propagatedRouteTableIds: [
      '${hub.id}/hubRouteTables/${defaultRouteTableName}'
    ]
    virtualHubName: hubName
    vnetId: vnetspoke.outputs.vnetId
    vnetName: vnetName
  }
}

module spokeDnsLink '../../common-bicep/connectivity/privatednslink.bicep' = [for dnsZoneName in hubPrivateDnsToLink: {
  scope: hubRg
  name: replace(dnsZoneName, '.', '_')
  dependsOn: [
    vnetspoke
  ]
  params: {
    privateDnsZoneName: dnsZoneName
    vnetId: vnetspoke.outputs.vnetId
    tags: sharedTags
  }
}]
