# Sample - Landing zone AKS applications

<https://github.com/Azure/Enterprise-Scale/blob/main/docs/wiki/How-Enterprise-Scale-Works.md#landing-zone-owners-responsibilities>

# TODO

- Assign Identities
az aks pod-identity add --cluster-name <cluster-name> -g lz-apps-oink-eastus2-001 --namespace core-platform -n cert-provider --binding-selector cert-provider --identity-resource-id <resource-id>

az aks pod-identity add --cluster-name <cluster-name> -g lz-apps-oink-eastus2-001 --namespace core-platform -n keda-operator --binding-selector keda-operator --identity-resource-id <resource-id>

az aks pod-identity add --cluster-name <cluster-name> -g lz-apps-oink-eastus2-001 --namespace core-monitoring -n grafana-operator --binding-selector grafana-operator --identity-resource-id <resource-id>
