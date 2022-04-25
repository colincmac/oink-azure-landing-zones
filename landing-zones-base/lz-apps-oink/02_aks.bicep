targetScope = 'subscription'

param deployRegion string = deployment().location
param aksRgName string
param hubRgName string
param appMgmtRgName string
param appMgmtVnetName string

param clusterName string
param vnetName string
param aksRbacGroupUsers string
param aksRbacGroupAdmins string
param aksIdentityName string = 'kubeletIdentity'
param acrName string
param keyvaultName string = clusterName
param storageAccountName string = toLower(replace(clusterName, '-', ''))
@description('Resource Group name for deployed AKS resources')
param nodeResourceGroupName string = 'MC_${aksRgName}_${clusterName}_${deployRegion}'
param laWorkspaceId string
param pvtDnsZoneId string
param aksCustomKeyVaultRoleGuid string

param sharedTags object = {
  version: '1.0.0'
  component: 'aks'
  partOf: 'lz-apps-oink-aks'
  channel: 'Digital'
  department: 'Retail Banking'
}
param defaultNodeLabels object = {
  channel: 'Digital'
  department: 'Retail-Banking'
}
var common = json(loadTextContent('./common-values.json'))
var nodeOsType = 'Linux'
var nodeMaxPods = 100
var defaultNodeMaxCount = 2
var defaultNodeMinCount = 1
/*
* This needs several resource providers to be registered first.
* az provider register -n Microsoft.OperationsManagement
* az provider register -n Microsoft.ContainerService
* az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
* az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService
*/

resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
}

resource appMgmtRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
}

module aksRg '../../common-bicep/resource-group/rg.bicep' = {
  name: aksRgName
  params: {
    rgName: aksRgName
    location: deployRegion
    tags: sharedTags
  }
}

module keyvault '../../common-bicep/keyvault/keyvault.bicep' = {
  scope: resourceGroup(aksRg.name)
  name: keyvaultName
  params: {
    location: deployRegion
    keyVaultsku: 'Standard'
    name: keyvaultName
    tenantId: subscription().tenantId
  }
}

module storageAccount '../../common-bicep/storage/storageAccount.bicep' = {
  scope: resourceGroup(aksRg.name)
  name: storageAccountName
  params: {
    accessTier: 'Hot'
    location: deployRegion
    storageAccountName: storageAccountName
  }
}

module aksKubeletIdentity '../../common-bicep/identity/userassigned.bicep' = {
  name: aksIdentityName
  scope: resourceGroup(aksRg.name)
  params: {
    identityName: aksIdentityName
    location: deployRegion
    tags: sharedTags
  }
}

// var userIdentities = [
//   {
//     name: 'keda-operator'
//     binding: 'keda-operator'
//     namespace: 'core-platform'
//   }
//   {
//     name: 'cert-provider'
//     binding: 'cert-provider'
//     namespace: 'core-platform'
//   }
//   {
//     name: 'grafana-operator'
//     binding: 'grafana-operator'
//     namespace: 'core-monitoring'
//   }
// ]

// var podIdentityConfigs = [for id in userIdentities: {
//   name: id.name
//   namespace: id.namespace
//   identity: {
//     resourceId: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.ManagedIdentity/userAssignedIdentities', id.name)
//   }
//   bindingSelector: id.binding
// }]

// module defaultPodIdentities '../../common-bicep/identity/userassigned.bicep' = [for id in userIdentities: {
//   name: id.name
//   scope: resourceGroup(aksRg.name)
//   params: {
//     identityName: id.name
//     location: deployRegion
//     tags: sharedTags
//   }
// }]

module kedaOperator '../../common-bicep/identity/userassigned.bicep' = {
  name: 'keda-operator'
  scope: resourceGroup(aksRg.name)
  params: {
    identityName: 'keda-operator'
    location: deployRegion
    tags: sharedTags
  }
}

module grafanaOperator '../../common-bicep/identity/userassigned.bicep' = {
  name: 'grafana-operator'
  scope: resourceGroup(aksRg.name)
  params: {
    identityName: 'grafana-operator'
    location: deployRegion
    tags: sharedTags
  }
}

module certProvider '../../common-bicep/identity/userassigned.bicep' = {
  name: 'cert-provider'
  scope: resourceGroup(aksRg.name)
  params: {
    identityName: 'cert-provider'
    location: deployRegion
    tags: sharedTags
  }
}

// Only needed if deploying AAD Pod Identity in Standard (un-managed) mode
// module aksPodIdentityRole ''../../common-bicep/identity/role.bicep' = {
//   scope: resourceGroup(aksRg.name)
//   name: 'aksPodIdentityRole'
//   params: {
//     principalId: aksIdentity.properties.principalId
//     roleGuid: 'f1a07417-d97a-45cb-824c-7a7467783830' //Managed Identity Operator
//   }
// }

module aksPvtNetworkContrib '../../common-bicep/identity/networkcontributorrole.bicep' = {
  scope: resourceGroup(aksRg.name)
  name: 'aksPvtNetworkContrib'
  params: {
    principalId: aksKubeletIdentity.outputs.principalId
    roleGuid: '4d97b98b-1d4f-4787-a291-c67834d212e7' //Network Contributor
    vnetName: vnetName
  }
}

module aksPvtDNSContrib '../../common-bicep/identity/pvtdnscontribrole.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'aksPvtDNSContrib'
  params: {
    principalId: aksKubeletIdentity.outputs.principalId
    roleGuid: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f' //Private DNS Zone Contributor
  }
}

module vmContributeRole '../../common-bicep/identity/role.bicep' = {
  scope: resourceGroup(nodeResourceGroupName)
  name: 'vmContributeRole'
  params: {
    principalId: aksKubeletIdentity.outputs.principalId
    roleGuid: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' //Virtual Machine Contributor
  }
  dependsOn: [
    aksCluster
  ]
}

module aksCluster '../../common-bicep/aks/secureCluster.bicep' = {
  scope: resourceGroup(aksRg.name)
  name: 'aksCluster'
  dependsOn: [
    aksPvtDNSContrib
    aksPvtNetworkContrib
  ]
  params: {
    aadGroupdIds: [
      aksRbacGroupAdmins
    ]
    agentProfiles: [
      {
        name: 'system01'
        mode: 'System'
        count: 1
        vmSize: 'Standard_B4ms'
        osDiskSizeGB: 0
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks-nodes-system')
        maxCount: defaultNodeMaxCount
        minCount: defaultNodeMinCount
        scaleSetPriority: 'Regular'
        enableAutoScaling: true
        // nodeTaints: [
        //   'CriticalAddonsOnly=true:NoSchedule'
        // ]
        osType: nodeOsType
        maxPods: nodeMaxPods
        nodeLabels: union({
          'compliance.colinmac.dev/pci-scope': 'out-of-scope'
        }, defaultNodeLabels)
      }
      {
        name: 'inscope01'
        mode: 'User'
        count: 1
        vmSize: 'Standard_B4ms'
        osDiskSizeGB: 0
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks-nodes-inscope-workers')
        maxCount: defaultNodeMaxCount
        minCount: defaultNodeMinCount
        scaleSetPriority: 'Regular'
        enableAutoScaling: true
        // nodeTaints: nodePoolNodeTaints
        osType: nodeOsType
        maxPods: nodeMaxPods
        nodeLabels: union({
          'compliance.colinmac.dev/pci-scope': 'in-scope'
        }, defaultNodeLabels)
      }
      {
        name: 'ooscope01'
        mode: 'User'
        count: 1
        vmSize: 'Standard_B4ms'
        osDiskSizeGB: 0
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks-nodes-outofscope-workers')
        maxCount: defaultNodeMaxCount
        minCount: defaultNodeMinCount
        scaleSetPriority: 'Regular'
        enableAutoScaling: true
        // nodeTaints: nodePoolNodeTaints
        osType: nodeOsType
        maxPods: nodeMaxPods
        nodeLabels: union({
          'compliance.colinmac.dev/pci-scope': 'out-of-scope'
        }, defaultNodeLabels)
      }
    ]
    // assignedPodIdentityProfiles: [
    //   {
    //     name: 'keda-operator'
    //     namespace: 'core-platform'
    //     identity: {
    //       resourceId: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.ManagedIdentity/userAssignedIdentities', 'keda-operator')
    //       clientId: kedaOperator.outputs.clientId
    //       objectId: kedaOperator.outputs.principalId
    //     }
    //     bindingSelector: 'keda-operator'
    //   }
    //   {
    //     name: 'cert-provider'
    //     namespace: 'core-platform'
    //     identity: {
    //       resourceId: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.ManagedIdentity/userAssignedIdentities', 'cert-provider')
    //       clientId: certProvider.outputs.clientId
    //       objectId: certProvider.outputs.principalId
    //     }
    //     bindingSelector: 'cert-provider'
    //   }
    //   {
    //     name: 'grafana-operator'
    //     namespace: 'core-monitoring'
    //     identity: {
    //       resourceId: resourceId(subscription().subscriptionId, aksRgName, 'Microsoft.ManagedIdentity/userAssignedIdentities', 'grafana-operator')
    //       clientId: grafanaOperator.outputs.clientId
    //       objectId: grafanaOperator.outputs.principalId
    //     }
    //     bindingSelector: 'grafana-operator'
    //   }
    // ]
    deployRegion: deployRegion
    clusterName: clusterName
    logworkspaceid: laWorkspaceId
    privateDNSZoneId: pvtDnsZoneId
    identity: {
      '${aksKubeletIdentity.outputs.identityid}': {}
    }
    nodeResourceGroupName: nodeResourceGroupName
  }
}

module storageAccountKeyAccess '../../common-bicep/identity/storageAccountRole.bicep' = {
  scope: resourceGroup(aksRg.name)
  name: 'storageAccountAccess'
  params: {
    principalId: aksCluster.outputs.kubeletIdentity
    roleGuid: '81a9662b-bebf-436f-a333-f67b29880f12' //Storage Account Key Operator Service Role
    storageAccountName: storageAccountName
  }
}

module acraksaccess '../../common-bicep/identity/acrrole.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'acraksaccess'
  params: {
    principalId: aksCluster.outputs.kubeletIdentity
    roleGuid: '7f951dda-4ed3-4680-a7ca-43fe172d538d' //AcrPull
    acrName: acrName
  }
}

// module aksuseraccess '../../common-bicep/identity/role.bicep' = {
//   scope: resourceGroup(aksRg.name)
//   name: 'aksuseraccess'
//   params: {
//     principalId: aksRbacGroupUsers
//     roleGuid: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f' //Azure Kubernetes Service Cluster User Role
//   }
// }

// module aksadminaccess '../../common-bicep/identity/role.bicep' = {
//   scope: resourceGroup(aksRg.name)
//   name: 'aksadminaccess'
//   params: {
//     principalId: aksRbacGroupAdmins
//     roleGuid: '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8' //Azure Kubernetes Service Cluster Admin Role
//   }
// }

// module keyVaultSecretsUser '../../common-bicep/identity/keyVaultRoles.bicep' = {
//   name: 'aksKeyVaultSecretUserRole'
//   scope: resourceGroup(aksRg.name)
//   params: {
//     principalId: aksCluster.outputs.keyvaultaddonIdentity
//     roleGuid: last(split(aksKvUserRole.id, '/')) // Custom AKS Key Vault User role
//     keyVaultName: keyvaultName
//   }
// }
