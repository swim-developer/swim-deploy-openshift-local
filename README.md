# SWIM on OpenShift Local

Deploy the complete SWIM (System Wide Information Management) ecosystem on your
local machine using Red Hat OpenShift Local (formerly CodeReady Containers).

This project is self-contained. Everything you need to deploy the full SWIM
Reference Architecture is included: Helm charts, operator subscriptions,
infrastructure configuration, and pre-built add-ons.

By the end of this tutorial you will have a fully functional SWIM environment
running locally with Digital NOTAM services, ED-254 Arrival Sequence services,
validators, message brokers, databases, and example applications.

## What Gets Deployed

### Shared Infrastructure

| Component | Description |
|-----------|-------------|
| **Kafka** (AMQ Streams) | Event streaming with pre-configured DNOTAM and ED-254 topics |
| **Artemis** (AMQ Broker) | AMQP 1.0 message broker with mTLS and Keycloak JWT authentication |
| **MongoDB** | Document store for consumer services (DNOTAM and ED-254) |
| **PostgreSQL** | Relational database for provider services (subscriptions, events, audit) |
| **MariaDB** | Relational database for validator web applications |
| **Keycloak** (RHBK) | OAuth 2.0 / OIDC identity provider with SWIM realm |
| **cert-manager** | Automated X.509 certificate management with SWIM CA |

### SWIM Services

| Service | Role | Description |
|---------|------|-------------|
| **swim-dnotam-provider** | AISP | Publishes Digital NOTAM events to subscribed consumers via AMQP 1.0. Manages subscriptions, topics, and WFS feature queries. Consumes events from Kafka and distributes them to per-subscriber queues on Artemis. |
| **swim-dnotam-consumer** | ANSP | Receives Digital NOTAM events from external providers. Manages subscriptions automatically, validates AIXM XML payloads, and routes events to 6 categorized Kafka topics (closures, restrictions, surface conditions, airspace, hazards, others). |
| **swim-ed254-provider** | AMAN Operator | Publishes ED-254 Arrival Sequence data to downstream ATSUs. Implements the EUROCAE ED-254 standard for Extended AMAN, including bidirectional CommunicateProblems for operational error reporting. |
| **swim-ed254-consumer** | Downstream ATSU | Receives arrival sequence data from upstream AMAN providers. Processes ED-254 messages (ArrivalDataType, AMANProviderException, Heartbeat, Subscription) and routes them to Kafka topics. |

### Validators

Validators simulate the counterpart of each SWIM service, eliminating the
dependency on external providers during development and testing. They also
enable the creation of failure scenarios that would be impossible to reproduce
against a real provider.

| Validator | Simulates | Description |
|-----------|-----------|-------------|
| **swim-dnotam-consumer-validator** | External DNOTAM provider (AISP) | Exposes a Subscription Manager API, generates test events, includes a built-in AMQP broker with per-subscription heartbeat. |
| **swim-dnotam-provider-validator** | External DNOTAM consumer (ANSP) | Subscribes to the DNOTAM provider under test, receives events, validates conformance against SWIM standards. Web UI with real-time event visualization. |
| **swim-ed254-consumer-validator** | External ED-254 provider (AMAN) | Simulates an upstream AMAN system, publishes arrival sequence test data to the ED-254 consumer. |
| **swim-ed254-provider-validator** | External ED-254 consumer (ATSU) | Subscribes to the ED-254 provider, validates arrival sequence delivery and conformance. |

### Example Applications

| Application | Description |
|-------------|-------------|
| **DNOTAM Operations Dashboard** | Real-time situational awareness for flight operations, ATC, and airport management. Consumes from 6 categorized Kafka topics and displays NOTAM events in an interactive map view, event timeline, critical alerts panel, and compliance audit dashboard. Built with Quarkus, React 19, and PatternFly 6. |
| **DNOTAM Event Publisher** | AISP event injection tool for testing and demonstration. Browse pre-configured DNOTAM scenario templates (runway closures, surface conditions, obstacles, airspace activations), preview XML content, and publish events to the SWIM provider via HTTP trigger or directly to Kafka. |
| **ED-254 Arrival Flow Manager** | Downstream ATSU arrival sequence coordination dashboard. Displays real-time arrival timelines from upstream AMAN, subscription management, and AMAN operational status monitoring. |
| **ED-254 Collaborative AMAN Client** | Upstream AMAN operator dashboard for monitoring and managing arrival sequence distribution. Includes subscriber registry, publication metrics, exception management, and system health diagnostics. |

## Prerequisites

### 1. Podman Desktop (Recommended)

[Podman Desktop](https://podman-desktop.io/) provides a graphical interface for
managing containers, Kubernetes, and OpenShift environments. It simplifies the
installation and configuration of OpenShift Local, including resource allocation,
cluster lifecycle, and developer workflows. It also integrates with Kubernetes
and OpenShift clusters for monitoring pods, logs, and deployments.

Podman Desktop is free and available for macOS, Windows, and Linux.

### 2. OpenShift Local (CRC)

Download and install OpenShift Local:

- [OpenShift Local](https://developers.redhat.com/products/openshift-local)
- [Download and Install](https://developers.redhat.com/content-gateway/link/3875380)

A free Red Hat account is required to download. The same account works for
accessing container images from `registry.redhat.io`.

OpenShift Local can also be installed and configured through Podman Desktop,
which provides a guided setup experience.

**Recommended resources for the full SWIM stack:**

```
crc config set cpus 8
crc config set memory 24576
```

### 3. Command-Line Tools

| Tool | Purpose | Install |
|------|---------|---------|
| `oc` | OpenShift CLI | Included with CRC (`crc oc-env`) |
| `helm` | Kubernetes package manager | [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/). Windows: `choco install kubernetes-helm`. macOS: `brew install helm` |
| `make` | Build automation (optional) | Pre-installed on macOS and Linux. Windows: `choco install make` |
| `git` | Version control | Pre-installed on macOS and Linux. Windows: [gitforwindows.org](https://gitforwindows.org/) |

### 4. Red Hat Developer Account

The SWIM infrastructure uses container images from `registry.redhat.io`
(Keycloak, AMQ Broker, PostgreSQL). A
[Red Hat Developer](https://developers.redhat.com) account is free and grants
access to all Red Hat products for development and demonstration purposes.
Production deployments require an enterprise subscription.

## Step-by-Step Deployment

### Step 1: Start OpenShift Local

```bash
crc setup       # first time only
crc start
```

After CRC starts, configure your shell:

```bash
eval $(crc oc-env)
oc login -u kubeadmin https://api.crc.testing:6443
```

The kubeadmin password is displayed by `crc start` or can be retrieved with
`crc console --credentials`.

### Step 2: Install OLM Operators

The SWIM platform requires five operators from the OpenShift OperatorHub:

- **cert-manager** (community) for automated TLS certificate management
- **AMQ Streams** (Red Hat) for Apache Kafka
- **AMQ Streams Console** (Red Hat) for Kafka web UI
- **AMQ Broker** (Red Hat) for AMQP 1.0 messaging
- **RHBK** (Red Hat Build of Keycloak) for OAuth 2.0 / OIDC

```bash
oc apply -f operators/cert-manager-operator.yaml
oc apply -f operators/amq-streams-operator.yaml
oc apply -f operators/amq-streams-console-operator.yaml
oc apply -f operators/amq-broker-operator.yaml
oc apply -f operators/rhbk-operator.yaml
```

Wait for all operator CRDs to become available before proceeding. On a fresh
CRC instance this typically takes 2-5 minutes.

```bash
oc wait --for=condition=Established crd/kafkas.kafka.strimzi.io --timeout=300s
oc wait --for=condition=Established crd/clusterissuers.cert-manager.io --timeout=300s
oc wait --for=condition=Established crd/activemqartemises.broker.amq.io --timeout=300s
oc wait --for=condition=Established crd/keycloaks.k8s.keycloak.org --timeout=300s
```

> **Makefile shortcut:** `make operators && make operators-wait`

### Step 3: Create the Namespace

```bash
oc new-project swim-demo
```

### Step 4: Create Keycloak SPI Secret

The Keycloak SWIM Role SPI adds per-user AMQP queue role mappings, required
for Artemis JWT authentication. The pre-built JAR is included in `lib/`.

```bash
oc create secret generic keycloak-swim-role-spi -n swim-demo \
  --from-file=keycloak-swim-role-spi.jar=lib/keycloak-swim-role-spi.jar
```

> **Makefile shortcut:** `make spi`

### Step 5: Deploy Shared Infrastructure

This installs the SWIM PKI (CA + ClusterIssuer), Kafka with all DNOTAM and
ED-254 topics, Artemis brokers (validator and provider), MongoDB, PostgreSQL,
MariaDB, and Keycloak with the SWIM realm.

```bash
helm upgrade --install swim-infra charts/swim-infra \
  -n swim-demo \
  -f charts/swim-infra/values.yaml
```

Wait for all infrastructure pods to reach the `Running` state before proceeding.
Kafka and Keycloak are the slowest to initialize.

```bash
oc get pods -n swim-demo -w
```

> **Makefile shortcut:** `make infra`

### Step 6: Create Artemis SSL Secrets

Once cert-manager has issued the Artemis TLS certificates, create the SSL
secrets that the brokers need for AMQP over TLS. Wait for the certificates
first:

```bash
oc wait --for=condition=Ready certificate/validator-artemis-amqp -n swim-demo --timeout=120s
oc wait --for=condition=Ready certificate/provider-artemis-amqp -n swim-demo --timeout=120s
```

Then create the secrets by extracting the JKS keystores from the
cert-manager-generated TLS secrets:

```bash
# Validator Artemis
KS=$(oc get secret validator-artemis-amqp-tls -n swim-demo -o jsonpath='{.data.keystore\.jks}')
TS=$(oc get secret validator-artemis-amqp-tls -n swim-demo -o jsonpath='{.data.truststore\.jks}')
PW=$(printf '%s' "$(oc get secret validator-artemis-keystore-password -n swim-demo \
  -o jsonpath='{.data.password}' | base64 -d)" | base64)

oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: validator-artemis-ssl-secret
  namespace: swim-demo
type: Opaque
data:
  broker.ks: $KS
  client.ts: $TS
  keyStorePassword: $PW
  trustStorePassword: $PW
EOF

# Provider Artemis
KS=$(oc get secret provider-artemis-amqp-tls -n swim-demo -o jsonpath='{.data.keystore\.jks}')
TS=$(oc get secret provider-artemis-amqp-tls -n swim-demo -o jsonpath='{.data.truststore\.jks}')
PW=$(printf '%s' "$(oc get secret provider-artemis-keystore-password -n swim-demo \
  -o jsonpath='{.data.password}' | base64 -d)" | base64)

oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: provider-artemis-ssl-secret
  namespace: swim-demo
type: Opaque
data:
  broker.ks: $KS
  client.ts: $TS
  keyStorePassword: $PW
  trustStorePassword: $PW
EOF
```

> **Makefile shortcut:** `make infra-artemis-ssl`

### Step 7: Deploy Digital NOTAM (DNOTAM)

Start with the DNOTAM module. Deploy the provider and consumer first, then
their respective validators.

#### DNOTAM Services

```bash
helm upgrade --install swim-dnotam-provider charts/swim-dnotam-provider \
  -n swim-demo \
  -f charts/swim-dnotam-provider/values.yaml

helm upgrade --install swim-dnotam-consumer charts/swim-dnotam-consumer \
  -n swim-demo \
  -f charts/swim-dnotam-consumer/values.yaml
```

#### DNOTAM Validators

```bash
helm upgrade --install swim-dnotam-consumer-validator charts/swim-dnotam-consumer-validator \
  -n swim-demo \
  -f charts/swim-dnotam-consumer-validator/values.yaml

helm upgrade --install swim-dnotam-provider-validator charts/swim-dnotam-provider-validator \
  -n swim-demo \
  -f charts/swim-dnotam-provider-validator/values.yaml
```

Verify all four pods are running before proceeding:

```bash
oc get pods -n swim-demo -l app.kubernetes.io/part-of=swim-dnotam
```

> **Makefile shortcut:** `make dnotam`

### Step 8: Add More Modules (ED-254)

Each SWIM module follows the same pattern: two services (provider and
consumer) and two validators. The only difference between modules is which
charts to use.

> **Resource consideration:** OpenShift Local runs on a single VM with
> limited CPU and memory. Running all modules simultaneously is possible
> with 8 CPUs and 24 GB RAM, but on constrained machines you may prefer to
> test one module at a time. Remove the current module before deploying
> the next one to stay within resource limits.

#### (Optional) Remove DNOTAM before deploying ED-254

If you want to free resources before deploying the ED-254 module:

```bash
helm uninstall swim-dnotam-provider-validator -n swim-demo
helm uninstall swim-dnotam-consumer-validator -n swim-demo
helm uninstall swim-dnotam-consumer -n swim-demo
helm uninstall swim-dnotam-provider -n swim-demo
```

#### ED-254 Services

```bash
helm upgrade --install swim-ed254-provider charts/swim-ed254-provider \
  -n swim-demo \
  -f charts/swim-ed254-provider/values.yaml

helm upgrade --install swim-ed254-consumer charts/swim-ed254-consumer \
  -n swim-demo \
  -f charts/swim-ed254-consumer/values.yaml
```

#### ED-254 Validators

```bash
helm upgrade --install swim-ed254-consumer-validator charts/swim-ed254-consumer-validator \
  -n swim-demo \
  -f charts/swim-ed254-consumer-validator/values.yaml

helm upgrade --install swim-ed254-provider-validator charts/swim-ed254-provider-validator \
  -n swim-demo \
  -f charts/swim-ed254-provider-validator/values.yaml
```

Verify all four ED-254 pods are running:

```bash
oc get pods -n swim-demo -l app.kubernetes.io/part-of=swim-ed254
```

> **Makefile shortcut:** `make ed254`

### Step 9: Deploy DNOTAM Example Applications (Optional)

Two demonstration applications complement the DNOTAM services and illustrate
how real-world clients integrate with the SWIM platform from each end of the
pipeline.

| Application | Simulates | Upstream dependency |
|-------------|-----------|---------------------|
| **DNOTAM Operations Dashboard** | ANSP / airport operations centre — consumes categorized DNOTAM events and displays them in a real-time situational awareness UI | `swim-dnotam-consumer` must be running and publishing to Kafka |
| **DNOTAM Event Publisher** | AISP / EAD operator workstation — injects pre-built AIXM 5.1.1 event templates into the DNOTAM provider via HTTP trigger or Kafka | `swim-dnotam-provider` must be running |

Together they form a complete end-to-end demonstration loop: publish an event
in the publisher, watch it appear in the dashboard.

#### 9.1 Build the container images

Run the following from the workspace root. Each `make jvm` target builds
multi-arch images for `linux/amd64` and `linux/arm64` and pushes them to
`quay.io/masales`. Source code is at
[github.com/swim-developer/swim-example-apps](https://github.com/swim-developer/swim-example-apps).

```bash
cd example-apps/dnotam-operations-dashboard
make jvm-backend     # backend only
make jvm-frontend    # frontend only
# or: make jvm       # both at once

cd ../dnotam-event-publisher
make jvm-backend
make jvm-frontend

cd ../..
```

Confirm the images are available on `quay.io` before proceeding:

```
quay.io/masales/dnotam-dashboard-backend:latest
quay.io/masales/dnotam-dashboard-frontend:latest
quay.io/masales/dnotam-event-publisher-backend:latest
quay.io/masales/dnotam-event-publisher-frontend:latest
```

#### 9.2 Deploy to OpenShift Local

```bash
helm upgrade --install dnotam-dashboard charts/dnotam-dashboard \
  -n swim-demo \
  -f charts/dnotam-dashboard/values.yaml

helm upgrade --install dnotam-event-publisher charts/dnotam-event-publisher \
  -n swim-demo \
  -f charts/dnotam-event-publisher/values.yaml
```

#### 9.3 Verify

Check that both pods are running:

```bash
oc get pods -n swim-demo -l app.kubernetes.io/part-of=swim-dnotam-apps
```

Open the applications using the routes below (also listed in the table at
the end of Step 10):

| Application | URL |
|-------------|-----|
| DNOTAM Operations Dashboard | `https://dnotam-dashboard.apps-crc.testing` |
| DNOTAM Event Publisher | `https://dnotam-event-publisher.apps-crc.testing` |

To confirm the end-to-end loop works:

1. Open the **DNOTAM Event Publisher** and publish a `RWY.CLS` event using
   the HTTP Trigger delivery mode.
2. Open the **DNOTAM Operations Dashboard** and verify the event appears in
   the Critical Alerts panel and the Event Timeline tab.

> **Makefile shortcut (deploy both):** `make dnotam-apps`

#### 9.4 ED-254 Example Applications

The ED-254 module ships equivalent applications following the same pattern:
**ED-254 Arrival Flow Manager** (downstream ATSU consumer UI) and
**ED-254 Collaborative AMAN Client** (upstream AMAN operator dashboard).
Their build and deployment steps mirror those above — replace the chart names
and image names accordingly.

```bash
helm upgrade --install ed254-arrival-flow-manager charts/ed254-arrival-flow-manager \
  -n swim-demo \
  -f charts/ed254-arrival-flow-manager/values.yaml

helm upgrade --install ed254-aman-client charts/ed254-aman-client \
  -n swim-demo \
  -f charts/ed254-aman-client/values.yaml
```

> **Makefile shortcut (all four apps):** `make apps`

### Step 10: Verify

Check that all Helm releases are deployed:

```bash
helm list -n swim-demo
```

Check that all pods are running:

```bash
oc get pods -n swim-demo
```

Check available routes:

```bash
oc get routes -n swim-demo
```

Key endpoints on CRC:

| Service | URL |
|---------|-----|
| Keycloak | `https://rhbk.apps-crc.testing` (username `admin`, password `password`) |
| DNOTAM Provider (mTLS) | `https://swim-dnotam-provider-mtls.apps-crc.testing` |
| ED-254 Provider (mTLS) | `https://swim-ed254-provider-mtls.apps-crc.testing` |
| DNOTAM Provider Validator | `https://dnotam-provider-validator-swim-demo.apps-crc.testing` |
| DNOTAM Dashboard | `https://dnotam-dashboard.apps-crc.testing` |
| DNOTAM Event Publisher | `https://dnotam-event-publisher.apps-crc.testing` |
| ED-254 Arrival Flow Manager | `https://ed254-arrival-flow-manager.apps-crc.testing` |
| ED-254 AMAN Client | `https://ed254-aman-client.apps-crc.testing` |

> **Makefile shortcut:** `make status`

## Makefile (Optional)

A Makefile is included for convenience. It wraps all the commands above into
short targets:

| Target | Description |
|--------|-------------|
| `make all` | Deploy everything in order (steps 2-9) |
| `make operators` | Install OLM operator subscriptions |
| `make operators-wait` | Wait for operator CRDs |
| `make spi` | Create Keycloak SPI secret |
| `make infra` | Deploy shared infrastructure |
| `make infra-artemis-ssl` | Create Artemis SSL secrets |
| `make services` | Deploy all 4 SWIM services |
| `make validators` | Deploy all 4 validators |
| `make apps` | Deploy all 4 example applications |
| `make status` | Show pods, PVCs, routes, and Helm releases |
| `make destroy` | Remove everything in reverse order |
| `make remove-apps` | Remove example applications only |
| `make remove-validators` | Remove validators only |
| `make remove-services` | Remove SWIM services only |
| `make remove-infra` | Remove shared infrastructure only |

Run `make help` for the full list.

## Teardown

Remove components in reverse order:

```bash
# Example applications
helm uninstall ed254-aman-client -n swim-demo
helm uninstall ed254-arrival-flow-manager -n swim-demo
helm uninstall dnotam-dashboard -n swim-demo
helm uninstall dnotam-event-publisher -n swim-demo

# Validators
helm uninstall swim-ed254-provider-validator -n swim-demo
helm uninstall swim-ed254-consumer-validator -n swim-demo
helm uninstall swim-dnotam-provider-validator -n swim-demo
helm uninstall swim-dnotam-consumer-validator -n swim-demo

# SWIM services
helm uninstall swim-ed254-consumer -n swim-demo
helm uninstall swim-ed254-provider -n swim-demo
helm uninstall swim-dnotam-consumer -n swim-demo
helm uninstall swim-dnotam-provider -n swim-demo

# Shared infrastructure
helm uninstall swim-infra -n swim-demo

# Keycloak SPI secret
oc delete secret keycloak-swim-role-spi -n swim-demo

# OLM operators
oc delete -f operators/rhbk-operator.yaml
oc delete -f operators/amq-broker-operator.yaml
oc delete -f operators/amq-streams-console-operator.yaml
oc delete -f operators/amq-streams-operator.yaml
oc delete -f operators/cert-manager-operator.yaml
```

> **Makefile shortcut:** `make destroy`

## Project Structure

```
swim-deploy-openshift-local/
  README.md                              This tutorial
  Makefile                               Deployment automation
  operators/                             OLM operator subscriptions
    amq-broker-operator.yaml             AMQ Broker 7.14.x
    amq-streams-operator.yaml            AMQ Streams (Kafka)
    amq-streams-console-operator.yaml    AMQ Streams Console
    cert-manager-operator.yaml           cert-manager (community)
    rhbk-operator.yaml                   Red Hat Build of Keycloak
  lib/
    keycloak-swim-role-spi.jar           Keycloak SPI for AMQP JWT roles
  charts/
    swim-infra/                          Shared infrastructure (PKI, Kafka, Artemis, databases, Keycloak)
    swim-dnotam-provider/                DNOTAM provider (AISP)
    swim-dnotam-consumer/                DNOTAM consumer (ANSP)
    swim-ed254-provider/                 ED-254 provider (AMAN operator)
    swim-ed254-consumer/                 ED-254 consumer (downstream ATSU)
    swim-dnotam-consumer-validator/      Mock DNOTAM provider for testing the consumer
    swim-dnotam-provider-validator/      Mock DNOTAM consumer for testing the provider
    swim-ed254-consumer-validator/       Mock ED-254 provider for testing the consumer
    swim-ed254-provider-validator/       Mock ED-254 consumer for testing the provider
    dnotam-dashboard/                    DNOTAM real-time operations dashboard
    dnotam-event-publisher/              DNOTAM event injection tool
    ed254-arrival-flow-manager/          ED-254 arrival sequence dashboard
    ed254-aman-client/                   ED-254 AMAN operator dashboard
```

## Compliance Standards

This deployment implements the following aviation standards:

- **EUROCONTROL SPEC-170** (SWIM-TI Yellow Profile) for service interfaces
- **EU Regulation 2021/116** (Common Project 1) for SWIM adoption
- **EUROCAE ED-254** for Extended AMAN arrival sequence distribution
- **AIXM 5.1.1** for aeronautical information exchange
- **FIXM 4.3** for flight information exchange
- **AMQP 1.0 over TLS 1.3** for secure publish/subscribe messaging

## License

Apache License 2.0
