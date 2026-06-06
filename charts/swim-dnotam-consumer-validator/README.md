# SWIM DNOTAM Consumer Validator, Helm Chart

## Prerequisites

- Helm 3.x installed
- `kubectl` or `oc` CLI authenticated to your cluster
- Namespace `swim-demo` exists
- Shared infrastructure deployed via `make infra-all` (from the repo root), which provides:
  - cert-manager with `swim-ca-issuer` ClusterIssuer
  - `validator-artemis` AMQP broker (shared by all consumer-validators)
  - MariaDB instance for this validator (`dnotam-consumer-validator-mariadb`)

## Quick Start

### OpenShift (remote cluster)

```bash
helm install swim-dnotam-consumer-validator . -n swim-demo
```

### OpenShift Local (CRC)

```bash
helm install swim-dnotam-consumer-validator . -n swim-demo -f values-crc.yaml
```

The `values-crc.yaml` override adjusts:

| Parameter | Default (remote) | CRC override |
|---|---|---|
| `clusterDomain` | `apps.ocp4.masales.cloud` | `apps-crc.testing` |
| `config.amqpBrokerHost` | `consumer-validator-artemis-hdls-svc...` | `validator-artemis-amqp-0-svc.swim-demo.svc.cluster.local` |

On CRC, the shared `validator-artemis` (deployed by `swim-infra` Helm chart) is used instead of a dedicated Artemis per validator.

### Kubernetes / minikube

Disable OpenShift Routes and enable Ingress:

```bash
helm install swim-dnotam-consumer-validator . -n swim-demo \
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
helm install swim-dnotam-consumer-validator . -n swim-demo \
  --set image.tag=1.2.0

# Change AMQP broker
helm install swim-dnotam-consumer-validator . -n swim-demo \
  --set config.amqpBrokerHost=my-artemis.my-namespace.svc.cluster.local \
  --set amqp.username=myuser \
  --set amqp.password=mypassword

# Change cluster domain (affects Route hostnames and Certificate DNS names)
helm install swim-dnotam-consumer-validator . -n swim-demo \
  --set clusterDomain=apps.my-cluster.example.com

# Disable certificates (if managing them externally)
helm install swim-dnotam-consumer-validator . -n swim-demo \
  --set serverCert.enabled=false \
  --set clientCert.enabled=false

# Change event generator settings
helm install swim-dnotam-consumer-validator . -n swim-demo \
  --set config.eventGeneratorEnabled=false
```

### Key Values

| Parameter | Default | Description |
|-----------|---------|-------------|
| `namespace` | `swim-demo` | Target namespace |
| `appName` | `consumer-validator` | Application name used in resource names |
| `clusterDomain` | `apps.ocp4.masales.cloud` | Cluster apps domain |
| `image.tag` | `latest` | Image tag |
| `replicas` | `1` | Number of replicas |
| `route.enabled` | `true` | Create OpenShift Routes (HTTP + mTLS) |
| `ingress.enabled` | `false` | Create Kubernetes Ingress |
| `ingress.className` | `""` | Ingress class (nginx, traefik, etc.) |
| `serverCert.enabled` | `true` | Create server TLS Certificate |
| `clientCert.enabled` | `true` | Create client mTLS Certificate |
| `config.eventGeneratorEnabled` | `true` | Enable the DNOTAM event generator |
| `amqp.username` | `admin` | AMQP broker username |
| `amqp.password` | `admin` | AMQP broker password |

## Values Files

| File | Purpose |
|---|---|
| `values.yaml` | Default values targeting the remote OpenShift cluster (`apps.ocp4.masales.cloud`) |
| `values-crc.yaml` | Overrides for CRC local (`apps-crc.testing`, shared `validator-artemis`) |

## Upgrade

```bash
helm upgrade swim-dnotam-consumer-validator . -n swim-demo
```

## Uninstall

```bash
helm uninstall swim-dnotam-consumer-validator -n swim-demo
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
