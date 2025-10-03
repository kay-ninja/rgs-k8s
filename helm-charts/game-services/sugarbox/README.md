# Sugarbox Game Helm Chart

This Helm chart deploys the Sugarbox game service to Kubernetes with Istio routing.

## Overview

The chart deploys:
- **Server** (Cyprus Go Server) - Port 80
- **Client** (Frontend) - Port 80
- **Server ConfigMap** - Server and game configuration (config.yaml + sugarbox.yaml)
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
unzip sugarbox-helm-chart.zip
cp -r sugarbox /path/to/rgs-k8s/helm-charts/game-services/
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
git add helm-charts/game-services/sugarbox/
git commit -m "Add sugarbox game helm chart"
git push
```

ArgoCD will automatically:
- Create the `sugarbox-game` application
- Deploy to `rgs-games` namespace
- Sync continuously

Check ArgoCD:
```bash
kubectl get application sugarbox-game -n argocd
argocd app get sugarbox-game
```

### 4. Manual deployment (alternative)

```bash
helm upgrade --install sugarbox ./sugarbox \
  --namespace rgs-games \
  --create-namespace
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gameSlug` | URL path for game | `sugarbox` |
| `replicaCount` | Number of replicas | `2` |
| `imagePullSecrets` | Registry credentials | `docker-registry-credentials` |
| `server.image.tag` | Server image version | `1.0.27` |
| `client.image.tag` | Client image version | `4.0.17-go-server` |
| `server.port` | Server port | `80` |
| `client.port` | Client port | `80` |

### Service Endpoints

The chart automatically connects to:
- **Overlord**: `overlord-service.rgs-core.svc.cluster.local:7500`
- **History**: `history-service.rgs-core.svc.cluster.local:7200`
- **RNG**: `rng-service-grpc.rgs-core.svc.cluster.local:7700`

### Configuration Files

The chart manages three configuration files:

1. **config.yaml** - Server configuration (HTTP, service endpoints)
2. **sugarbox.yaml** - Game-specific rules and logic
3. **addon.js** - Client-side JavaScript configuration

All are managed via Helm values and deployed as ConfigMaps.

## Accessing the Game

Once deployed, the game will be accessible at:

**HTTP**: `http://dev-h3-games.ninjagaming.com:30828/sugarbox/`

**HTTPS** (if configured): `https://dev-h3-games.ninjagaming.com:30827/sugarbox/`

### API Endpoint

The game server API endpoint:
- `http://dev-h3-games.ninjagaming.com:30828/sugarbox/api/`

## Monitoring

### Check deployment status

```bash
kubectl get pods -n rgs-games -l app=sugarbox
kubectl get svc -n rgs-games -l app=sugarbox
kubectl get vs -n rgs-games -l app=sugarbox
kubectl get cm -n rgs-games -l app=sugarbox
```

### View logs

```bash
# Server logs
kubectl logs -n rgs-games -l app=sugarbox,component=server -f

# Client logs
kubectl logs -n rgs-games -l app=sugarbox,component=client -f
```

### View configuration

```bash
# Server config
kubectl get configmap sugarbox-server-config -n rgs-games -o yaml

# Client config
kubectl get configmap sugarbox-client-config -n rgs-games -o yaml
```

### Test connectivity

```bash
# Test from within cluster
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n rgs-games -- curl -v http://sugarbox-client:80

# Test from outside (from bastion host)
curl -H "Host: dev-h3-games.ninjagaming.com" http://10.10.10.21:30828/sugarbox/
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
kubectl get cm -n rgs-games -l app=sugarbox

# Check mounted volumes in pod
kubectl describe pod -n rgs-games -l app=sugarbox,component=server
kubectl describe pod -n rgs-games -l app=sugarbox,component=client
```

### Client addon.js not working

If the client shows errors related to configuration:
1. Check the ConfigMap content:
   ```bash
   kubectl get cm sugarbox-client-config -n rgs-games -o yaml
   ```
2. Verify the mount path matches the expected location
3. Check client logs for JavaScript errors

## Updating Configuration

To update game configuration:

1. **Edit values.yaml** - Update the config or gameConfig sections
2. **Apply changes**:
   ```bash
   helm upgrade sugarbox ./sugarbox -n rgs-games
   ```
3. **Restart pods** (if needed):
   ```bash
   kubectl rollout restart deployment/sugarbox-server -n rgs-games
   kubectl rollout restart deployment/sugarbox-client -n rgs-games
   ```

## Replicating for Other Games Using Cyprus Go Server

If you have other games that use the same cyprus-go-server:

1. **Copy this directory:**
   ```bash
   cp -r sugarbox another-game
   cd another-game
   ```

2. **Update Chart.yaml:**
   ```yaml
   name: another-game
   description: Another game service for RGS platform
   ```

3. **Update values.yaml:**
   ```yaml
   gameSlug: another-game  # Change this
   
   client:
     image:
       repository: another-game-client  # Update client image
       tag: "1.0.0"  # Update version
   
   clientConfig:
     serverIP: "https://dev-h3-games.ninjagaming.com/another-game/api"
   ```

4. **Update game configuration** in `values.yaml`:
   - Update `gameConfig` section with game-specific rules
   - Keep `config` section mostly the same (just HTTP and service endpoints)

5. **Update client config** if the game has custom addon.js requirements

6. **Commit and push** - ArgoCD will auto-deploy

## File Structure

```
sugarbox/
├── Chart.yaml                      # Chart metadata
├── values.yaml                     # Configuration values
├── templates/
│   ├── configmap-server.yaml      # Server config (config.yaml + sugarbox.yaml)
│   ├── configmap-client.yaml      # Client config (addon.js)
│   ├── deployment-server.yaml     # Server deployment
│   ├── deployment-client.yaml     # Client deployment
│   ├── service-server.yaml        # Server service
│   ├── service-client.yaml        # Client service
│   └── virtualservice.yaml        # Istio routing
└── README.md                       # This file
```

## Game-Specific Notes

### Cyprus Go Server

This game uses the generic `cyprus-go-server` which can run multiple games. The game-specific logic is defined in `sugarbox.yaml`.

### Game Configuration

The `sugarbox.yaml` defines:
- **RTP values** for different game modes
- **Symbol logic** and paylines
- **Game modes** (normal, bonus)
- **Win mechanics** and cascading logic
- **Multipliers** and special features

### Client Configuration

The `addon.js` handles:
- Server API endpoint configuration
- Site-specific settings
- UI customization
- Demo mode detection
- Lobby and deposit URL handling

## Support

For issues with the chart, check:
- ArgoCD application status: `kubectl get app sugarbox-game -n argocd`
- Pod logs in rgs-games namespace
- Istio gateway configuration
- Core services health
- Registry credentials
- ConfigMap content and mounting

## Version History

- **1.0.0** - Initial release
  - Cyprus Go Server support
  - Dual ConfigMap support (server + client)
  - Game-specific configuration (sugarbox.yaml)
  - Client JavaScript configuration (addon.js)
  - Istio routing configuration
