# Sample - Landing Zone Architecture Infrastructure as Code with Bicep

**This is a work in progress. This repo is a part of a larger effort to demonstrate secure workloads on Azure. This is for reference only and not meant for production workloads**

This repo is under heavy construction.

Core infrastructure to support Data and App workloads in a secure Azure environment.
<https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/design-areas>

## Related GitHub repositories

### Supporting

|Item|Description|
|----|-----|
|[Utility Docker Images](https://github.com/colincmac/oink-docker-images)|Images used to support Ops scenarios. Built using [ACR Tasks](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tasks-overview)|
|[Helm Charts](https://github.com/colincmac/oink-helm-charts)|Helm charts to support GitOps scenarios|
|[AKS GitOps - Core Platform](https://github.com/colincmac/aks-lz-manifests)|Flux multi-tenant configuration in AKS - Core Platform|
|[AKS GitOps - Shared Services](https://github.com/colincmac/aks-lz-shared-services-manifests)|Flux multi-tenant configuration in AKS - Shared Services|
|[Landing Zone IaC](https://github.com/colincmac/aks-lz-shared-services-manifests)|Flux multi-tenant configuration in AKS - Shared Services|

### Application Workloads

|Item|Description|
|----|-----|
|[Shared .NET Libraries](https://github.com/colincmac/oink-core-dotnet)|Base .NET seedwork for implementing CQRS, EventSourcing, and DDD|
|[Financial Account Management](https://github.com/colincmac/oink-financial-account-mgmt)|Serverless Azure Function used to demonstrate several concepts|

## Resources

- Link to supporting information
- Link to similar sample
- ...
