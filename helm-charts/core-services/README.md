# RGS Core Services Helm Charts

This directory contains Helm charts for all 8 RGS core services, ready for deployment via ArgoCD.

## 📦 Services Included

| Service | Description | gRPC Port | HTTP Port | Version |
|---------|-------------|-----------|-----------|---------|
| **office** | Backoffice management service (includes UI) | 7400 | 7410 | 2.5.54 |
| **exchange** | Currency and wallet management | 7100 | 7110 | 1.0.52 |
| **history** | Game history and audit service | 7200 | 7210 | 1.0.39 |
| **launch** | Game launcher service | 7300 | 7310 | 1.0.37 |
| **overlord** | Master control and orchestration | 7500 | 7510 | 1.0.23 |
| **pfr** | PFR service | 7600 | 7610 | 1.0.23 |
| **rng** | Random number generation service | 7700 | 7710 | 1.0.19 |
| **adaptor** | Integration adapter service | 7000 | 7010 | 1.0.30 |

## 🚀 Deployment via ArgoCD

### Option 1: Using ApplicationSet (Recommended)

The ApplicationSet will automatically detect and deploy all core services:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: core-services-apps
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - name: office
        namespace: rgs-core
        path: helm-charts/core-services/office
      - name: exchange
        namespace: rgs-core
        path: helm-charts/core-services/exchange
      - name: history
        namespace: rgs-core
        path: helm-charts/core-services/history
      - name: launch
        namespace: rgs-core
        path: helm-charts/core-services/launch
      - name: overlord
        namespace: rgs-core
        path: helm-charts/core-services/overlord
      - name: pfr
        namespace: rgs-core
        path: helm-charts/core-services/pfr
      - name: rng
        namespace: rgs-core
        path: helm-charts/core-services/rng
      - name: adaptor
        namespace: rgs-core
        path: helm-charts/core-services/adaptor
  template:
    metadata:
      name: '{{name}}-service'
      namespace: argocd
    spec:
      project: default
      source:
        repoURL:  https://github.com/kay-ninja/rgs-k8s
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### Option 2: Individual ArgoCD Applications

Deploy each service individually:

```bash
# Example for office service
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: office-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL:  https://github.com/kay-ninja/rgs-k8s
    targetRevision: HEAD
    path: helm-charts/core-services/office
  destination:
    server: https://kubernetes.default.svc
    namespace: rgs-core
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```

### Option 3: Direct Helm Installation (Development)

```bash
# Create namespace
kubectl create namespace rgs-core

# Install each service
helm install office ./core-services-charts/office -n rgs-core
helm install exchange ./core-services-charts/exchange -n rgs-core
helm install history ./core-services-charts/history -n rgs-core
helm install launch ./core-services-charts/launch -n rgs-core
helm install overlord ./core-services-charts/overlord -n rgs-core
helm install pfr ./core-services-charts/pfr -n rgs-core
helm install rng ./core-services-charts/rng -n rgs-core
helm install adaptor ./core-services-charts/adaptor -n rgs-core
```

## 📝 Prerequisites

1. **Infrastructure Services** must be deployed first:
   - PostgreSQL
   - Redis
   - RabbitMQ

2. **Docker Registry Secret**:
```bash
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_PASSWORD \
  --namespace=rgs-core
```

3. **Database Setup**:
Each service expects its own database. Create them in PostgreSQL:
```sql
CREATE DATABASE office;
CREATE DATABASE exchange;
CREATE DATABASE history;
CREATE DATABASE launch;
CREATE DATABASE overlord;
CREATE DATABASE pfr;
CREATE DATABASE rng;
CREATE DATABASE adaptor;
```

## 🔧 Configuration

### Environment-Specific Values

Each service supports environment-specific configurations:

```bash
# Development
helm install office ./office -f ./office/values.yaml -f ./office/values-dev.yaml

# Production
helm install office ./office -f ./office/values.yaml -f ./office/values-production.yaml
```

### Common Configuration Points

All services share these configuration patterns:

- **Database**: PostgreSQL connection settings
- **Redis**: Cache and session storage
- **RabbitMQ**: Message queue configuration
- **Health Checks**: Liveness and readiness probes
- **Resources**: CPU and memory limits/requests
- **Autoscaling**: HPA configuration (disabled by default)

### Service Dependencies

Services communicate with each other via gRPC/HTTP:

```
office → exchange, history, overlord
exchange → history, overlord
launch → history, overlord, pfr
history → overlord
overlord → (master service, no dependencies)
pfr → overlord
rng → (standalone service)
adaptor → overlord, exchange
```

## 🎯 Key Features

Each Helm chart includes:

- ✅ **Deployment** with configurable replicas
- ✅ **Services** for both gRPC and HTTP endpoints
- ✅ **ConfigMap** for environment configuration
- ✅ **ServiceAccount** with RBAC support
- ✅ **HorizontalPodAutoscaler** (optional)
- ✅ **PodDisruptionBudget** for high availability
- ✅ **Health checks** (liveness/readiness probes)
- ✅ **Anti-affinity** rules for pod distribution
- ✅ **Resource limits** and requests
- ✅ **Prometheus metrics** annotations

## 🔍 Verification

After deployment, verify all services are running:

```bash
# Check pods
kubectl get pods -n rgs-core

# Check services
kubectl get svc -n rgs-core

# Check health endpoints
for service in office exchange history launch overlord pfr rng adaptor; do
  echo "Checking $service..."
  kubectl port-forward -n rgs-core svc/$service 8080:7${service:0:1}10 &
  sleep 2
  curl http://localhost:8080/health
  kill %1
done
```

## 🐛 Troubleshooting

### Pods not starting
```bash
# Check events
kubectl describe pod <pod-name> -n rgs-core

# Check logs
kubectl logs <pod-name> -n rgs-core
```

### Database connection issues
- Verify PostgreSQL is running
- Check database credentials in secrets
- Ensure databases are created
- Check network policies

### Service discovery issues
- Verify service names match configuration
- Check DNS resolution: `kubectl exec -it <pod> -- nslookup history.rgs-core.svc.cluster.local`

## 📊 Monitoring

Services expose Prometheus metrics on their HTTP ports:

```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "<HTTP_PORT>"
```

## 🔄 Updates

To update a service via GitOps:

1. Modify the `values.yaml` or templates
2. Commit and push to Git
3. ArgoCD will automatically sync (if auto-sync enabled)
4. Or manually sync: `argocd app sync <service-name>`

## 📁 Directory Structure

```
core-services-charts/
├── office/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       ├── serviceaccount.yaml
│       ├── hpa.yaml
│       └── pdb.yaml
├── exchange/
│   └── ... (same structure)
├── history/
│   └── ... (same structure)
├── launch/
│   └── ... (same structure)
├── overlord/
│   └── ... (same structure)
├── pfr/
│   └── ... (same structure)
├── rng/
│   └── ... (same structure)
└── adaptor/
    └── ... (same structure)
```

## 🚨 Important Notes

1. **Minimal Istio**: These charts are configured with `sidecar.istio.io/inject: "false"` for minimal Istio setup
2. **Secrets**: Database passwords and API keys should be stored in Kubernetes secrets or external secret managers
3. **Resource Limits**: Adjust based on your actual usage patterns
4. **Replicas**: Production should have at least 2 replicas for HA

## 🎉 Ready to Deploy!

1. Copy these charts to your Git repository: `helm-charts/core-services/`
2. Update the Git URL in your ApplicationSet
3. Push to Git
4. ArgoCD will automatically detect and deploy all services!
