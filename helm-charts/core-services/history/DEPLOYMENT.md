# History Service Helm Chart - Deployment Guide

## Chart Summary

Simplified Helm chart for the History service following the Adaptor pattern.

**Version:** 1.0.0  
**App Version:** 1.0.98  
**Image:** `rg.fr-par.scw.cloud/ejaw/history:1.0.98`

## What's Included

### Root Files
- `Chart.yaml` - Chart metadata
- `values.yaml` - Configuration values
- `PVC-SETUP.md` - Detailed GeoIP PVC setup instructions

### Templates (7 files)
- `_helpers.tpl` - Template helper functions
- `configmap.yaml` - Application configuration
- `deployment.yaml` - Main deployment with GeoIP PVC mount
- `service.yaml` - ClusterIP service (HTTP 7210, gRPC 7200)
- `serviceaccount.yaml` - Service account for pods
- `NOTES.txt` - Post-installation instructions

## Key Features

✅ **Simplified Design** - Matches Adaptor chart pattern  
✅ **PVC for GeoIP** - 64MB country.mmdb via pre-created PVC  
✅ **Correct Credentials** - Uses `docker-registry-credentials`  
✅ **Dual Protocols** - HTTP (7210) and gRPC (7200) endpoints  
✅ **Service References** - Kubernetes DNS for Exchange, Redis  
✅ **Health Checks** - Liveness and readiness probes  
✅ **Prometheus** - Metrics scraping enabled  
✅ **Istio** - Service mesh injection enabled  

## Pre-Deployment Requirements

### 1. Create Docker Registry Secret (if not exists)

```bash
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=rg.fr-par.scw.cloud \
  --docker-username=<your-scw-username> \
  --docker-password=<your-scw-token> \
  -n rgs-core
```

### 2. Create and Populate GeoIP PVC

**See `PVC-SETUP.md` for detailed instructions.**

Quick version:
```bash
# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: history-geoip
  namespace: rgs-core
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Mi
  storageClassName: <your-storage-class>
EOF

# Upload country.mmdb (see PVC-SETUP.md for methods)
```

## Deployment

```bash
# Install
helm install history ./history -n rgs-core

# Or upgrade if already installed
helm upgrade history ./history -n rgs-core

# Check status
kubectl get pods -n rgs-core -l app=history
kubectl logs -n rgs-core -l app=history
```

## Configuration Overview

### Service Dependencies
- **Exchange**: `exchange.rgs-core.svc.cluster.local:7100`
- **Redis**: `redis-master.rgs-infrastructure.svc.cluster.local:6379`
- **PostgreSQL**: `77.93.172.59:5432` (external)

### Resources
- **Limits**: 1 CPU, 2Gi RAM
- **Requests**: 500m CPU, 1Gi RAM
- **Shared Memory**: 1Gi

### Ports
- **7210** - HTTP API & health checks
- **7200** - gRPC service

### Environment
- **GOMAXPROCS**: 6

## Verification

```bash
# Check pod is running
kubectl get pods -n rgs-core -l app=history

# Test health endpoint
kubectl exec -n rgs-core deployment/history -- wget -qO- localhost:7210/health

# Check logs
kubectl logs -n rgs-core -l app=history --tail=100

# Verify GeoIP mount
kubectl exec -n rgs-core deployment/history -- ls -lh /app/data/ip2country/country.mmdb
```

## Troubleshooting

### Pod won't start - ImagePullBackOff
```bash
# Check secret exists
kubectl get secret docker-registry-credentials -n rgs-core

# If missing, create it (see Pre-Deployment Requirements)
```

### Pod pending - PVC not bound
```bash
# Check PVC status
kubectl get pvc history-geoip -n rgs-core
kubectl describe pvc history-geoip -n rgs-core

# Verify storage class exists
kubectl get sc
```

### Container crashing - File not found
```bash
# Verify country.mmdb exists in PVC
kubectl run -it --rm debug --image=busybox -n rgs-core \
  --overrides='{"spec":{"containers":[{"name":"debug","image":"busybox","command":["sh"],"volumeMounts":[{"name":"geoip","mountPath":"/data"}]}],"volumes":[{"name":"geoip","persistentVolumeClaim":{"claimName":"history-geoip"}}]}}'

# Inside pod:
ls -lh /data/
```

### Service not reachable
```bash
# Check service exists
kubectl get svc -n rgs-core | grep history

# Test from another pod
kubectl run -it --rm test --image=busybox -n rgs-core -- \
  wget -qO- history.rgs-core.svc.cluster.local:7210/health
```

## Customization

Edit `values.yaml` to customize:

```yaml
# Change replica count
replicaCount: 2

# Update image version
image:
  tag: "1.0.99"

# Change PVC name
geoip:
  pvcName: "my-custom-geoip-pvc"

# Update resource limits
resources:
  limits:
    cpu: 2000m
    memory: 4Gi
```

## Next Steps

After successfully deploying History:
- Monitor logs for any errors
- Verify integration with Exchange service
- Test gRPC endpoint connectivity
- Check Prometheus metrics are being scraped

## Differences from Complex Version

This simplified chart **removes**:
- PodDisruptionBudget (for HA)
- HorizontalPodAutoscaler template
- Anti-affinity rules
- Init container download options
- Multiple GeoIP strategies

Kept **simple and production-ready** like the Adaptor chart.
