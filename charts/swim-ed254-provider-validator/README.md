# SWIM ED-254 Provider Validator, Helm Chart

## Prerequisites

- Helm 3.x installed
- `kubectl` or `oc` CLI authenticated to your cluster
- Namespace `swim-demo` exists
- cert-manager installed with `swim-ca-issuer` ClusterIssuer
- RHBK (Keycloak) realm `swim` with client `swim-public-client`
- SWIM ED-254 Provider deployed and accessible
- MariaDB instance available

## Quick Start

### OpenShift / OpenShift Local (CRC)

```bash
helm install swim-ed254-provider-validator . -n swim-demo
```

### Kubernetes / minikube

```bash
helm install swim-ed254-provider-validator . -n swim-demo \
  --set route.enabled=false \
  --set ingress.enabled=true \
  --set ingress.className=nginx

kubectl port-forward svc/swim-ed254-provider-validator 8080:8080 -n swim-demo
```

On minikube, if cert-manager is not installed:

```bash
minikube addons enable cert-manager
```

## Customizing Values

```bash
# Change the SWIM Provider API URLs
helm install swim-ed254-provider-validator . -n swim-demo \
  --set config.swimProviderApiUrls="https://my-provider.example.com"

# Change Keycloak configuration
helm install swim-ed254-provider-validator . -n swim-demo \
  --set config.keycloakUrl=https://keycloak.example.com \
  --set config.keycloakRealm=my-realm

# Change MariaDB connection
helm install swim-ed254-provider-validator . -n swim-demo \
  --set config.mariadbHost=my-mariadb \
  --set config.mariadbUsername=myuser \
  --set config.mariadbPassword=mypassword

# Change PVC storage size
helm install swim-ed254-provider-validator . -n swim-demo \
  --set pvc.storage=500Mi

# Disable optional components
helm install swim-ed254-provider-validator . -n swim-demo \
  --set hpa.enabled=false \
  --set serviceMonitor.enabled=false \
  --set clientCert.enabled=false \
  --set pvc.enabled=false
```

### Key Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namespace` | `swim-demo` | Target namespace |
| `clusterDomain` | `apps.ocp4.masales.cloud` | Cluster apps domain |
| `image.tag` | `latest` | Image tag |
| `replicas` | `1` | Number of replicas |
| `route.enabled` | `true` | Create OpenShift Route |
| `ingress.enabled` | `false` | Create Kubernetes Ingress |
| `ingress.className` | `""` | Ingress class (nginx, traefik, etc.) |
| `clientCert.enabled` | `true` | Create client mTLS Certificate |
| `pvc.enabled` | `true` | Create PersistentVolumeClaim |
| `pvc.storage` | `100Mi` | PVC storage size |
| `hpa.enabled` | `true` | Enable HPA (singleton, max 1) |
| `serviceMonitor.enabled` | `true` | Enable Prometheus metrics |
| `secret.certsPassword` | `changeit` | Keystore/truststore password |

## Upgrade

```bash
helm upgrade swim-ed254-provider-validator . -n swim-demo
```

## Uninstall

```bash
helm uninstall swim-ed254-provider-validator -n swim-demo
```

## Platform Compatibility

| Resource | OpenShift | OpenShift Local | Kubernetes | minikube |
|----------|-----------|-----------------|------------|----------|
| Deployment, Service, ConfigMap, Secret | Yes | Yes | Yes | Yes |
| HPA | Yes | Yes | Yes | Yes |
| PVC | Yes | Yes | Yes | Yes |
| Route | Yes | Yes | No | No |
| Ingress | Yes (1) | Yes (1) | Yes | Yes |
| Certificate (cert-manager) | Yes | Yes | Yes (2) | Yes (2) |
| ServiceMonitor | Yes (3) | Yes (3) | Yes (3) | Yes (3) |

(1) Disable route, enable ingress. OpenShift also supports Ingress via the built-in router.
(2) Requires cert-manager installed. On minikube: `minikube addons enable cert-manager`.
(3) Requires Prometheus Operator installed in the cluster.
