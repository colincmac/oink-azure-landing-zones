param location string = resourceGroup().location
param acrPoolName string = 'default-pool'
param devopsKeyVaultName string = 'oink-devops-config'
param devopsGithubPATSecretName string = 'github-repo-pat'

var baseTaskName = 'build-fin-acct-mgmt-api'

var base64TaskContent = loadFileAsBase64('./resources/acct-mgmt-acr-task.yaml')
var common = json(loadTextContent('common.json'))

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: common.acrName
  scope: resourceGroup(common.acrRgName)
}

resource devopsVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: devopsKeyVaultName
  scope: resourceGroup(common.appsMgmtRgName)
}

module githubRunnerAcrTaskProd '../common-bicep/acr/acr-source-triggered-encoded-task.bicep' = {
  name: 'build-github-runner-task-prod'
  params: {
    location: location
    githubPAT: devopsVault.getSecret(devopsGithubPATSecretName)
    registryName: common.acrName
    taskName: '${baseTaskName}-prod'
    base64TaskContent: base64TaskContent
    sourceName: 'default'
    sourceBranch: 'main'
    soureRepoUrl: 'https://github.com/colincmac/oink-financial-account-mgmt#main'
    contextPath: 'https://github.com/colincmac/oink-financial-account-mgmt#main'
    agentPoolName: acrPoolName
    sourceTriggerEvents: [
      'commit'
    ]
  }
}
