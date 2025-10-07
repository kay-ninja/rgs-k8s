# Dede5000 Game Helm Chart

This Helm chart deploys the Dede5000 game service to Kubernetes with Istio routing.

## Overview

The chart deploys:
- **Server** (Cyprus Go Server) - Port 8000
- **Client** (Frontend) - Port 8089
- **Server ConfigMap** - Server and game configuration (config.yaml + dede5000.yaml)
- **Client ConfigMap** - Client configuration (addon.js)
- **Istio VirtualService** - Traffic routing

## Prerequisites

- Kubernetes 1.20+
- Helm 3+
- Istio installed with gateway `istio-system/rgs-gateway`
- Docker registry credentials secret: `docker-registry-credentials` in `rgs-games` namespace
- Running core services: overlord, history, rng

## Installation

### 1. Copy to game-services directory

```bash
# Extract and copy to your helm charts directory
cp -r dede5000 /path/to/rgs-k8s/helm-charts/game-services/
```

### 2. Ensure registry credentials exist

```bash
# Create the secret if it doesn't exist
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=ninjargs \
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
git add helm-charts/game-services/dede5000/
git commit -m "Add dede5000 game helm chart"
git push
```

ArgoCD will automatically:
- Create the `dede5000-game` application
- Deploy to `rgs-games` namespace
- Sync continuously

Check ArgoCD:
```bash
kubectl get application dede5000-game -n argocd
argocd app get dede5000-game
```

### 4. Manual deployment (alternative)

```bash
helm upgrade --install dede5000 ./dede5000 \
  --namespace rgs-games \
  --create-namespace
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gameSlug` | URL path for game | `cyprus-dede5000` |
| `replicaCount` | Number of replicas | `2` |
| `imagePullSecrets` | Registry credentials | `docker-registry-credentials` |
| `server.image.tag` | Server image version | `1.0.10` |
| `client.image.tag` | Client image version | `cyprus-go-server` |
| `server.port` | Server port | `8000` |
| `client.port` | Client port | `8089` |

### Service Endpoints

The chart automatically connects to:
- **Overlord**: `overlord-service.rgs-core.svc.cluster.local:7500`
- **History**: `history-service.rgs-core.svc.cluster.local:7200`
- **RNG**: `rng-service-grpc.rgs-core.svc.cluster.local:7700`

### Configuration Files

The chart manages three configuration files:

1. **config.yaml** - Server configuration (HTTP, service endpoints)
2. **dede5000.yaml** - Game-specific rules and logic
3. **addon.js** - Client-side JavaScript configuration

All are managed via Helm values and deployed as ConfigMaps.

## Accessing the Game

Once deployed, the game will be accessible at:

**HTTP**: `http://dev-h3-games.ninjagaming.com:30828/cyprus-dede5000/`

**HTTPS** (if configured): `https://dev-h3-games.ninjagaming.com:30827/cyprus-dede5000/`

### API Endpoint

The game server API endpoint:
- `http://dev-h3-games.ninjagaming.com:30828/cyprus-dede5000/api/`

## Monitoring

### Check deployment status

```bash
kubectl get pods -n rgs-games -l app=dede5000
kubectl get svc -n rgs-games -l app=dede5000
kubectl get vs -n rgs-games -l app=dede5000
kubectl get cm -n rgs-games -l app=dede5000
```

### View logs

```bash
# Server logs
kubectl logs -n rgs-games -l app=dede5000,component=server -f

# Client logs
kubectl logs -n rgs-games -l app=dede5000,component=client -f
```

### View configuration

```bash
# Server config
kubectl get configmap dede5000-server-config -n rgs-games -o yaml

# Client config
kubectl get configmap dede5000-client-config -n rgs-games -o yaml
```

### Test connectivity

```bash
# Test from within cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n rgs-games -- curl -v http://dede5000-client:8089

# Test from outside (from bastion host)
curl -H "Host: dev-h3-games.ninjagaming.com" http://10.10.10.21:30828/cyprus-dede5000/
```

## Troubleshooting

### ImagePullBackOff error

If pods show `ImagePullBackOff`:
```bash
# Check if secret exists
kubectl get secret docker-registry-credentials -n rgs-games

# If missing, create it for ninjargs registry:
kubectl create secret docker-registry docker-registry-credentials \
  --docker-server=ninjargs \
  --docker-username=your-username \
  --docker-password=your-password \
  -n rgs-games
```

### Server not starting

Check if dependencies are running:
```bash
kubectl get pods -n rgs-core | grep -E 'overlord|history|rng'
```

### Configuration not loading

Check if ConfigMaps exist and are mounted:
```bash
# List ConfigMaps
kubectl get cm -n rgs-games -l app=dede5000

# Check mounted volumes in pod
kubectl describe pod -n rgs-games -l app=dede5000,component=server
kubectl describe pod -n rgs-games -l app=dede5000,component=client
```

### Client not working

If the client shows errors:
1. Check browser console for JavaScript errors
2. Verify client port is 8089 (not 80):
   ```bash
   kubectl exec -it deployment/dede5000-client -n rgs-games -- ss -tulpn | grep nginx
   ```
3. Check if addon.js is mounted correctly:
   ```bash
   kubectl exec -it deployment/dede5000-client -n rgs-games -- cat /usr/src/app/games/common/src/addon.js
   ```

## Updating Configuration

To update game configuration:

1. **Edit values.yaml** - Update the config or gameConfig sections
2. **Apply changes**:
   ```bash
   helm upgrade dede5000 ./dede5000 -n rgs-games
   ```
3. **Restart pods** (if needed):
   ```bash
   kubectl rollout restart deployment/dede5000-server -n rgs-games
   kubectl rollout restart deployment/dede5000-client -n rgs-games
   ```

## Game-Specific Notes

### Cyprus Go Server

This game uses the generic `cyprus-go-server` (v1.0.10) which can run multiple games. The game-specific logic is defined in `dede5000.yaml`.

### Game Configuration

The `dede5000.yaml` defines:
- **RTP values** for different game modes
- **Symbol logic** and paylines
- **Game modes** (normal, bonus)
- **Win mechanics** with special "dede-" prefixed algorithms
- **Multipliers** and special features
- **15 base iterations** in bonus mode (vs 10 in sugarbox)

### Client Configuration

The `addon.js` handles:
- Server API endpoint configuration
- Site-specific settings
- UI customization
- Demo mode detection
- Lobby and deposit URL handling

## Differences from Sugarbox

| Feature | Dede5000 | Sugarbox |
|---------|----------|----------|
| **Game Slug** | cyprus-dede5000 | sugarbox |
| **Server Version** | 1.0.10 | 1.0.27 |
| **Server Port** | 8000 | 80 |
| **Client Port** | 8089 | 8089 |
| **Bonus Iterations** | 15 | 10 |
| **Algorithms** | dede- prefixed | No prefix |

## File Structure

```
dede5000/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Configuration values
├── README.md                       # This file
└── templates/
    ├── configmap-server.yaml      # Server config (config.yaml + dede5000.yaml)
    ├── configmap-client.yaml      # Client config (addon.js)
    ├── deployment-server.yaml     # Server deployment
    ├── deployment-client.yaml     # Client deployment
    ├── service-server.yaml        # Server service
    ├── service-client.yaml        # Client service
    └── virtualservice.yaml        # Istio routing
```

## Support

For issues with the chart, check:
- ArgoCD application status: `kubectl get app dede5000-game -n argocd`
- Pod logs in rgs-games namespace
- Istio gateway configuration
- Core services health
- Registry credentials
- ConfigMap content and mounting
- Client port configuration (8089)

## Version History

- **1.0.0** - Initial release
  - Cyprus Go Server v1.0.10 support
  - Dual ConfigMap support (server + client)
  - Game-specific configuration (dede5000.yaml)
  - Client JavaScript configuration (addon.js)
  - Istio routing configuration
  - Correct port configuration (server: 8000, client: 8089)
