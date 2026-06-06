# DNOTAM Operations Dashboard - Helm Chart

Helm chart for deploying the DNOTAM Operations Dashboard to OpenShift/Kubernetes.

## Architecture

This chart deploys a complete stack:

```
┌─────────────────────────────────────────────────┐
│           OpenShift Cluster (swim-sandbox)         │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────┐    ┌──────────────────┐    │
│  │   MongoDB      │    │  Backend         │    │
│  │  StatefulSet   │◄───│  (Quarkus)       │    │
│  │  (5Gi PVC)     │    │  Port: 8090      │    │
│  └────────────────┘    └──────────────────┘    │
│                              ▲                   │
│                              │                   │
│                              │ API calls         │
│                              │                   │
│  ┌─────────────────────────────────────────┐    │
│  │   Frontend (React + Nginx)              │    │
│  │   Port: 8080                            │    │
│  └─────────────────────────────────────────┘    │
│                              ▲                   │
│                              │                   │
│  ┌─────────────────────────────────────────┐    │
│  │   Route (TLS Edge)                      │    │
│  │   dnotam-dashboard.apps.ocp4.masales... │    │
│  └─────────────────────────────────────────┘    │
│                                                  │
│  External Dependencies:                         │
│  • Kafka: kafka-kafka-bootstrap:9092            │
│  • Topics: 6 DNOTAM event topics                │
└─────────────────────────────────────────────────┘
```

## Prerequisites

1. **OpenShift/Kubernetes cluster** (4.x+)
2. **Helm 3.x** installed locally
3. **Kafka cluster** running in namespace with bootstrap: `kafka-kafka-bootstrap.swim-sandbox.svc.cluster.local:9092`
4. **swim-dnotam-consumer** deployed and publishing to Kafka topics
5. **Container images** pushed to quay.io:
   - `quay.io/masales/dnotam-dashboard-backend:latest`
   - `quay.io/masales/dnotam-dashboard-frontend:latest`

## Quick Start

### 1. Login to OpenShift

```bash
oc login https://api.ocp4.masales.cloud:6443
```

### 2. Create namespace (if not exists)

```bash
oc new-project swim-sandbox
```

### 3. Install the chart

```bash
cd /Users/marcelosales/RedHat/rhone/example-apps/dnotam-operations-dashboard/deploy/helm

helm install dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --create-namespace
```

### 4. Verify deployment

```bash
# Check pods
oc get pods -n swim-sandbox | grep dnotam

# Expected output:
# dnotam-dashboard-backend-xxx     1/1     Running   0          2m
# dnotam-dashboard-frontend-xxx    1/1     Running   0          2m
# dnotam-dashboard-mongodb-0       1/1     Running   0          2m

# Check route
oc get route dnotam-dashboard-frontend -n swim-sandbox

# Get application URL
echo "https://$(oc get route dnotam-dashboard-frontend -n swim-sandbox -o jsonpath='{.spec.host}')"
```

### 5. Access the application

Open browser to: `https://dnotam-dashboard.apps.ocp4.masales.cloud`

## Configuration

### Default Values

See [values.yaml](./values.yaml) for all configuration options.

### Common Customizations

#### Change Kafka bootstrap servers

```bash
helm install dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --set kafka.bootstrapServers="my-kafka:9092"
```

#### Change Route hostname

```bash
helm install dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --set frontend.route.host="my-custom-host.apps.ocp4.masales.cloud"
```

#### Increase backend resources

```bash
helm install dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --set backend.resources.requests.memory="1Gi" \
  --set backend.resources.limits.memory="2Gi"
```

#### Disable MongoDB (use external)

```bash
helm install dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --set mongodb.enabled=false \
  --set backend.env.MONGODB_URI="mongodb://external-mongo:27017"
```

## Upgrade

```bash
helm upgrade dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --reuse-values
```

## Rollback

```bash
helm rollback dnotam-dashboard --namespace swim-sandbox
```

## Uninstall

```bash
helm uninstall dnotam-dashboard --namespace swim-sandbox

# Clean up PVCs manually (if needed)
oc delete pvc -l app.kubernetes.io/instance=dnotam-dashboard -n swim-sandbox
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
oc get pods -n swim-sandbox | grep dnotam

# Check pod logs
oc logs -f deployment/dnotam-dashboard-backend -n swim-sandbox
oc logs -f deployment/dnotam-dashboard-frontend -n swim-sandbox
oc logs -f dnotam-dashboard-mongodb-0 -n swim-sandbox

# Describe pod for events
oc describe pod <pod-name> -n swim-sandbox
```

### Backend can't connect to MongoDB

```bash
# Check if MongoDB is ready
oc exec -it dnotam-dashboard-mongodb-0 -n swim-sandbox -- mongosh --eval "db.adminCommand('ping')"

# Check backend logs
oc logs -f deployment/dnotam-dashboard-backend -n swim-sandbox | grep -i mongo
```

### Backend can't connect to Kafka

```bash
# Check if Kafka is accessible
oc exec -it dnotam-dashboard-backend-xxx -n swim-sandbox -- nc -zv kafka-kafka-bootstrap 9092

# Check backend logs
oc logs -f deployment/dnotam-dashboard-backend -n swim-sandbox | grep -i kafka
```

### No data in dashboard

```bash
# Check if swim-dnotam-consumer is running
oc get pods -n swim-sandbox | grep swim-dnotam-consumer

# Check Kafka topics have messages
oc exec -it kafka-kafka-0 -n swim-sandbox -- /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dnotam-events-closure-topic \
  --from-beginning \
  --max-messages 1

# Check if backend is consuming messages
oc logs -f deployment/dnotam-dashboard-backend -n swim-sandbox | grep "Received DNOTAM event"
```

### Route not accessible

```bash
# Check route status
oc get route dnotam-dashboard-frontend -n swim-sandbox

# Check if TLS is properly configured
curl -I https://dnotam-dashboard.apps.ocp4.masales.cloud
```

## Health Checks

### Backend Health

```bash
# Liveness
curl http://dnotam-dashboard-backend:8090/q/health/live

# Readiness
curl http://dnotam-dashboard-backend:8090/q/health/ready

# Full health check
curl http://dnotam-dashboard-backend:8090/q/health
```

### Frontend Health

```bash
curl http://dnotam-dashboard-frontend:8080/health
```

## Monitoring

### Prometheus Metrics

```bash
# Backend metrics
curl http://dnotam-dashboard-backend:8090/q/metrics

# Key metrics to watch:
# - dnotam_events_processed_total
# - kafka_consumer_records_consumed_total
# - mongodb_driver_pool_checkedout
```

### OpenTelemetry Traces

If OpenTelemetry is enabled (`otel.enabled=true`), traces are sent to the configured endpoint.

## Development

### Port-forward for local testing

```bash
# Backend
oc port-forward svc/dnotam-dashboard-backend 8090:8090 -n swim-sandbox

# Frontend
oc port-forward svc/dnotam-dashboard-frontend 8080:8080 -n swim-sandbox

# MongoDB
oc port-forward svc/dnotam-dashboard-mongodb 27017:27017 -n swim-sandbox
```

### Template Validation

```bash
# Render templates without installing
helm template dnotam-dashboard ./dnotam-dashboard --namespace swim-sandbox

# Dry-run installation
helm install dnotam-dashboard ./dnotam-dashboard \
  --namespace swim-sandbox \
  --dry-run --debug
```

## Values Reference

See [values.yaml](./values.yaml) for detailed documentation of all configuration options.

Key sections:
- `mongodb.*` - MongoDB configuration
- `backend.*` - Quarkus backend configuration
- `frontend.*` - React frontend configuration
- `kafka.*` - Kafka connection settings
- `otel.*` - OpenTelemetry configuration

## Support

For issues or questions:
- GitHub: https://github.com/swim-developer/rhone/issues
- Contact: Marcelo Sales (masales@redhat.com)
