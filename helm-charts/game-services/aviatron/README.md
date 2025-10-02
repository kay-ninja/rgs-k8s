# Aviatron Game Helm Chart

This Helm chart deploys the Aviatron game service to Kubernetes with Istio routing.

## Overview

The chart deploys:
- **Server** (WebSocket game server) - Port 8000
- **Client** (Frontend) - Port 80
- **ConfigMap** - Game configuration
- **Istio VirtualService** - Traffic routing

## Prerequisites

- Kubernetes 1.20+
- Helm 3+
- Istio installed with gateway `istio-system/rgs-gateway`
- Docker registry credentials secret: `docker-registry-credentials` in `rgs-games` namespace
- Running core services: overlord, history, rng, redis

## Installation

### 1. Copy to game-services directory

```bash
# Extract and copy to your helm charts directory
unzip aviatron-helm-chart.zip
cp -r aviatron /path/to/rgs-k8s/helm-charts/game-services/
```

### 2. Ensure registry credentials exist

```bash
# Create the secret if it doesn't exist
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=registry.ejaw.net \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email \
  -n rgs-games
```

### 3. Deploy via ArgoCD (Recommended)

The chart will be automatically discovered by your ArgoCD ApplicationSet for game services.

Push to Git:
```bash
cd /path/to/rgs-k8s
git add helm-charts/game-services/aviatron/
git commit -m "Add aviatron game helm chart"
git push
```

ArgoCD will automatically:
- Create the `aviatron-game` application
- Deploy to `rgs-games` namespace
- Sync continuously

Check ArgoCD:
```bash
kubectl get application aviatron-game -n argocd
argocd app get aviatron-game
```

### 4. Manual deployment (alternative)

```bash
helm upgrade --install aviatron ./aviatron \
  --namespace rgs-games \
  --create-namespace
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gameSlug` | URL path for game | `aviatron` |
| `replicaCount` | Number of replicas | `2` |
| `imagePullSecrets` | Registry credentials | `docker-registry-credentials` |
| `server.image.tag` | Server image version | `1.0.47` |
| `client.image.tag` | Client image version | `1.0.81` |
| `server.port` | Server port | `8000` |
| `client.port` | Client port | `80` |

### Service Endpoints

The chart automatically connects to:
- **Overlord**: `overlord-service.rgs-core.svc.cluster.local:7500`
- **History**: `history-service.rgs-core.svc.cluster.local:7200`
- **RNG**: `rng-service-grpc.rgs-core.svc.cluster.local:7700`
- **Redis**: `redis-master.rgs-infrastructure.svc.cluster.local:6379`

## Accessing the Game

Once deployed, the game will be accessible at:

**HTTP**: `http://dev-h3-games.ninjagaming.com:30828/aviatron/`

**HTTPS** (if configured): `https://dev-h3-games.ninjagaming.com:30827/aviatron/`

### API/WebSocket Endpoint

The game server WebSocket endpoint:
- `http://dev-h3-games.ninjagaming.com:30828/aviatron/api/`

## Monitoring

### Check deployment status

```bash
kubectl get pods -n rgs-games -l app=aviatron
kubectl get svc -n rgs-games -l app=aviatron
kubectl get vs -n rgs-games -l app=aviatron
```

### View logs

```bash
# Server logs
kubectl logs -n rgs-games -l app=aviatron,component=server -f

# Client logs
kubectl logs -n rgs-games -l app=aviatron,component=client -f
```

### Test connectivity

```bash
# Test from within cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n rgs-games -- curl -v http://aviatron-client:80

# Test from outside (from bastion host)
curl -H "Host: dev-h3-games.ninjagaming.com" http://10.10.10.21:30828/aviatron/
```

## Troubleshooting

### ImagePullBackOff error

If pods show `ImagePullBackOff`:
```bash
# Check if secret exists
kubectl get secret docker-registry-credentials -n rgs-games

# If missing, create it:
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=registry.ejaw.net \
  --docker-username=your-username \
  --docker-password=your-password \
  -n rgs-games
```

### Server not starting

Check if dependencies are running:
```bash
kubectl get pods -n rgs-core | grep -E 'overlord|history|rng'
kubectl get pods -n rgs-infrastructure | grep redis
```

### WebSocket connection issues

1. Ensure Istio VirtualService has `timeout: 0s` for WebSocket routes (already configured)
2. Check if HTTP/2 upgrade is disabled in DestinationRule
3. Verify firewall allows WebSocket connections

### Configuration issues

View the generated config:
```bash
kubectl get configmap aviatron-config -n rgs-games -o yaml
```

## Replicating for Other Games

To create charts for other games:

1. **Copy this directory:**
   ```bash
   cp -r aviatron big-beak-guppy
   cd big-beak-guppy
   ```

2. **Update Chart.yaml:**
   ```yaml
   name: big-beak-guppy
   description: Big Beak Guppy game service for RGS platform
   ```

3. **Update values.yaml:**
   ```yaml
   gameSlug: big-beak-guppy  # Change this
   
   server:
     image:
       repository: rgs/backend/slots/heronbyte/big-beak-guppy  # Update
       tag: "1.0.0"  # Update
   
   client:
     image:
       repository: rgs/frontend/slots/ninjagaming/big-beak-guppy  # Update
       tag: "1.0.0"  # Update
   
   config:
     redis:
       prefix: big-beak-guppy  # Change this
   ```

4. **Update game-specific config** in `values.yaml` under `config:` section

5. **Commit and push** - ArgoCD will auto-deploy

## File Structure

```
aviatron/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Configuration values
├── templates/
│   ├── configmap.yaml             # Game config
│   ├── deployment-server.yaml     # Server deployment
│   ├── deployment-client.yaml     # Client deployment
│   ├── service-server.yaml        # Server service
│   ├── service-client.yaml        # Client service
│   └── virtualservice.yaml        # Istio routing
└── README.md                       # This file
```

## Support

For issues with the chart, check:
- ArgoCD application status: `kubectl get app aviatron-game -n argocd`
- Pod logs in rgs-games namespace
- Istio gateway configuration
- Core services health
- Registry credentials

## Version History

- **1.0.0** - Initial release
  - WebSocket support
  - Docker registry credentials integration
  - Kubernetes service endpoints
  - Istio routing configuration
