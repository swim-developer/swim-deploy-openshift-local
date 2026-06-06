# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SWIM (System Wide Information Management) deployment toolkit for OpenShift Local (CRC). This is a pure infrastructure-as-code repository — no application source code. It contains Helm charts, OLM operator subscriptions, and a Makefile to deploy the complete SWIM Reference Architecture on a local OpenShift cluster.

## Key Commands

```bash
# Full deployment (ordered pipeline)
make all

# Step-by-step deployment (must follow this order)
make operators              # 1. Install OLM operators
make operators-wait         # 2. Wait for CRDs
make spi                    # 3. Keycloak SPI secret
make infra                  # 4. Shared infrastructure (Kafka, Artemis, DBs, Keycloak)
make infra-artemis-ssl      # 5. Artemis SSL secrets from cert-manager certs
make services               # 6. DNOTAM + ED-254 providers and consumers
make validators             # 7. All 4 validators
make apps                   # 8. Example applications (dashboards, publishers)

# Status and teardown
make status                 # Show pods, PVCs, routes, Helm releases
make destroy                # Remove everything in reverse order

# Individual charts (useful when iterating on a single service)
make dnotam-provider
make dnotam-consumer
make ed254-provider
make ed254-consumer
make dnotam-consumer-validator
make dnotam-provider-validator
make ed254-consumer-validator
make ed254-provider-validator
make dnotam-dashboard
make dnotam-event-publisher
make ed254-arrival-flow-manager
make ed254-aman-client

# Selective removal
make remove-apps
make remove-validators
make remove-services
make remove-infra

# Namespace override (default: swim-demo)
make infra NS=my-namespace
```

## Architecture

The platform has four layers deployed in strict order:

1. **OLM Operators** (`operators/`): cert-manager, AMQ Streams (Kafka), AMQ Streams Console, AMQ Broker (Artemis), RHBK (Keycloak). These are cluster-scoped subscriptions.

2. **Shared Infrastructure** (`charts/swim-infra/`): Single umbrella chart deploying SWIM PKI (CA + ClusterIssuer), Kafka with pre-configured topics, two Artemis brokers (validator + provider) with mTLS and JWT auth, MongoDB, PostgreSQL, MariaDB, and Keycloak with the SWIM realm. The `modules` list in `values.yaml` controls which topic sets are created.

3. **SWIM Services** (`charts/swim-{dnotam,ed254}-{provider,consumer}/`): Two modules (DNOTAM and ED-254), each with a provider and consumer. Providers publish to AMQP (Artemis); consumers receive from AMQP and route to Kafka topics.

4. **Validators** (`charts/swim-{dnotam,ed254}-{consumer,provider}-validator/`): Mock counterparts that simulate external SWIM endpoints. Critical rule: consumers connect to consumer-validators (not to the real provider of the same module).

5. **Example Applications** (`charts/{dnotam-dashboard,dnotam-event-publisher,ed254-arrival-flow-manager,ed254-aman-client}/`): Frontend+backend demo apps deployed as separate pods.

## Helm Chart Conventions

- Every chart has `values.yaml` as the base configuration.
- The Makefile passes `-f values.yaml -f values-crc.yaml` when `values-crc.yaml` exists, applying CRC-specific overrides. The README examples omit the CRC overlay for simplicity.
- Templates follow standard Kubernetes resource types: Deployment, Service, ConfigMap, Secret, Route (OpenShift), PVC.
- Validator charts include their own embedded Artemis broker configuration.
- `charts/swim-infra/values.yaml` defines the `clusterDomain` (default `apps-crc.testing`) and all Kafka topic definitions.

## Critical Rules

- **No autonomous deployment**: never execute `oc apply`, `helm install/upgrade`, `crc start/stop`, or `podman machine` commands without explicit user confirmation.
- **YAML only**: all Kubernetes resources must be YAML, never JSON.

## Compliance Context

Implements EUROCONTROL SPEC-170 (SWIM-TI Yellow Profile), EU Regulation 2021/116 (CP1), EUROCAE ED-254 (Extended AMAN), AIXM 5.1.1, and AMQP 1.0 over TLS 1.3. ED-254 applies to Extended AMAN only, not DNOTAM.
