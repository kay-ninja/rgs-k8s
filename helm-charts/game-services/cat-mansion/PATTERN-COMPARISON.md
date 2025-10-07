# Cat-Mansion Architecture Pattern Comparison

## Pattern Classification: Custom Server with WebSocket

Cat-Mansion follows the **Aviatron pattern** (Pattern 1) based on these characteristics:

### Comparison Matrix

| Feature | Aviatron | Cat-Mansion | Sugarbox | Dede5000 |
|---------|----------|-------------|----------|----------|
| **Server Type** | Custom | Custom | Cyprus-Go | Cyprus-Go |
| **Server Image** | heronbyte/aviator | ninjagaming/dog-house-megaways | cyprus-go-server | cyprus-go-server |
| **WebSocket** | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| **Redis** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Bot System** | ✅ Yes (400+ names) | ❌ No | ❌ No | ❌ No |
| **Config Files** | 1 (all-in-one) | 1 (all-in-one) | 3 (2 server + 1 client) | 3 (2 server + 1 client) |
| **Server Port** | 8000 | 8000 | 80 | 8000 |
| **Client Port** | 80 | 80? (needs verification) | 8089 | 8089 |
| **Tracer** | ❌ No | ✅ Yes (disabled) | ❌ No | ❌ No |
| **Pattern** | Pattern 1 | Pattern 1 | Pattern 2 | Pattern 2 |

## Why Cat-Mansion Uses Aviatron Pattern

### ✅ Similarities with Aviatron:
1. **Custom Server**: Uses specialized `dog-house-megaways` backend (not generic cyprus-go-server)
2. **WebSocket Support**: Has dedicated websocket configuration section
3. **Single Config File**: All configuration in one `config.yaml` file
4. **Same Registry**: Both use `registry.ejaw.net`
5. **Port 8000**: Server runs on port 8000 (like Aviatron)
6. **Complex Features**: Has tracer integration (more advanced)

### ❌ Differences from Cyprus-Go Pattern (Sugarbox/Dede5000):
1. **Not Generic Server**: Sugarbox/Dede5000 use generic `cyprus-go-server`
2. **No Game Logic YAML**: Cyprus-Go pattern splits game logic into separate YAML file
3. **No Client Config**: Cyprus-Go pattern has `addon.js` for client configuration
4. **Different Architecture**: Single comprehensive config vs. modular config

## Configuration Structure Comparison

### Cat-Mansion (Pattern 1 - Like Aviatron)
```
ConfigMaps:
└── cat-mansion-server-config
    └── config.yaml (all-in-one)
        ├── engine (RTP, volatility, etc.)
        ├── server (host, port, timeouts)
        ├── websocket (buffers, timeouts)
        ├── overlord/history/rng endpoints
        ├── tracer (optional monitoring)
        ├── game (available games & integrators)
        └── logger
```

### Sugarbox/Dede5000 (Pattern 2 - Cyprus-Go)
```
ConfigMaps:
├── server-config
│   ├── config.yaml (HTTP + service endpoints)
│   └── {game}.yaml (game-specific logic/rules)
└── client-config
    └── addon.js (client environment config)
```

## Migration Implications

### Template Selection
✅ **Use Aviatron templates** because:
- Custom server (not cyprus-go-server)
- WebSocket configuration present
- Single config file structure
- Complex feature set

❌ **Don't use Sugarbox/Dede5000 templates** because:
- Different server type
- Different config structure
- No game logic YAML separation
- No client addon.js needed

### Key Considerations

1. **Port Verification (CRITICAL)**
   ```bash
   # MUST verify before deploying
   docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \
     sh -c "sleep 5 && ss -tulpn"
   ```
   - Aviatron client: Port 80 ✅
   - Sugarbox client: Port 8089 ✅
   - Dede5000 client: Port 8089 ✅
   - **Cat-Mansion client: Unknown - verify first!**

2. **Service Endpoints**
   All games need Kubernetes FQDN format:
   ```yaml
   overlord: overlord-service.rgs-core.svc.cluster.local:7500
   history: history-service.rgs-core.svc.cluster.local:7200
   rng: rng-service-grpc.rgs-core.svc.cluster.local:7700
   ```

3. **WebSocket Routing**
   Like Aviatron, Cat-Mansion needs WebSocket support through Istio VirtualService

## Resource Allocation

All games use standard resources:

```yaml
Server:
  requests: 200m CPU, 256Mi RAM
  limits:   500m CPU, 512Mi RAM

Client:
  requests: 100m CPU, 128Mi RAM
  limits:   200m CPU, 256Mi RAM

Total per game: ~1.4 CPU, ~1.5Gi RAM (with 2 replicas each)
```

## Deployment Pattern

### Pattern 1 (Aviatron, Cat-Mansion)
```yaml
Structure:
- deployment-server.yaml
- deployment-client.yaml
- service-server.yaml
- service-client.yaml
- configmap.yaml (single)
- virtualservice.yaml

Features:
- WebSocket in VirtualService
- Single ConfigMap
- Custom server logic
```

### Pattern 2 (Sugarbox, Dede5000)
```yaml
Structure:
- deployment-server.yaml
- deployment-client.yaml
- service-server.yaml
- service-client.yaml
- configmap-server.yaml (2 files)
- configmap-client.yaml
- virtualservice.yaml

Features:
- HTTP only
- Multiple ConfigMaps
- Generic server + game logic
```

## Migration Time Estimate

Based on established patterns:

- **First Pattern 1 game (Aviatron)**: 1-2 hours
- **Cat-Mansion (second Pattern 1 game)**: ~45-60 minutes
  - Already have Aviatron template
  - Know the pattern well
  - Main time: port verification + testing

## Success Metrics

### Completed Games
1. ✅ Aviatron (Pattern 1) - Deployed successfully
2. ✅ Sugarbox (Pattern 2) - Deployed after port fix
3. ✅ Dede5000 (Pattern 2) - Pre-configured correctly
4. 🔄 Cat-Mansion (Pattern 1) - Chart ready, awaiting port verification

### Pattern Distribution
- Pattern 1 (Custom): 2 games (Aviatron, Cat-Mansion)
- Pattern 2 (Cyprus-Go): 2 games (Sugarbox, Dede5000)

## Next Steps for Cat-Mansion

1. **Verify client port** (CRITICAL)
   ```bash
   docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \
     sh -c "sleep 5 && ss -tulpn | grep nginx"
   ```

2. **Update values.yaml** if port is not 80

3. **Deploy**
   ```bash
   helm install cat-mansion ./cat-mansion -n rgs-games
   ```

4. **Verify**
   ```bash
   kubectl get pods -n rgs-games -l app=cat-mansion
   kubectl exec -it deployment/cat-mansion-client -n rgs-games -- ss -tulpn
   ```

5. **Test**
   - Access: http://dev-h3-games.ninjagaming.com:30828/cat-mansion/
   - Check WebSocket connection
   - Test game functionality

## Key Lessons Applied

1. ✅ **Pattern Recognition**: Correctly identified as Pattern 1 based on architecture
2. ✅ **Template Reuse**: Used Aviatron as base template
3. ✅ **Port Awareness**: Added warnings and verification steps
4. ✅ **Service Endpoints**: Pre-configured Kubernetes FQDN
5. ✅ **Documentation**: Comprehensive README and checklist

## Future Games

When migrating future games:

### If game has:
- **WebSocket** → Use Aviatron/Cat-Mansion template (Pattern 1)
- **Redis** → Use Aviatron template (Pattern 1)
- **cyprus-go-server** → Use Sugarbox/Dede5000 template (Pattern 2)
- **Single config** → Likely Pattern 1
- **Multiple configs** → Likely Pattern 2

Always verify client port first! 🚨
