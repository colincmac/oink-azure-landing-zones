targetScope = 'subscription'

// Parameters
param deployRegion string = deployment().location
param rgName string
param vwanHubAddressPrefix string = '192.168.0.0/24'

param sharedVnetPrefixes array = [
  '10.0.0.0/16'
]

param vnetSharedServicesName string = toLower('shared-services-${deployRegion}')

@maxLength(80)
param vwanName string
param certManagerIdentityName string = 'certificate-manager-prod'

var primaryVwanHubName = toLower('primary-${deployRegion}')

module rg '../../common-bicep/resource-group/rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: deployRegion
  }
}

module vwan '../../common-bicep/networking/vwan.bicep' = {
  scope: resourceGroup(rg.name)
  name: vwanName
  params: {
    location: deployRegion
    virtualHubName: primaryVwanHubName
    virtualHubAddressPrefix: vwanHubAddressPrefix
    vwanName: vwanName
    vwanType: 'Standard'
  }
}

module vnetSharedServices '../../common-bicep/networking/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: vnetSharedServicesName
  params: {
    location: deployRegion
    vnetAddressPrefixes: sharedVnetPrefixes
    vnetName: vnetSharedServicesName
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/26'
        }
      }
      {
        name: 'services-pe'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
  dependsOn: [
    rg
  ]
}

module sharedServicesVwanConnection '../../common-bicep/networking/vwanConnection.bicep' = {
  scope: resourceGroup(rg.name)
  name: '${vnetSharedServicesName}_connection'
  dependsOn: [
    vnetSharedServices
    vwan
  ]
  params: {
    associatedRouteTableId: '${vwan.outputs.vhubId}/hubRouteTables/defaultRouteTable'
    propagatedRouteTableIds: [
      '${vwan.outputs.vhubId}/hubRouteTables/defaultRouteTable'
    ]
    virtualHubName: primaryVwanHubName
    vnetId: vnetSharedServices.outputs.vnetId
    vnetName: vnetSharedServicesName
  }
}

module routeTableShared '../../common-bicep/networking/routetable.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'rtShared'
  dependsOn: [
    sharedServicesVwanConnection
  ]
  params: {
    virtualHubName: primaryVwanHubName
    routes: [
      {
        name: 'route_to_shared_services'
        destinationType: 'CIDR'
        destinations: sharedVnetPrefixes
        nextHopType: 'ResourceId'
        nextHop: sharedServicesVwanConnection.outputs.connectionId
      }
    ]
    rtName: 'RT_SHARED'
  }
}

// need to update the shared VNET connection with updated route table
module updateSharedServicesVwanConnection '../../common-bicep/networking/vwanConnection.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'UPDATE_${vnetSharedServicesName}_connection'
  dependsOn: [
    vnetSharedServices
    vwan
    routeTableShared
  ]
  params: {
    associatedRouteTableId: '${vwan.outputs.vhubId}/hubRouteTables/defaultRouteTable'
    propagatedRouteTableIds: [
      '${vwan.outputs.vhubId}/hubRouteTables/defaultRouteTable'
      routeTableShared.outputs.routetableId
    ]
    virtualHubName: primaryVwanHubName
    vnetId: vnetSharedServices.outputs.vnetId
    vnetName: vnetSharedServicesName
  }
}

module privateDNSZoneACR '../../common-bicep/connectivity/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsACRZone'
  params: {
    privateDNSZoneName: 'privatelink.azurecr.io'
  }
}

module privateDNSLinkACR '../../common-bicep/connectivity/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkACR'
  dependsOn: [
    vnetSharedServices
  ]
  params: {
    privateDnsZoneName: privateDNSZoneACR.outputs.privateDNSZoneName
    vnetId: vnetSharedServices.outputs.vnetId
  }
}

module privateDNSZoneLocal '../../common-bicep/connectivity/privatednszone.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privatednsLocalZone'
  params: {
    privateDNSZoneName: 'privatelink.azurecr.io'
  }
}

module privateDNSLinkLocal '../../common-bicep/connectivity/privatednslink.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'privateDNSLinkLocal'
  dependsOn: [
    vnetSharedServices
  ]
  params: {
    privateDnsZoneName: privateDNSZoneLocal.outputs.privateDNSZoneName
    vnetId: vnetSharedServices.outputs.vnetId
  }
}

module certManagerIdentity '../../common-bicep/identity/userassigned.bicep' = {
  scope: resourceGroup(rg.name)
  name: certManagerIdentityName
  params: {
    identityName: certManagerIdentityName
    location: deployRegion
  }
}

output defaultRouteTableId string = '${vwan.outputs.vhubId}/hubRouteTables/defaultRouteTable'
output sharedRouteTableId string = routeTableShared.outputs.routetableId
