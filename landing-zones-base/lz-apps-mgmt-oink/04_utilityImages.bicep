param location string = resourceGroup().location
param poolSubnetId string

@secure()
param githubPAT string

var common = json(loadTextContent('./common.json'))

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: common.acrName
}

resource acrPool 'Microsoft.ContainerRegistry/registries/agentPools@2019-06-01-preview' = {
  name: 'default-pool'
  location: location
  parent: acr
  properties: {
    count: 1
    os: 'Linux'
    tier: 'S2'
    virtualNetworkSubnetResourceId: poolSubnetId
  }
}

module githubRunnerAcrTask '../../common-bicep/acr/acr-source-triggered-docker-task.bicep' = {
  name: 'build-github-runner-task'
  params: {
    location: location
    githubPAT: githubPAT
    registryName: 'colinmac'
    taskName: 'build-devops-github-runner'
    sourceName: 'default'
    sourceBranch: 'main'
    soureRepoUrl: 'https://github.com/colincmac/oink-docker-images#main'
    contextPath: 'https://github.com/colincmac/oink-docker-images#main:github-runner'
    agentPoolName: 'default-pool'
    dockerfilePath: 'Dockerfile'
    imageNames: [
      'utility/devops-github-runner:{{$.Run.ID}}'
    ]
    sourceTriggerEvents: [
      'commit'
    ]
  }
}
