param location string = resourceGroup().location
param storageAccountName string
param privateEndpointSubnetId string
param dnsRg string
param tags object = {}
param pvtEpPrefix string = storageAccountName
var blobPrivateEndpointName = '${pvtEpPrefix}-blob-ep'
var queuePrivateEndpointName = '${pvtEpPrefix}-queue-ep'
var filePrivateEndpointName = '${pvtEpPrefix}-file-ep'

var blobDnsName = 'privatelink.blob.${environment().suffixes.storage}'
var queueDnsName = 'privatelink.queue.${environment().suffixes.storage}'
var fileDnsName = 'privatelink.file.${environment().suffixes.storage}'

module storageAccount '../../common-bicep/storage/storageAccount.bicep' = {
  name: storageAccountName
  params: {
    accessTier: 'Hot'
    location: location
    storageAccountName: storageAccountName
    tags: tags
    allowBlobPublicAccess: false
  }
}

module privateEndpointBlob '../../common-bicep/connectivity/privateendpoint.bicep' = {
  name: blobPrivateEndpointName
  dependsOn: [
    storageAccount
  ]
  params: {
    location: location
    groupIds: [
      'blob'
    ]
    privateEndpointName: blobPrivateEndpointName
    privatelinkConnName: '${blobPrivateEndpointName}-conn'
    resourceId: storageAccount.outputs.provisionedResourceId
    subnetid: privateEndpointSubnetId
  }
}

module privateEndpointQueue '../../common-bicep/connectivity/privateendpoint.bicep' = {
  name: queuePrivateEndpointName
  dependsOn: [
    storageAccount
  ]
  params: {
    location: location
    groupIds: [
      'queue'
    ]
    privateEndpointName: queuePrivateEndpointName
    privatelinkConnName: '${queuePrivateEndpointName}-conn'
    resourceId: storageAccount.outputs.provisionedResourceId
    subnetid: privateEndpointSubnetId
  }
}

module privateEndpointFile '../../common-bicep/connectivity/privateendpoint.bicep' = {
  name: filePrivateEndpointName
  params: {
    location: location
    groupIds: [
      'file'
    ]
    privateEndpointName: filePrivateEndpointName
    privatelinkConnName: '${filePrivateEndpointName}-conn'
    resourceId: storageAccount.outputs.provisionedResourceId
    subnetid: privateEndpointSubnetId
  }
}

module privateEndpointBlobDNSSetting '../../common-bicep/connectivity/privateEndpointDNSGroup.bicep' = {
  name: 'blob-pvtep-dns'
  params: {
    privateDNSZoneId: resourceId(subscription().subscriptionId, dnsRg, 'Microsoft.Network/privateDnsZones', blobDnsName)
    privateEndpointName: privateEndpointBlob.name
    dnsZoneConfigName: replace(blobDnsName, '.', '-')
  }
}

module privateEndpointQueueDNSSetting '../../common-bicep/connectivity/privateEndpointDNSGroup.bicep' = {
  name: 'queue-pvtep-dns'
  params: {
    privateDNSZoneId: resourceId(subscription().subscriptionId, dnsRg, 'Microsoft.Network/privateDnsZones', queueDnsName)
    privateEndpointName: privateEndpointQueue.name
    dnsZoneConfigName: replace(queueDnsName, '.', '-')
  }
}

module privateEndpointFileDNSSetting '../../common-bicep/connectivity/privateEndpointDNSGroup.bicep' = {
  name: 'file-pvtep-dns'
  params: {
    privateDNSZoneId: resourceId(subscription().subscriptionId, dnsRg, 'Microsoft.Network/privateDnsZones', fileDnsName)
    privateEndpointName: privateEndpointFile.name
    dnsZoneConfigName: replace(fileDnsName, '.', '-')
  }
}
