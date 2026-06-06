NS ?= swim-demo
CHARTS := charts
OPERATORS := operators

.PHONY: help sync pull
.PHONY: operators operators-wait spi infra infra-artemis-ssl
.PHONY: dnotam-provider dnotam-consumer ed254-provider ed254-consumer services
.PHONY: dnotam-consumer-validator dnotam-provider-validator ed254-consumer-validator ed254-provider-validator validators
.PHONY: dnotam-event-publisher dnotam-dashboard ed254-arrival-flow-manager ed254-aman-client apps
.PHONY: all status
.PHONY: remove-apps remove-validators remove-services remove-infra remove-spi remove-operators destroy

help:
	@echo ""
	@echo "  SWIM on OpenShift Local (CRC)"
	@echo "  =============================="
	@echo ""
	@echo "  Full deployment (recommended order):"
	@echo "    make all              Deploy everything (operators + infra + services + validators + apps)"
	@echo ""
	@echo "  Step-by-step:"
	@echo "    make operators        Install OLM operators (AMQ Streams, AMQ Broker, cert-manager, RHBK)"
	@echo "    make operators-wait   Wait for operator CRDs to become available"
	@echo "    make spi              Create Keycloak SWIM Role SPI secret"
	@echo "    make infra            Deploy shared infrastructure (Kafka, Artemis, MongoDB, PostgreSQL, Keycloak)"
	@echo "    make infra-artemis-ssl Create Artemis SSL secrets from cert-manager certificates"
	@echo "    make services         Deploy DNOTAM + ED-254 providers and consumers"
	@echo "    make validators       Deploy all validators (mock providers and mock consumers)"
	@echo "    make apps             Deploy example applications (dashboards, publishers)"
	@echo ""
	@echo "  Individual services:"
	@echo "    make dnotam-provider / dnotam-consumer / ed254-provider / ed254-consumer"
	@echo ""
	@echo "  Individual validators:"
	@echo "    make dnotam-consumer-validator / dnotam-provider-validator"
	@echo "    make ed254-consumer-validator  / ed254-provider-validator"
	@echo ""
	@echo "  Individual example apps:"
	@echo "    make dnotam-event-publisher / dnotam-dashboard"
	@echo "    make ed254-arrival-flow-manager / ed254-aman-client"
	@echo ""
	@echo "  Operations:"
	@echo "    make status           Show pods, PVCs, and Helm releases"
	@echo "    make destroy          Remove everything in reverse order"
	@echo ""
	@echo "  Selective removal:"
	@echo "    make remove-apps      Remove example applications"
	@echo "    make remove-validators Remove validators"
	@echo "    make remove-services  Remove DNOTAM + ED-254 services"
	@echo "    make remove-infra     Remove shared infrastructure"
	@echo ""
	@echo "  Variables:"
	@echo "    NS=swim-demo          Target namespace (default: swim-demo)"
	@echo ""

sync: pull

pull:
	@git pull --ff-only

# ==============================================================================
# 1. OLM Operators
# ==============================================================================

operators:
	@echo ""
	@echo "  [1/6] Installing OLM operators..."
	@echo "  ================================="
	oc apply -f $(OPERATORS)/cert-manager-operator.yaml
	oc apply -f $(OPERATORS)/amq-streams-operator.yaml
	oc apply -f $(OPERATORS)/amq-streams-console-operator.yaml
	oc apply -f $(OPERATORS)/amq-broker-operator.yaml
	oc apply -f $(OPERATORS)/rhbk-operator.yaml
	@echo ""
	@echo "  Operators submitted. Run 'make operators-wait' to wait for CRDs."

operators-wait:
	@echo "  Waiting for operator CRDs..."
	@printf "    Kafka..."
	@until oc get crd kafkas.kafka.strimzi.io >/dev/null 2>&1; do sleep 5; done
	@echo " ready"
	@printf "    ClusterIssuer..."
	@until oc get crd clusterissuers.cert-manager.io >/dev/null 2>&1; do sleep 5; done
	@echo " ready"
	@printf "    ActiveMQArtemis..."
	@until oc get crd activemqartemises.broker.amq.io >/dev/null 2>&1; do sleep 5; done
	@echo " ready"
	@printf "    Keycloak..."
	@until oc get crd keycloaks.k8s.keycloak.org >/dev/null 2>&1; do sleep 5; done
	@echo " ready"
	@echo "  All operator CRDs available."

# ==============================================================================
# 2. Keycloak SPI
# ==============================================================================

spi:
	@echo ""
	@echo "  [2/6] Creating Keycloak SWIM Role SPI secret..."
	@echo "  ================================================"
	oc create secret generic keycloak-swim-role-spi -n $(NS) \
		--from-file=keycloak-swim-role-spi.jar=lib/keycloak-swim-role-spi.jar \
		--dry-run=client -o yaml | oc apply -f -
	@echo "  SPI secret created."

# ==============================================================================
# 3. Shared Infrastructure
# ==============================================================================

infra:
	@echo ""
	@echo "  [3/6] Deploying shared infrastructure..."
	@echo "  ========================================="
	helm upgrade --install swim-infra $(CHARTS)/swim-infra \
		-n $(NS) --create-namespace \
		-f $(CHARTS)/swim-infra/values.yaml \
		-f $(CHARTS)/swim-infra/values-crc.yaml
	@echo ""
	@echo "  Infrastructure deployed."

infra-artemis-ssl:
	@echo ""
	@echo "  Creating Artemis SSL secrets from cert-manager certificates..."
	@echo "  ==============================================================="
	@echo "  Waiting for validator-artemis-amqp certificate..."
	@oc wait --for=condition=Ready certificate/validator-artemis-amqp -n $(NS) --timeout=120s
	@echo "  Waiting for provider-artemis-amqp certificate..."
	@oc wait --for=condition=Ready certificate/provider-artemis-amqp -n $(NS) --timeout=120s
	@KS=$$(oc get secret validator-artemis-amqp-tls -n $(NS) -o jsonpath='{.data.keystore\.jks}') && \
	TS=$$(oc get secret validator-artemis-amqp-tls -n $(NS) -o jsonpath='{.data.truststore\.jks}') && \
	PW=$$(printf '%s' "$$(oc get secret validator-artemis-keystore-password -n $(NS) -o jsonpath='{.data.password}' | base64 -d)" | base64) && \
	oc apply -f - <<< "$$( \
		printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: validator-artemis-ssl-secret\n  namespace: $(NS)\ntype: Opaque\ndata:\n  broker.ks: %s\n  client.ts: %s\n  keyStorePassword: %s\n  trustStorePassword: %s\n' $$KS $$TS $$PW $$PW)"
	@echo "  validator-artemis-ssl-secret created."
	@KS=$$(oc get secret provider-artemis-amqp-tls -n $(NS) -o jsonpath='{.data.keystore\.jks}') && \
	TS=$$(oc get secret provider-artemis-amqp-tls -n $(NS) -o jsonpath='{.data.truststore\.jks}') && \
	PW=$$(printf '%s' "$$(oc get secret provider-artemis-keystore-password -n $(NS) -o jsonpath='{.data.password}' | base64 -d)" | base64) && \
	oc apply -f - <<< "$$( \
		printf 'apiVersion: v1\nkind: Secret\nmetadata:\n  name: provider-artemis-ssl-secret\n  namespace: $(NS)\ntype: Opaque\ndata:\n  broker.ks: %s\n  client.ts: %s\n  keyStorePassword: %s\n  trustStorePassword: %s\n' $$KS $$TS $$PW $$PW)"
	@echo "  provider-artemis-ssl-secret created."

# ==============================================================================
# 4. SWIM Services
# ==============================================================================

dnotam-provider:
	helm upgrade --install swim-dnotam-provider $(CHARTS)/swim-dnotam-provider \
		-n $(NS) -f $(CHARTS)/swim-dnotam-provider/values.yaml -f $(CHARTS)/swim-dnotam-provider/values-crc.yaml

dnotam-consumer:
	helm upgrade --install swim-dnotam-consumer $(CHARTS)/swim-dnotam-consumer \
		-n $(NS) -f $(CHARTS)/swim-dnotam-consumer/values.yaml -f $(CHARTS)/swim-dnotam-consumer/values-crc.yaml

ed254-provider:
	helm upgrade --install swim-ed254-provider $(CHARTS)/swim-ed254-provider \
		-n $(NS) -f $(CHARTS)/swim-ed254-provider/values.yaml -f $(CHARTS)/swim-ed254-provider/values-crc.yaml

ed254-consumer:
	helm upgrade --install swim-ed254-consumer $(CHARTS)/swim-ed254-consumer \
		-n $(NS) -f $(CHARTS)/swim-ed254-consumer/values.yaml -f $(CHARTS)/swim-ed254-consumer/values-crc.yaml

services:
	@echo ""
	@echo "  [4/6] Deploying SWIM services..."
	@echo "  ================================="
	@$(MAKE) --no-print-directory dnotam-provider
	@$(MAKE) --no-print-directory dnotam-consumer
	@$(MAKE) --no-print-directory ed254-provider
	@$(MAKE) --no-print-directory ed254-consumer
	@echo ""
	@echo "  All services deployed."

# ==============================================================================
# 5. Validators
# ==============================================================================

dnotam-consumer-validator:
	helm upgrade --install swim-dnotam-consumer-validator $(CHARTS)/swim-dnotam-consumer-validator \
		-n $(NS) -f $(CHARTS)/swim-dnotam-consumer-validator/values.yaml -f $(CHARTS)/swim-dnotam-consumer-validator/values-crc.yaml

dnotam-provider-validator:
	helm upgrade --install swim-dnotam-provider-validator $(CHARTS)/swim-dnotam-provider-validator \
		-n $(NS) -f $(CHARTS)/swim-dnotam-provider-validator/values.yaml -f $(CHARTS)/swim-dnotam-provider-validator/values-crc.yaml

ed254-consumer-validator:
	helm upgrade --install swim-ed254-consumer-validator $(CHARTS)/swim-ed254-consumer-validator \
		-n $(NS) -f $(CHARTS)/swim-ed254-consumer-validator/values.yaml -f $(CHARTS)/swim-ed254-consumer-validator/values-crc.yaml

ed254-provider-validator:
	helm upgrade --install swim-ed254-provider-validator $(CHARTS)/swim-ed254-provider-validator \
		-n $(NS) -f $(CHARTS)/swim-ed254-provider-validator/values.yaml -f $(CHARTS)/swim-ed254-provider-validator/values-crc.yaml

validators:
	@echo ""
	@echo "  [5/6] Deploying validators..."
	@echo "  =============================="
	@$(MAKE) --no-print-directory dnotam-consumer-validator
	@$(MAKE) --no-print-directory dnotam-provider-validator
	@$(MAKE) --no-print-directory ed254-consumer-validator
	@$(MAKE) --no-print-directory ed254-provider-validator
	@echo ""
	@echo "  All validators deployed."

# ==============================================================================
# 6. Example Applications
# ==============================================================================

dnotam-event-publisher:
	helm upgrade --install dnotam-event-publisher $(CHARTS)/dnotam-event-publisher \
		-n $(NS) -f $(CHARTS)/dnotam-event-publisher/values.yaml -f $(CHARTS)/dnotam-event-publisher/values-crc.yaml

dnotam-dashboard:
	helm upgrade --install dnotam-dashboard $(CHARTS)/dnotam-dashboard \
		-n $(NS) -f $(CHARTS)/dnotam-dashboard/values.yaml -f $(CHARTS)/dnotam-dashboard/values-crc.yaml

ed254-arrival-flow-manager:
	helm upgrade --install ed254-arrival-flow-manager $(CHARTS)/ed254-arrival-flow-manager \
		-n $(NS) -f $(CHARTS)/ed254-arrival-flow-manager/values.yaml -f $(CHARTS)/ed254-arrival-flow-manager/values-crc.yaml

ed254-aman-client:
	helm upgrade --install ed254-aman-client $(CHARTS)/ed254-aman-client \
		-n $(NS) -f $(CHARTS)/ed254-aman-client/values.yaml -f $(CHARTS)/ed254-aman-client/values-crc.yaml

apps:
	@echo ""
	@echo "  [6/6] Deploying example applications..."
	@echo "  ========================================"
	@$(MAKE) --no-print-directory dnotam-event-publisher
	@$(MAKE) --no-print-directory dnotam-dashboard
	@$(MAKE) --no-print-directory ed254-arrival-flow-manager
	@$(MAKE) --no-print-directory ed254-aman-client
	@echo ""
	@echo "  All example applications deployed."

# ==============================================================================
# Full Deployment
# ==============================================================================

all: operators operators-wait spi infra infra-artemis-ssl services validators apps
	@echo ""
	@echo "  =============================="
	@echo "  SWIM deployment complete."
	@echo "  =============================="
	@echo ""
	@echo "  Run 'make status' to verify."

# ==============================================================================
# Status
# ==============================================================================

status:
	@echo ""
	@echo "  SWIM on OpenShift Local - Status ($(NS))"
	@echo "  =========================================="
	@echo ""
	@echo "  Helm Releases:"
	@helm list -n $(NS) 2>/dev/null || echo "  (not connected)"
	@echo ""
	@echo "  Pods:"
	@oc get pods -n $(NS) 2>/dev/null || echo "  (not connected)"
	@echo ""
	@echo "  PVCs:"
	@oc get pvc -n $(NS) 2>/dev/null || echo "  (not connected)"
	@echo ""
	@echo "  Routes:"
	@oc get routes -n $(NS) 2>/dev/null || echo "  (not connected)"

# ==============================================================================
# Removal (reverse order)
# ==============================================================================

remove-apps:
	@echo "  Removing example applications..."
	-helm uninstall ed254-aman-client -n $(NS) 2>/dev/null
	-helm uninstall ed254-arrival-flow-manager -n $(NS) 2>/dev/null
	-helm uninstall dnotam-dashboard -n $(NS) 2>/dev/null
	-helm uninstall dnotam-event-publisher -n $(NS) 2>/dev/null
	@echo "  Done."

remove-validators:
	@echo "  Removing validators..."
	-helm uninstall swim-ed254-provider-validator -n $(NS) 2>/dev/null
	-helm uninstall swim-ed254-consumer-validator -n $(NS) 2>/dev/null
	-helm uninstall swim-dnotam-provider-validator -n $(NS) 2>/dev/null
	-helm uninstall swim-dnotam-consumer-validator -n $(NS) 2>/dev/null
	@echo "  Done."

remove-services:
	@echo "  Removing SWIM services..."
	-helm uninstall swim-ed254-consumer -n $(NS) 2>/dev/null
	-helm uninstall swim-ed254-provider -n $(NS) 2>/dev/null
	-helm uninstall swim-dnotam-consumer -n $(NS) 2>/dev/null
	-helm uninstall swim-dnotam-provider -n $(NS) 2>/dev/null
	@echo "  Done."

remove-infra:
	@echo "  Removing shared infrastructure..."
	-helm uninstall swim-infra -n $(NS) 2>/dev/null
	@echo "  Done."

remove-spi:
	@echo "  Removing Keycloak SPI secret..."
	-oc delete secret keycloak-swim-role-spi -n $(NS) 2>/dev/null
	@echo "  Done."

remove-operators:
	@echo "  Removing OLM operators..."
	-oc delete -f $(OPERATORS)/rhbk-operator.yaml 2>/dev/null
	-oc delete -f $(OPERATORS)/amq-broker-operator.yaml 2>/dev/null
	-oc delete -f $(OPERATORS)/amq-streams-console-operator.yaml 2>/dev/null
	-oc delete -f $(OPERATORS)/amq-streams-operator.yaml 2>/dev/null
	-oc delete -f $(OPERATORS)/cert-manager-operator.yaml 2>/dev/null
	@echo "  Done."

destroy: remove-apps remove-validators remove-services remove-infra remove-spi remove-operators
	@echo ""
	@echo "  =============================="
	@echo "  SWIM fully removed from CRC."
	@echo "  =============================="
