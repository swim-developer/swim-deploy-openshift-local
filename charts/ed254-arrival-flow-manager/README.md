# ED-254 Arrival Flow Manager - Helm Chart

Helm chart for deploying ED-254 Arrival Flow Manager on OpenShift/Kubernetes.

---

## 📦 Components

| Component | Technology | Port | Description |
|-----------|-----------|------|-------------|
| **Frontend** | React 19 + Nginx 1.27 | 8080 | Dashboard UI |
| **Backend** | Quarkus 3.17 + JVM | 8091 | REST API + WebSocket + Kafka consumer |

---

## 🚀 Quick Start

### Prerequisites

- OpenShift 4.12+ or Kubernetes 1.27+
- Helm 3+
- swim-ed254-consumer running (external dependency)
- Kafka running (external dependency)

### Install

```bash
# From rhone project root
helm install ed254-arrival-flow-manager \
  example-apps/ed254-arrival-flow-manager/deploy/helm/ed254-arrival-flow-manager \
  -n swim-example-apps --create-namespace
```

### Verify

```bash
# Check pods
kubectl get pods -n swim-example-apps -l app.kubernetes.io/name=ed254-arrival-flow-manager

# Check route (OpenShift)
oc get route -n swim-example-apps
```

### Access

**OpenShift:**
```
https://ed254-arrival-flow-manager.apps.ocp4.masales.cloud
```

**Kubernetes (port-forward):**
```bash
kubectl port-forward svc/ed254-arrival-flow-manager-frontend 8080:8080 -n swim-example-apps
# Access: http://localhost:8080
```

---

## ⚙️ Configuration

### Values Structure

```yaml
# Global
namespace: swim-example-apps
appName: ed254-arrival-flow-manager
swimNamespace: swim-sandbox

# Backend
backend:
  image:
    repository: quay.io/masales/ed254-arrival-flow-manager-backend
    tag: latest
  port: 8091

# Frontend
frontend:
  image:
    repository: quay.io/masales/ed254-arrival-flow-manager-frontend
    tag: latest
  port: 8080
  route:
    host: ed254-arrival-flow-manager.apps.ocp4.masales.cloud

# External dependencies
ed254Consumer:
  serviceName: swim-ed254-consumer
  port: 8090

kafka:
  serviceName: kafka-kafka-bootstrap
  port: 9092
  topics:
    arrivalSequence: ed254-arrival-sequence-topic
```

### Custom Values

```bash
helm install ed254-arrival-flow-manager \
  example-apps/ed254-arrival-flow-manager/deploy/helm/ed254-arrival-flow-manager \
  -n swim-example-apps \
  --set frontend.route.host=my-custom-host.apps.example.com \
  --set backend.image.tag=v1.0.0
```

---

## 🔧 Upgrade

```bash
# Upgrade to new image version
helm upgrade ed254-arrival-flow-manager \
  example-apps/ed254-arrival-flow-manager/deploy/helm/ed254-arrival-flow-manager \
  -n swim-example-apps \
  --set backend.image.tag=v1.1.0 \
  --set frontend.image.tag=v1.1.0
```

---

## 🗑️ Uninstall

```bash
helm uninstall ed254-arrival-flow-manager -n swim-example-apps
```

---

## 🔍 Troubleshooting

### Backend not starting

**Check logs:**
```bash
kubectl logs -f deployment/ed254-arrival-flow-manager-backend -n swim-example-apps
```

**Common issues:**
- Kafka not ready → Verify swim-ed254-consumer is running
- ED254_CONSUMER_URL wrong → Check ConfigMap

### Frontend 502 Bad Gateway

**Check nginx config:**
```bash
kubectl exec deployment/ed254-arrival-flow-manager-frontend -n swim-example-apps -- cat /etc/nginx/conf.d/default.conf
```

**Verify backend URL:**
```bash
kubectl get configmap ed254-arrival-flow-manager-frontend-config -n swim-example-apps -o yaml
```

### No data appearing

**Check WebSocket connection:**
1. Open browser DevTools → Network → WS
2. Should see connection to `/api/ws/ed254/sequences`
3. Check backend logs for Kafka consumption errors

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Frontend (Nginx)                                           │
│  - Serves React SPA                                         │
│  - Proxies /api/* to backend                                │
│  - Proxies /api/ws/* to backend WebSocket                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Backend (Quarkus)                                          │
│  - REST API: /api/ed254/sequences                           │
│  - WebSocket: /ws/ed254/sequences (real-time broadcast)     │
│  - Subscription proxy: /api/ed254/subscriptions             │
│  - Kafka consumer: ed254-arrival-sequence-topic             │
└─────────────────────────────────────────────────────────────┘
                            ↓
         External Dependencies (swim-sandbox namespace)
  - swim-ed254-consumer (port 8090) - Subscription management
  - Kafka (port 9092) - Real-time event streaming
```

---

## 🔗 Dependencies

**Must be running BEFORE deploying this chart:**

1. **Kafka** (`swim-sandbox` namespace)
   - Service: `kafka-kafka-bootstrap`
   - Topic: `ed254-arrival-sequence-topic`

2. **swim-ed254-consumer** (`swim-sandbox` namespace)
   - Service: `swim-ed254-consumer`
   - Port: 8090
   - Endpoint: `/api/v1/subscriptions`

---

---

## 🧪 Local Development

For local development without deploying to OpenShift/Kubernetes, see the project root `compose.yml` and README.

---

**Version:** 1.0.0  
**Last Updated:** 2026-04-13  
**Author:** Marcelo Sales
