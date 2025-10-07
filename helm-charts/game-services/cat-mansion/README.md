# Cat-Mansion Helm Chart

Cat Mansion slot game - Custom server with WebSocket support

## Overview

**Pattern**: Custom Server with WebSocket (Aviatron-style)
- **Server**: Custom dog-house-megaways backend with WebSocket
- **Client**: Cat Mansion frontend
- **Architecture**: Single config file, custom server binary
- **Features**: WebSocket support, tracer integration, multiple integrators

## 🚨 CRITICAL: Client Port Verification Required

**BEFORE DEPLOYING**, you MUST verify the client container's nginx port:

```bash
# Verify the actual port nginx listens on
docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \
  sh -c "sleep 5 && ss -tulpn | grep nginx"
```

**Expected output examples:**
- Port 80: `tcp    0.0.0.0:80    LISTEN    1/nginx` ✅ (default assumption)
- Port 8089: `tcp    0.0.0.0:8089    LISTEN    1/nginx` ⚠️ (update values.yaml!)

If the port is NOT 80, update `values.yaml`:
```yaml
client:
  port: 8089  # or whatever port nginx actually listens on
  # Also update livenessProbe and readinessProbe ports
```

**Why this matters**: Wrong port configuration causes CrashLoopBackOff errors that can waste hours of debugging time!

## Chart Structure

```
cat-mansion/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Configuration values
├── README.md                     # This file
└── templates/
    ├── configmap.yaml           # Server configuration
    ├── deployment-server.yaml   # Server deployment
    ├── deployment-client.yaml   # Client deployment
    ├── service-server.yaml      # Server service
    ├── service-client.yaml      # Client service
    └── virtualservice.yaml      # Istio routing
```

## Configuration

### Images
- **Server**: `registry.ejaw.net/rgs/backend/slots/ninjagaming/dog-house-megaways:3.0.2`
- **Client**: `registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109`

### Ports
- **Server**: 8000 (HTTP + WebSocket)
- **Client**: 80 (HTTP - VERIFY THIS!)

### Service Endpoints (Updated for Kubernetes)
```yaml
overlord: overlord-service.rgs-core.svc.cluster.local:7500
history: history-service.rgs-core.svc.cluster.local:7200
rng: rng-service-grpc.rgs-core.svc.cluster.local:7700
```

### Resources (Per Pod)
```yaml
Server:  200m CPU / 256Mi RAM (request), 500m CPU / 512Mi RAM (limit)
Client:  100m CPU / 128Mi RAM (request), 200m CPU / 256Mi RAM (limit)
Total:   1.4 CPU / 1.5Gi RAM (with 2 replicas each)
```

## Prerequisites

1. Kubernetes cluster with Istio installed
2. Namespace `rgs-games` created
3. Docker registry credentials configured:
   ```bash
   kubectl create secret docker-registry docker-registry-credentials \
     --docker-server=registry.ejaw.net \
     --docker-username=<username> \
     --docker-password=<password> \
     -n rgs-games
   ```

## Installation

### 1. Verify Client Port (CRITICAL!)
```bash
docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \
  sh -c "sleep 5 && ss -tulpn"
```

### 2. Update values.yaml if needed
If nginx listens on port 8089 instead of 80, update:
```yaml
client:
  port: 8089
  livenessProbe:
    httpGet:
      port: 8089
  readinessProbe:
    httpGet:
      port: 8089
service:
  client:
    targetPort: 8089
```

### 3. Install the chart
```bash
# From the chart directory
helm install cat-mansion ./cat-mansion -n rgs-games

# Or with custom values
helm install cat-mansion ./cat-mansion -n rgs-games -f custom-values.yaml
```

### 4. Verify deployment
```bash
# Check pods
kubectl get pods -n rgs-games -l app=cat-mansion

# Should see:
# cat-mansion-server-xxx   1/1   Running
# cat-mansion-client-xxx   1/1   Running

# Verify actual port inside client pod
kubectl exec -it deployment/cat-mansion-client -n rgs-games -- ss -tulpn | grep nginx
```

## Access

Once deployed, access the game at:
- **Game**: http://dev-h3-games.ninjagaming.com:30828/cat-mansion/
- **API**: http://dev-h3-games.ninjagaming.com:30828/cat-mansion/api/

## Troubleshooting

### Pod in CrashLoopBackOff
**Cause**: Wrong client port configuration
**Solution**:
```bash
# Check actual listening port
kubectl exec -it deployment/cat-mansion-client -n rgs-games -- ss -tulpn | grep nginx

# If different from values.yaml, update and upgrade
helm upgrade cat-mansion ./cat-mansion -n rgs-games
```

### ImagePullBackOff
**Cause**: Missing or incorrect registry credentials
**Solution**:
```bash
# Verify secret exists
kubectl get secret docker-registry-credentials -n rgs-games

# If missing, create it
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=registry.ejaw.net \
  --docker-username=<username> \
  --docker-password=<password> \
  -n rgs-games
```

### Server not connecting to services
**Cause**: Service endpoints not reachable
**Solution**:
```bash
# Test from server pod
kubectl exec -it deployment/cat-mansion-server -n rgs-games -- sh

# Try to reach services
nc -zv overlord-service.rgs-core.svc.cluster.local 7500
nc -zv history-service.rgs-core.svc.cluster.local 7200
nc -zv rng-service-grpc.rgs-core.svc.cluster.local 7700
```

### Check logs
```bash
# Server logs
kubectl logs -n rgs-games -l app=cat-mansion,component=server -f

# Client logs
kubectl logs -n rgs-games -l app=cat-mansion,component=client -f
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade cat-mansion ./cat-mansion -n rgs-games

# Upgrade with specific changes
helm upgrade cat-mansion ./cat-mansion -n rgs-games \
  --set server.replicaCount=3 \
  --set client.replicaCount=3
```

## Uninstalling

```bash
helm uninstall cat-mansion -n rgs-games
```

## Configuration Options

Key values that can be customized in `values.yaml`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `server.replicaCount` | Number of server replicas | `2` |
| `client.replicaCount` | Number of client replicas | `2` |
| `client.port` | **CRITICAL** - Client nginx port | `80` |
| `config.engine.rtp` | Return to Player percentage | `94` |
| `config.engine.debug` | Enable debug mode | `true` |
| `config.tracer.disabled` | Disable tracing | `true` |
| `virtualService.prefix` | URL prefix | `/cat-mansion` |

## Validation

Validate the chart before deployment:
```bash
# Lint the chart
helm lint ./cat-mansion

# Dry run
helm install cat-mansion ./cat-mansion -n rgs-games --dry-run --debug

# Template rendering
helm template cat-mansion ./cat-mansion -n rgs-games
```

## Notes

1. **Port Verification is Critical**: Always verify the client port before deployment
2. **Service Endpoints**: Pre-configured for Kubernetes FQDN format
3. **WebSocket Support**: Server supports WebSocket connections on port 8000
4. **Tracer**: Currently disabled, can be enabled in values.yaml
5. **Debug Mode**: Enabled by default for development environment

## Support

For issues or questions:
1. Check pod logs: `kubectl logs -n rgs-games -l app=cat-mansion`
2. Verify configuration: `kubectl get cm -n rgs-games -l app=cat-mansion`
3. Check service connectivity: `kubectl exec` into pods and test with `nc` or `curl`
