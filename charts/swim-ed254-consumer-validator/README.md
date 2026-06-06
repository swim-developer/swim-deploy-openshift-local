# SWIM ED-254 Consumer Validator, Helm Chart

## Prerequisites

- Helm 3.x installed
- `kubectl` or `oc` CLI authenticated to your cluster
- Namespace `swim-demo` exists
- cert-manager installed with `swim-ca-issuer` ClusterIssuer
- AMQP broker (Artemis) deployed and accessible

## Quick Start

### OpenShift / OpenShift Local (CRC)

```bash
helm install swim-ed254-consumer-validator . -n swim-demo
```

### Kubernetes / minikube

Disable OpenShift Routes:

```bash
helm install swim-ed254-consumer-validator . -n swim-demo \
  --set route.enabled=false \
  --set ingress.enabled=true \
  --set ingress.className=nginx
```

On minikube, if cert-manager is not installed:

```bash
minikube addons enable cert-manager
```

## Customizing Values

```bash
# Change image tag
helm install swim-ed254-consumer-validator . -n swim-demo \
  --set image.tag=1.2.0

# Change AMQP broker
helm install swim-ed254-consumer-validator . -n swim-demo \
  --set config.amqpBrokerHost=my-artemis.my-namespace.svc.cluster.local \
  --set amqp.username=myuser \
  --set amqp.password=mypassword

# Change cluster domain
helm install swim-ed254-consumer-validator . -n swim-demo \
  --set clusterDomain=apps.my-cluster.example.com

# Disable certificates (if managing them externally)
helm install swim-ed254-consumer-validator . -n swim-demo \
  --set serverCert.enabled=false \
  --set clientCert.enabled=false

# Change event generator settings
helm install swim-ed254-consumer-validator . -n swim-demo \
  --set config.eventGeneratorEnabled=false
```

### Key Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namespace` | `swim-demo` | Target namespace |
| `appName` | `ed254-consumer-validator` | Application name used in resource names |
| `clusterDomain` | `apps.ocp4.masales.cloud` | Cluster apps domain |
| `image.tag` | `latest` | Image tag |
| `replicas` | `1` | Number of replicas |
| `route.enabled` | `true` | Create OpenShift Routes (HTTP + mTLS) |
| `ingress.enabled` | `false` | Create Kubernetes Ingress |
| `ingress.className` | `""` | Ingress class (nginx, traefik, etc.) |
| `serverCert.enabled` | `true` | Create server TLS Certificate |
| `clientCert.enabled` | `true` | Create client mTLS Certificate |
| `config.eventGeneratorEnabled` | `true` | Enable the ED-254 event generator |
| `amqp.username` | `admin` | AMQP broker username |
| `amqp.password` | `admin` | AMQP broker password |

## Upgrade

```bash
helm upgrade swim-ed254-consumer-validator . -n swim-demo
```

## Uninstall

```bash
helm uninstall swim-ed254-consumer-validator -n swim-demo
```

## Platform Compatibility

| Resource | OpenShift | OpenShift Local | Kubernetes | minikube |
|----------|-----------|-----------------|------------|----------|
| Deployment, Service, ConfigMap, Secret | Yes | Yes | Yes | Yes |
| Route (HTTP/mTLS) | Yes | Yes | No | No |
| Ingress | Yes (3) | Yes (3) | Yes | Yes |
| Certificate (cert-manager) | Yes | Yes | Yes (2) | Yes (2) |

(1) Disable Routes and use Ingress instead on vanilla Kubernetes.
(2) Requires cert-manager installed. On minikube: `minikube addons enable cert-manager`.
(3) Disable route, enable ingress. OpenShift also supports Ingress via the built-in router.
