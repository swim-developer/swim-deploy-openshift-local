# SWIM DNOTAM Provider -- Helm Chart

## Prerequisites

- Helm 3.x installed
- `kubectl` or `oc` CLI authenticated to your cluster
- Namespace `swim-demo` exists
- cert-manager installed with `swim-ca-issuer` ClusterIssuer
- `swim-ca-bundle` ConfigMap in `swim-demo`
- PostgreSQL, Kafka, and AMQP broker (Artemis) available
- RHBK (Keycloak) realm `swim` configured

## Quick Start

### OpenShift / OpenShift Local (CRC)

```bash
# Install with default values (Routes enabled)
helm install swim-dnotam-provider . -n swim-demo

# Or with custom values
helm install swim-dnotam-provider . -n swim-demo -f my-values.yaml
```

### Kubernetes / minikube

Disable OpenShift Routes and create your own Ingress resources:

```bash
helm install swim-dnotam-provider . -n swim-demo \
  --set route.enabled=false \
  --set ingress.enabled=true \
  --set ingress.className=nginx

# Access locally via port-forward
kubectl port-forward svc/swim-dnotam-provider 8080:8080 -n swim-demo
```

On minikube, if cert-manager is not installed:

```bash
minikube addons enable cert-manager
```

## Customizing Values

```bash
# Change cluster domain (affects Routes and Certificate DNS names)
helm install swim-dnotam-provider . -n swim-demo \
  --set clusterDomain=apps.my-cluster.example.com

# Change OIDC configuration
helm install swim-dnotam-provider . -n swim-demo \
  --set oidc.authServerUrl=https://keycloak.example.com/realms/swim \
  --set oidc.clientSecret=my-secret

# Change database credentials
helm install swim-dnotam-provider . -n swim-demo \
  --set secret.postgresUser=myuser \
  --set secret.postgresPassword=mypassword

# Disable optional components
helm install swim-dnotam-provider . -n swim-demo \
  --set hpa.enabled=false \
  --set serviceMonitor.enabled=false \
  --set serverCert.enabled=false
```

### Key Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namespace` | `swim-demo` | Target namespace |
| `clusterDomain` | `apps.ocp4.masales.cloud` | Cluster apps domain |
| `image.tag` | `latest` | Image tag |
| `replicas` | `1` | Number of replicas |
| `route.enabled` | `true` | Create OpenShift Routes (HTTP + mTLS) |
| `ingress.enabled` | `false` | Create Kubernetes Ingress |
| `ingress.className` | `""` | Ingress class (nginx, traefik, etc.) |
| `serverCert.enabled` | `true` | Create cert-manager Certificate |
| `hpa.enabled` | `true` | Enable autoscaling |
| `serviceMonitor.enabled` | `true` | Enable Prometheus metrics |
| `oidc.clientSecret` | `L3wFb...` | OIDC client secret |

## Upgrade

```bash
helm upgrade swim-dnotam-provider . -n swim-demo
```

## Uninstall

```bash
helm uninstall swim-dnotam-provider -n swim-demo
```

## Platform Compatibility

| Resource | OpenShift | OpenShift Local | Kubernetes | minikube |
|----------|-----------|-----------------|------------|----------|
| Deployment, Service, ConfigMap, Secret | Yes | Yes | Yes | Yes |
| HPA | Yes | Yes | Yes | Yes |
| Route (HTTP/mTLS) | Yes | Yes | No | No |
| Ingress | Yes (4) | Yes (4) | Yes | Yes |
| Certificate (cert-manager) | Yes | Yes | Yes (2) | Yes (2) |
| ServiceMonitor | Yes (3) | Yes (3) | Yes (3) | Yes (3) |

(1) Disable Routes and use Ingress instead on vanilla Kubernetes.
(2) Requires cert-manager installed. On minikube: `minikube addons enable cert-manager`.
(3) Requires Prometheus Operator installed in the cluster.
(4) Disable route, enable ingress. OpenShift also supports Ingress via the built-in router.
