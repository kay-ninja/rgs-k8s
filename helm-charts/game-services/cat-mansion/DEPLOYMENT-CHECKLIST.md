# Cat-Mansion Deployment Checklist

## Pre-Deployment (CRITICAL)

### 1. ⚠️ VERIFY CLIENT PORT (MOST IMPORTANT!)
```bash
docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \
  sh -c "sleep 5 && ss -tulpn | grep nginx"
```

**What to look for:**
- [ ] Port 80: Continue with default values.yaml
- [ ] Port 8089: Update values.yaml client.port to 8089

**If port is 8089, update these in values.yaml:**
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

### 2. Prerequisites Check
- [ ] Kubernetes cluster accessible
- [ ] Helm 3.x installed
- [ ] kubectl configured
- [ ] Namespace `rgs-games` exists
  ```bash
  kubectl create namespace rgs-games
  ```

### 3. Registry Credentials
- [ ] Docker registry secret created
  ```bash
  kubectl create secret docker-registry docker-registry-credentials \
    --docker-server=registry.ejaw.net \
    --docker-username=<username> \
    --docker-password=<password> \
    -n rgs-games
  ```

### 4. Dependencies Check
- [ ] Overlord service available in `rgs-core` namespace
- [ ] History service available in `rgs-core` namespace
- [ ] RNG service available in `rgs-core` namespace
- [ ] Redis available in `rgs-infrastructure` namespace (if needed)

### 5. Chart Validation
- [ ] Run validation script
  ```bash
  chmod +x validate-chart.sh
  ./validate-chart.sh
  ```
- [ ] Helm lint passes
  ```bash
  helm lint ./cat-mansion
  ```
- [ ] Dry-run successful
  ```bash
  helm install cat-mansion ./cat-mansion -n rgs-games --dry-run
  ```

## Deployment

### 6. Install Chart
```bash
helm install cat-mansion ./cat-mansion -n rgs-games
```

### 7. Monitor Deployment
```bash
# Watch pods come up
kubectl get pods -n rgs-games -l app=cat-mansion -w

# Expected output (after 30-60 seconds):
# cat-mansion-server-xxx   1/1   Running
# cat-mansion-client-xxx   1/1   Running
```

## Post-Deployment Verification

### 8. Check Pod Status
- [ ] All pods Running (1/1)
  ```bash
  kubectl get pods -n rgs-games -l app=cat-mansion
  ```
- [ ] No CrashLoopBackOff
- [ ] No ImagePullBackOff

### 9. Verify Client Port (In Cluster)
```bash
kubectl exec -it deployment/cat-mansion-client -n rgs-games -- ss -tulpn | grep nginx
```
- [ ] Nginx listening on expected port
- [ ] Port matches values.yaml configuration

### 10. Check Services
```bash
kubectl get svc -n rgs-games -l app=cat-mansion
```
- [ ] `cat-mansion-server` service exists
- [ ] `cat-mansion-client` service exists
- [ ] Both are ClusterIP type

### 11. Check ConfigMap
```bash
kubectl get cm -n rgs-games -l app=cat-mansion
```
- [ ] `cat-mansion-server-config` exists

### 12. Check VirtualService
```bash
kubectl get virtualservice -n rgs-games cat-mansion
```
- [ ] VirtualService created
- [ ] Routes configured correctly

### 13. Test Connectivity
```bash
# Port forward to client
kubectl port-forward svc/cat-mansion-client 8080:80 -n rgs-games

# Then access: http://localhost:8080
```
- [ ] Client loads successfully
- [ ] No 502/503 errors

### 14. Check Logs
```bash
# Server logs
kubectl logs -n rgs-games -l app=cat-mansion,component=server --tail=50

# Client logs  
kubectl logs -n rgs-games -l app=cat-mansion,component=client --tail=50
```
- [ ] No errors in server logs
- [ ] No errors in client logs
- [ ] Server connected to overlord/history/rng

### 15. Access Game
```bash
# Access via ingress
curl -I http://dev-h3-games.ninjagaming.com:30828/cat-mansion/
```
- [ ] Returns 200 OK
- [ ] Game loads in browser
- [ ] API endpoint accessible: `/cat-mansion/api/`

### 16. Test Game Functionality
- [ ] Game loads and renders
- [ ] WebSocket connection established (check browser console)
- [ ] Can place bets
- [ ] Game rounds work correctly
- [ ] No console errors

## Troubleshooting

### If pods are CrashLoopBackOff:
1. Check port configuration matches actual nginx port
2. Review liveness/readiness probe settings
3. Check logs: `kubectl logs -n rgs-games <pod-name>`

### If ImagePullBackOff:
1. Verify registry credentials exist and are correct
2. Check image names and tags in values.yaml
3. Test pull manually: `docker pull <image>`

### If game not accessible:
1. Check VirtualService configuration
2. Verify gateway exists: `kubectl get gateway -n istio-system`
3. Test service directly: `kubectl port-forward`

### If server can't connect to services:
1. Test from server pod:
   ```bash
   kubectl exec -it deployment/cat-mansion-server -n rgs-games -- sh
   nc -zv overlord-service.rgs-core.svc.cluster.local 7500
   ```
2. Verify service endpoints exist in other namespaces

## Rollback

If deployment fails:
```bash
helm uninstall cat-mansion -n rgs-games
```

## Success Criteria

✅ All pods Running (1/1)
✅ No errors in logs
✅ Services accessible
✅ Game loads at http://dev-h3-games.ninjagaming.com:30828/cat-mansion/
✅ WebSocket connections work
✅ Game functionality works (can play rounds)

## Notes

- Estimated deployment time: 2-3 minutes
- Total pods: 4 (2 server + 2 client replicas)
- Resource usage: ~1.4 CPU, ~1.5Gi RAM total
- Pattern: Custom Server with WebSocket (Aviatron-style)

## Post-Deployment

After successful deployment:
- [ ] Document any configuration changes made
- [ ] Update monitoring/alerting
- [ ] Schedule health checks
- [ ] Plan scaling strategy if needed
