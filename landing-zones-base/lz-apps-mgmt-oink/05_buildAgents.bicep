param location string = resourceGroup().location
param githubContainerAppName string
param containerEnvName string
param githubAgentImage string
param workspaceName string
param isInternal bool = false
param identityName string
@secure()
param githubPAT string

param containerappInfraSubnetId string
param containerappRuntimeSubnetId string

var common = json(loadTextContent('./common.json'))

var commonTags = union(common.tags, {
  component: 'devops'
})

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: common.acrName
  scope: resourceGroup(common.acrRgName)
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: workspaceName
}

resource devopsContainerEnv 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: containerEnvName
  tags: commonTags
  location: location
  properties: {
    vnetConfiguration: {
      internal: isInternal
      infrastructureSubnetId: containerappInfraSubnetId
      runtimeSubnetId: containerappRuntimeSubnetId
      dockerBridgeCidr: '10.1.0.1/16'
      platformReservedCidr: '10.0.0.0/16'
      platformReservedDnsIP: '10.0.0.2'
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: listKeys(workspace.id, '2021-12-01-preview').primarySharedKey
      }
    }
  }
}

var acrCredentials = acr.listCredentials()
var acrServer = '${common.acrName}${environment().suffixes.acrLoginServer}'
var containerAppKeyEnvName = 'acrkey'
var ghTokenAppKeyEnvName = 'github-token'

// module identity '../../common-bicep/identity/userassigned.bicep' = {
//   name: 'devopsIdentity'
//   params: {
//     identityName: 'oink-apps-mgmt-devops'
//     location: location
//     tags: commonTags
//   }
// }
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: identityName
}

module acrPush '../../common-bicep/identity/acrrole.bicep' = {
  name: 'acrPushaccess'
  scope: resourceGroup(common.acrRgName)
  params: {
    principalId: identity.properties.principalId
    roleGuid: '8311e382-0749-4cb8-b61a-304f252e45ec' //AcrPush
    acrName: common.acrName
  }
}

resource githubRunnerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: '${githubContainerAppName}-004'
  location: location

  tags: union(commonTags, {
    instance: 'github-runner'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    configuration: {
      secrets: [
        {
          name: containerAppKeyEnvName
          value: acrCredentials.passwords[0].value ?? ''
        }
        {
          name: ghTokenAppKeyEnvName
          value: githubPAT // There seems to be an issue with ContainerApp secrets from KeyVaults
        }
      ]
      registries: [
        {
          passwordSecretRef: containerAppKeyEnvName
          server: acrServer
          username: acrCredentials.username
        }
      ]
    }
    template: {
      scale: {
        maxReplicas: 10
        minReplicas: 1
      }
      containers: [
        {
          image: '${acrServer}/${githubAgentImage}'
          name: 'github-runner'
          command: []
          env: [
            {
              name: 'REPO_OWNER'
              value: 'colincmac'
            }
            {
              name: 'REPO_NAME'
              value: 'oink-financial-account-mgmt'
            }
            {
              name: 'GH_TOKEN'
              secretRef: ghTokenAppKeyEnvName
            }
            {
              name: 'ACTIONS_RUNNER_INPUT_URL'
              value: 'https://github.com/colincmac/oink-financial-account-mgmt'
            }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
    }
    managedEnvironmentId: devopsContainerEnv.id
  }
}

// TODO: Enable once identities can access ACR images and Key Vault secrets.

// param aksCustomKeyVaultRoleGuid string = '89a199fe-c3ac-4f9e-8c5e-b9b4b778847f'

// module acrPull '../../common-bicep/identity/acrrole.bicep' = {
//   name: 'acrPullaccess'
//   params: {
//     principalId: githubRunnerApp.identity.principalId
//     roleGuid: '7f951dda-4ed3-4680-a7ca-43fe172d538d' //AcrPull
//     acrName: common.acrName
//   }
// }

// module vault '../../common-bicep/keyvault/keyvault.bicep' = {
//   name: devopsKeyVaultName
//   params: {
//     location: location
//     name: devopsKeyVaultName
//     tenantId: subscription().tenantId
//     tags: union(common.tags, {
//       component: 'secrets'
//     })
//   }
// }

// module keyVaultSecretsUser '../../common-bicep/identity/keyVaultRoles.bicep' = {
//   name: 'aksKeyVaultSecretUserRole'
//   dependsOn: [
//     vault
//   ]
//   params: {
//     principalId: githubRunnerApp.identity.principalId
//     roleGuid: aksCustomKeyVaultRoleGuid // Custom AKS Key Vault User role
//     keyVaultName: devopsKeyVaultName
//   }
// }
