# Cat-Mansion Quick Reference

## 🚨 BEFORE DEPLOYING - VERIFY PORT!
```bash
docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \
  sh -c "sleep 5 && ss -tulpn | grep nginx"
```
If port ≠ 80, update `values.yaml` client.port

## Quick Deploy
```bash
# 1. Verify chart
./validate-chart.sh

# 2. Install
helm install cat-mansion ./cat-mansion -n rgs-games

# 3. Watch
kubectl get pods -n rgs-games -l app=cat-mansion -w
```

## Quick Commands

### Status Check
```bash
# Pods
kubectl get pods -n rgs-games -l app=cat-mansion

# Services
kubectl get svc -n rgs-games -l app=cat-mansion

# Logs
kubectl logs -n rgs-games -l app=cat-mansion,component=server -f
kubectl logs -n rgs-games -l app=cat-mansion,component=client -f
```

### Troubleshooting
```bash
# Check actual port
kubectl exec -it deployment/cat-mansion-client -n rgs-games -- ss -tulpn | grep nginx

# Test connectivity
kubectl exec -it deployment/cat-mansion-server -n rgs-games -- sh
nc -zv overlord-service.rgs-core.svc.cluster.local 7500

# Port forward
kubectl port-forward svc/cat-mansion-client 8080:80 -n rgs-games
```

### Access
- **Game**: http://dev-h3-games.ninjagaming.com:30828/cat-mansion/
- **API**: http://dev-h3-games.ninjagaming.com:30828/cat-mansion/api/

### Upgrade/Rollback
```bash
# Upgrade
helm upgrade cat-mansion ./cat-mansion -n rgs-games

# Rollback
helm rollback cat-mansion -n rgs-games

# Uninstall
helm uninstall cat-mansion -n rgs-games
```

## Configuration Summary

| Component | Image | Port |
|-----------|-------|------|
| Server | dog-house-megaways:3.0.2 | 8000 |
| Client | cat-mansion:1.0.109 | 80? |

| Endpoint | FQDN |
|----------|------|
| Overlord | overlord-service.rgs-core.svc.cluster.local:7500 |
| History | history-service.rgs-core.svc.cluster.local:7200 |
| RNG | rng-service-grpc.rgs-core.svc.cluster.local:7700 |

## Pattern: Custom Server + WebSocket (Like Aviatron)
- Single config file
- WebSocket support
- Custom server binary
- Tracer integration (disabled)
