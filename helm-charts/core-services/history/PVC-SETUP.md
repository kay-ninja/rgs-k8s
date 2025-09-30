# GeoIP Database PVC Setup

The History service requires a 64MB MaxMind GeoIP2 Country database (`country.mmdb`) mounted via a PersistentVolumeClaim.

## Step 1: Create the PVC

```bash
cat <<EOF | kubectl apply -f -
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
```

**Note:** Change `<your-storage-class>` to your cluster's storage class. Use `kubectl get sc` to list available storage classes.

## Step 2: Upload country.mmdb to the PVC

### Method A: Using a temporary pod

```bash
# Create a pod that mounts the PVC
kubectl run geoip-uploader -n rgs-core \
  --image=busybox \
  --restart=Never \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "uploader",
      "image": "busybox",
      "command": ["sleep", "3600"],
      "volumeMounts": [{
        "name": "geoip",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "geoip",
      "persistentVolumeClaim": {
        "claimName": "history-geoip"
      }
    }]
  }
}'

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/geoip-uploader -n rgs-core --timeout=60s

# Copy the file
kubectl cp country.mmdb rgs-core/geoip-uploader:/data/country.mmdb

# Verify the file
kubectl exec -n rgs-core geoip-uploader -- ls -lh /data/country.mmdb

# Delete the uploader pod
kubectl delete pod geoip-uploader -n rgs-core
```

### Method B: Using a Job

```bash
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: geoip-setup
  namespace: rgs-core
spec:
  template:
    spec:
      containers:
      - name: setup
        image: busybox
        command: ["sleep", "3600"]
        volumeMounts:
        - name: geoip
          mountPath: /data
      volumes:
      - name: geoip
        persistentVolumeClaim:
          claimName: history-geoip
      restartPolicy: Never
EOF

# Wait for job pod to be ready
kubectl wait --for=condition=Ready pod -l job-name=geoip-setup -n rgs-core --timeout=60s

# Get the pod name
POD_NAME=$(kubectl get pods -n rgs-core -l job-name=geoip-setup -o jsonpath='{.items[0].metadata.name}')

# Copy the file
kubectl cp country.mmdb rgs-core/$POD_NAME:/data/country.mmdb

# Verify
kubectl exec -n rgs-core $POD_NAME -- ls -lh /data/country.mmdb

# Clean up
kubectl delete job geoip-setup -n rgs-core
```

## Step 3: Deploy History Service

Once the PVC is created and populated:

```bash
helm install history ./history -n rgs-core
```

## Verification

Check that the History pod mounted the file correctly:

```bash
# Check pod status
kubectl get pods -n rgs-core -l app.kubernetes.io/name=history

# Verify file is mounted
kubectl exec -n rgs-core deployment/history -- ls -lh /app/data/ip2country/country.mmdb

# Check logs
kubectl logs -n rgs-core -l app.kubernetes.io/name=history --tail=50
```

## Troubleshooting

### Pod stuck in Pending
```bash
kubectl describe pod -n rgs-core -l app.kubernetes.io/name=history
```
Check for PVC binding issues or storage class problems.

### File not found error
Verify the PVC contains the file:
```bash
kubectl run -it --rm debug --image=busybox -n rgs-core \
  --overrides='{"spec":{"containers":[{"name":"debug","image":"busybox","command":["sh"],"volumeMounts":[{"name":"geoip","mountPath":"/data"}]}],"volumes":[{"name":"geoip","persistentVolumeClaim":{"claimName":"history-geoip"}}]}}'

# Inside the pod:
ls -lh /data/
```

### Updating the GeoIP database

```bash
# Scale down History service
kubectl scale deployment/history --replicas=0 -n rgs-core

# Upload new file (use Method A or B above)

# Scale back up
kubectl scale deployment/history --replicas=1 -n rgs-core
```

## PVC Configuration

The chart expects the PVC to be named `history-geoip` by default. You can change this in `values.yaml`:

```yaml
geoip:
  pvcName: "your-custom-pvc-name"
```
