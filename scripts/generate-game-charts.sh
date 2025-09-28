#!/bin/bash
# Generate Helm Charts for all Game Services
# This script parses the docker-compose files and generates Kubernetes manifests

set -e

# Game services mapping from docker-compose
declare -A EJAW_GAMES=(
    ["delicious-bonanza"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/aloha-king-elvis:1.0.38|registry.ejaw.net/rgs/frontend/slots/ninjagaming/delicious-bonanza:1.0.233"
    ["paper-toss"]="registry.ejaw.net/rgs/backend/slots/heronbyte/aviator:1.0.47|registry.ejaw.net/rgs/frontend/slots/ninjagaming/paper-toss:1.0.120"
    ["savanna-spins-multiways"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/madame-destiny:1.0.18|registry.ejaw.net/rgs/frontend/slots/ninjagaming/omnis/savanna-spins-multiways:1.1.0"
    ["aviatron"]="registry.ejaw.net/rgs/backend/slots/heronbyte/aviator:1.0.47|registry.ejaw.net/rgs/frontend/slots/ninjagaming/aviatron:1.0.81"
    ["caribbean-bones"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/beast-below:1.0.18|registry.ejaw.net/rgs/frontend/slots/ninjagaming/caribbien-bounes:1.0.274"
    ["winds-of-wins"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/dog-house-megaways:3.0.1|registry.ejaw.net/rgs/frontend/slots/ninjagaming/winds-of-wins:1.0.135"
    ["cat-mansion"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/dog-house-megaways:3.0.1|registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109"
    ["candy-crashout"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/sweet-bonanza:1.0.14|registry.ejaw.net/rgs/frontend/slots/ninjagaming/sweet-bonanza:1.0.175"
    ["epic-tresur-spins"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/sweet-kingdom:1.0.8|registry.ejaw.net/rgs/frontend/slots/ninjagaming/omnis/epic-tresur-spins:2.0.2"
    ["aztec-mystique"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/candy-blitz-bombs:1.0.11|registry.ejaw.net/rgs/frontend/slots/ninjagaming/omnis/aztec-mystique:2.0.3"
    ["plinko-show"]="rg.fr-par.scw.cloud/ejaw/plinko-x-server:1.0.5|registry.ejaw.net/rgs/frontend/slots/ninjagaming/ninja-x-plinko:1.0.33"
    ["ninja-clan"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/ninja-clan:1.0.3|registry.ejaw.net/rgs/frontend/slots/ninjagaming/ninja-clan:0.1.25"
    ["pepper-party"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/extra-chilli:1.0.7|registry.ejaw.net/rgs/frontend/slots/ninjagaming/pepper-party:1.0.30"
    ["big-beak-guppy"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/gates-of-olympus:1.0.11|registry.ejaw.net/rgs/frontend/slots/ninjagaming/big-beak-guppy:0.1.18"
    ["canyon-of-riches"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/sweet-kingdom:1.0.8|registry.ejaw.net/rgs/frontend/slots/ninjagaming/canyon-of-riches:1.0.36"
    ["cowboy-cashout"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/candy-blitz-bombs:1.0.11|registry.ejaw.net/rgs/frontend/slots/ninjagaming/wild-west:1.0.224"
    ["captain-vs-kingslime"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/zeus-vs-hades:1.0.17|registry.ejaw.net/rgs/frontend/slots/ninjagaming/captain-vs-kingslime:0.0.178"
    ["gamblers-gala"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/gates-of-olympus:1.0.11|registry.ejaw.net/rgs/frontend/slots/ninjagaming/gates-of-olympus:1.0.84"
    ["great-bear-multiways"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/great-rhino-megaways:1.0.37|registry.ejaw.net/rgs/frontend/slots/ninjagaming/great-rhino-megaways:1.1.194"
    ["king-of-vegas-nights"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/aloha-king-elvis:1.0.38|registry.ejaw.net/rgs/frontend/slots/ninjagaming/aloha-king-elvis:1.0.191"
    ["riches-of-valhall"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/great-rhino-megaways:1.0.37|registry.ejaw.net/rgs/frontend/slots/ninjagaming/omnis/riches-of-valhalla:1.1.253"
    ["rush-moji"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/sugar-rush:1.1.1|registry.ejaw.net/rgs/frontend/slots/ninjagaming/sugar-rush:1.0.175"
    ["spinx-club"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/wild-wild-riches-megaways:1.0.14|registry.ejaw.net/rgs/frontend/slots/ninjagaming/fairy-glade-riches-multiways:1.0.141"
    ["winland"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/shadow-strike:1.0.14|registry.ejaw.net/rgs/frontend/slots/ninjagaming/shadow-strike:1.0.493"
    ["witch-of-fortune-multiways"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/madame-destiny:1.0.18|registry.ejaw.net/rgs/frontend/slots/ninjagaming/witch-of-fortune-megaways:1.0.173"
    ["frenzy-fruit"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/sweet-bonanza:1.0.14|rg.fr-par.scw.cloud/ejaw/frenzy-fruit-client:1.0.186"
    ["sangria-time"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/frozen-fuits-reskin:1.0.15|registry.ejaw.net/rgs/frontend/slots/ninjagaming/burning-ice:0.1.7"
    ["blackbeards-jackpot"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/fire-rooster:1.0.16|registry.ejaw.net/rgs/frontend/slots/ninjagaming/fire-rooster-reskin:0.1.4"
    ["a-day-in-macau"]="registry.ejaw.net/rgs/backend/slots/ninjagaming/a-day-in-macau:1.0.22|registry.ejaw.net/rgs/frontend/slots/ninjagaming/a-day-in-macau:1.0.202"
)

declare -A PROGA_GAMES=(
    ["ocean-fish"]="ocean-fish-server|ocean-fish-client"
    ["baseball-crash"]="baseball-crash-server|baseball-crash-client"
    ["danger-zone"]="danger-zone-server|danger-zone-client"
    ["strike-zone"]="strike-zone-server|strike-zone-client"
    ["sugarbox1000"]="sugarbox1000-server|sugarbox1000-client"
    ["sugar-box-1000-valentines"]="sugar-box-1000-valentines-server|sugar-box-1000-valentines-client"
    ["sugarbox"]="sugarbox-server|sugarbox-client"
    ["betturkeybox1000"]="betturkeybox1000-server|betturkeybox1000-client"
    ["gold-tooth-pirate"]="gold-tooth-pirate-server|gold-tooth-pirate-client"
    ["magic-princess"]="magic-princess-server|magic-princess-client"
    ["magic-princess-1000"]="magic-princess-1000-server|magic-princess-1000-client"
    ["magic-princess-5000"]="magic-princess-5000-server|magic-princess-5000-client"
    ["dede"]="dede-server|dede-client"
    ["dede-1000"]="dede-1000-server|dede-1000-client"
    ["dede5000"]="dede5000-server|dede5000-client"
    ["mariobet-dede-5000"]="mariobet-dede-5000-server|mariobet-dede-5000-client"
    ["bahis-dede-5000"]="bahis-dede-5000-server|bahis-dede-5000-client"
    ["fixbet-dede-5000"]="fixbet-dede-5000-server|fixbet-dede-5000-client"
    ["matadorbet-dede-5000"]="matadorbet-dede-5000-server|matadorbet-dede-5000-client"
    ["bycasino-dede-5000"]="bycasino-dede-5000-server|bycasino-dede-5000-client"
    ["cash-bandicoot"]="cash-bandicoot-server|cash-bandicoot-client"
    ["kralbet-dede-5000"]="kralbet-dede-5000-server|kralbet-dede-5000-client"
    ["jungle-king"]="jungle-king-server|jungle-king-client"
    ["xslot-dede-5000"]="xslot-dede-5000-server|xslot-dede-5000-client"
    ["otobet-dede-5000"]="otobet-dede-5000-server|otobet-dede-5000-client"
    ["solobet-dede-5000"]="solobet-dede-5000-server|solobet-dede-5000-client"
    ["solobet-sugar-box-1000"]="solobet-sugar-box-1000-server|solobet-sugar-box-1000-client"
)

# Base directory for helm charts
HELM_BASE_DIR="helm-charts/game-services"

# Function to create helm chart for a game
create_game_helm_chart() {
    local game_name=$1
    local server_image=$2
    local client_image=$3
    local is_websocket=$4
    
    local chart_dir="$HELM_BASE_DIR/$game_name"
    
    echo "Creating Helm chart for $game_name..."
    
    # Create directory structure
    mkdir -p "$chart_dir/templates"
    
    # Create Chart.yaml
    cat <<EOF > "$chart_dir/Chart.yaml"
apiVersion: v2
name: $game_name
description: Game service for $game_name
type: application
version: 1.0.0
appVersion: "1.0.0"
dependencies: []
EOF
    
    # Create values.yaml
    cat <<EOF > "$chart_dir/values.yaml"
# Default values for $game_name
nameOverride: "$game_name"
fullnameOverride: ""

replicaCount:
  server: 2
  client: 1

server:
  image:
    repository: $server_image
    pullPolicy: IfNotPresent
    tag: "" # Uses appVersion if not set

client:
  image:
    repository: $client_image
    pullPolicy: IfNotPresent
    tag: "" # Uses appVersion if not set

imagePullSecrets:
  - name: regcred

service:
  type: ClusterIP
  serverPort: 8000
  clientPort: 80
  annotations: {}

websocket:
  enabled: $is_websocket
  
resources:
  server:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi
  client:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}
tolerations: []
affinity: {}

podAnnotations:
  sidecar.istio.io/inject: "true"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false

livenessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5

config:
  rtp: 94
  volatility: medium
  debug: false
  
dependencies:
  overlord:
    host: overlord.rgs-core.svc.cluster.local
    port: 7500
    isSecure: true
  
  history:
    host: history.rgs-core.svc.cluster.local
    port: 7200
    isSecure: true
  
  rng:
    host: rng.rgs-core.svc.cluster.local
    port: 7700
    isSecure: true
EOF
    
    # Create deployment template
    cat <<'EOF' > "$chart_dir/templates/deployment.yaml"
{{- $game := .Values.nameOverride -}}
---
# Server Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $game }}-server
  labels:
    app: {{ $game }}
    component: server
    version: {{ .Values.server.image.tag | default .Chart.AppVersion }}
spec:
  replicas: {{ .Values.replicaCount.server }}
  selector:
    matchLabels:
      app: {{ $game }}
      component: server
  template:
    metadata:
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
      labels:
        app: {{ $game }}
        component: server
        version: {{ .Values.server.image.tag | default .Chart.AppVersion }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: server
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.server.image.repository }}:{{ .Values.server.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.server.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 8000
          protocol: TCP
        {{- if .Values.websocket.enabled }}
        - name: websocket
          containerPort: 8000
          protocol: TCP
        {{- end }}
        livenessProbe:
          {{- toYaml .Values.livenessProbe | nindent 12 }}
        readinessProbe:
          {{- toYaml .Values.readinessProbe | nindent 12 }}
        resources:
          {{- toYaml .Values.resources.server | nindent 12 }}
        volumeMounts:
        - name: config
          mountPath: /app/config.yaml
          subPath: config.yaml
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: config
        configMap:
          name: {{ $game }}-config
      - name: tmp
        emptyDir: {}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
---
# Client Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ $game }}-client
  labels:
    app: {{ $game }}
    component: client
spec:
  replicas: {{ .Values.replicaCount.client }}
  selector:
    matchLabels:
      app: {{ $game }}
      component: client
  template:
    metadata:
      annotations:
        {{- toYaml .Values.podAnnotations | nindent 8 }}
      labels:
        app: {{ $game }}
        component: client
        version: {{ .Values.client.image.tag | default .Chart.AppVersion }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: client
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.client.image.repository }}:{{ .Values.client.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.client.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          {{- toYaml .Values.resources.client | nindent 12 }}
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
EOF
    
    # Create service template
    cat <<'EOF' > "$chart_dir/templates/service.yaml"
{{- $game := .Values.nameOverride -}}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $game }}-server
  labels:
    app: {{ $game }}
    component: server
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.serverPort }}
    targetPort: 8000
    protocol: TCP
    name: http
  {{- if .Values.websocket.enabled }}
  - port: {{ .Values.service.serverPort }}
    targetPort: 8000
    protocol: TCP
    name: websocket
  {{- end }}
  selector:
    app: {{ $game }}
    component: server
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $game }}-client
  labels:
    app: {{ $game }}
    component: client
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.clientPort }}
    targetPort: 80
    protocol: TCP
    name: http
  selector:
    app: {{ $game }}
    component: client
EOF
    
    # Create ConfigMap template
    cat <<'EOF' > "$chart_dir/templates/configmap.yaml"
{{- $game := .Values.nameOverride -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ $game }}-config
  labels:
    app: {{ $game }}
data:
  config.yaml: |
    engine:
      rtp: {{ .Values.config.rtp }}
      volatility: {{ .Values.config.volatility }}
      debug: {{ .Values.config.debug }}
    
    server:
      host: 0.0.0.0
      port: 8000
      readTimeout: 30s
      writeTimeout: 30s
      maxProcessingTime: 10000
    
    {{- if .Values.websocket.enabled }}
    websocket:
      maxProcessingTime: 10000ms
      readBufferSize: 1024
      writeBufferSize: 1024
    {{- end }}
    
    overlord:
      host: {{ .Values.dependencies.overlord.host }}
      port: {{ .Values.dependencies.overlord.port }}
      isSecure: {{ .Values.dependencies.overlord.isSecure }}
    
    history:
      host: {{ .Values.dependencies.history.host }}
      port: {{ .Values.dependencies.history.port }}
      isSecure: {{ .Values.dependencies.history.isSecure }}
    
    rng:
      host: {{ .Values.dependencies.rng.host }}
      port: {{ .Values.dependencies.rng.port }}
      maxProcessingTime: 10000ms
    
    game:
      availableGames:
        - {{ $game }}
      availableIntegrators:
        - ninjagaming_lb
        - mock
    
    logger:
      logLevel: info
EOF
    
    # Create HPA template
    cat <<'EOF' > "$chart_dir/templates/hpa.yaml"
{{- if .Values.autoscaling.enabled }}
{{- $game := .Values.nameOverride -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $game }}-server-hpa
  labels:
    app: {{ $game }}
    component: server
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ $game }}-server
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
EOF
    
    echo "Created Helm chart for $game_name"
}

# Main execution
main() {
    mkdir -p "$HELM_BASE_DIR"
    
    # Process EJAW games
    echo "Processing EJAW games..."
    for game in "${!EJAW_GAMES[@]}"; do
        IFS='|' read -r server_image client_image <<< "${EJAW_GAMES[$game]}"
        
        # Check if it's a websocket game
        is_websocket="false"
        if [[ "$game" == "paper-toss" ]] || [[ "$game" == "aviatron" ]]; then
            is_websocket="true"
        fi
        
        # Extract just the image name without tag
        server_image_name=$(echo "$server_image" | cut -d: -f1)
        client_image_name=$(echo "$client_image" | cut -d: -f1)
        
        create_game_helm_chart "$game" "$server_image_name" "$client_image_name" "$is_websocket"
    done
    
    # Process Proga games
    echo "Processing Proga games..."
    for game in "${!PROGA_GAMES[@]}"; do
        IFS='|' read -r server_image client_image <<< "${PROGA_GAMES[$game]}"
        
        # Check if it's a websocket game
        is_websocket="false"
        if [[ "$game" == "baseball-crash" ]] || [[ "$game" == "danger-zone" ]] || [[ "$game" == "strike-zone" ]]; then
            is_websocket="true"
        fi
        
        # For Proga games, we'll use a standard image path
        server_image_name="ninjargs/proga-$server_image"
        client_image_name="ninjargs/proga-$client_image"
        
        create_game_helm_chart "$game" "$server_image_name" "$client_image_name" "$is_websocket"
    done
    
    echo "Helm chart generation completed!"
    echo "Total charts created: $(ls -1 $HELM_BASE_DIR | wc -l)"
}

# Run the script
main
