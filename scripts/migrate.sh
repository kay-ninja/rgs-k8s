#!/bin/bash
# RGS Platform Migration Script
# This script helps migrate from Docker Compose to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE_INFRA="rgs-infrastructure"
NAMESPACE_CORE="rgs-core"
NAMESPACE_GAMES="rgs-games"
GITHUB_REPO="https://github.com/your-org/rgs-k8s.git"
DOCKER_REGISTRY="rg.fr-par.scw.cloud/ejaw"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm not found. Please install helm."
        exit 1
    fi
    
    # Check istioctl
    if ! command -v istioctl &> /dev/null; then
        log_error "istioctl not found. Please install istioctl."
        exit 1
    fi
    
    # Check argocd
    if ! command -v argocd &> /dev/null; then
        log_error "argocd CLI not found. Please install argocd."
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_info "All prerequisites met."
}

create_namespaces() {
    log_info "Creating namespaces..."
    
    kubectl create namespace $NAMESPACE_INFRA --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $NAMESPACE_CORE --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace $NAMESPACE_GAMES --dry-run=client -o yaml | kubectl apply -f -
    
    # Label namespaces for Istio injection
    kubectl label namespace $NAMESPACE_CORE istio-injection=disabled --overwrite
    kubectl label namespace $NAMESPACE_GAMES istio-injection=disabled --overwrite
    
    log_info "Namespaces created and configured."
}

create_secrets() {
    log_info "Creating secrets..."
    
    # Create docker registry secret
    read -p "Docker Registry Username: " DOCKER_USER
    read -s -p "Docker Registry Password: " DOCKER_PASS
    echo
    
    kubectl create secret docker-registry regcred \
        --docker-server=$DOCKER_REGISTRY \
        --docker-username=$DOCKER_USER \
        --docker-password=$DOCKER_PASS \
        --namespace=$NAMESPACE_INFRA \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Copy to other namespaces
    kubectl get secret regcred -n $NAMESPACE_INFRA -o yaml | \
        sed "s/namespace: $NAMESPACE_INFRA/namespace: $NAMESPACE_CORE/" | \
        kubectl apply -f -
    
    kubectl get secret regcred -n $NAMESPACE_INFRA -o yaml | \
        sed "s/namespace: $NAMESPACE_INFRA/namespace: $NAMESPACE_GAMES/" | \
        kubectl apply -f -
    
    log_info "Registry secrets created."
}

migrate_configs() {
    log_info "Migrating configurations..."
    
    # Create ConfigMaps from existing configs
    for config in etc/*.yaml; do
        if [ -f "$config" ]; then
            filename=$(basename "$config")
            service="${filename%.*}"
            
            kubectl create configmap "${service}-config" \
                --from-file="config.yaml=$config" \
                --namespace=$NAMESPACE_CORE \
                --dry-run=client -o yaml | kubectl apply -f -
            
            log_info "Created ConfigMap for $service"
        fi
    done
}

deploy_infrastructure() {
    log_info "Deploying infrastructure services..."
    
    # PostgreSQL
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    cat <<EOF > /tmp/postgres-values.yaml
auth:
  postgresPassword: $(openssl rand -base64 32)
  database: rgs
primary:
  persistence:
    enabled: true
    size: 50Gi
  resources:
    requests:
      memory: 2Gi
      cpu: 1000m
    limits:
      memory: 4Gi
      cpu: 2000m
metrics:
  enabled: true
EOF
    
    helm upgrade --install postgresql bitnami/postgresql \
        --namespace $NAMESPACE_INFRA \
        --values /tmp/postgres-values.yaml \
        --wait
    
    # Redis
    cat <<EOF > /tmp/redis-values.yaml
auth:
  enabled: true
  password: $(openssl rand -base64 32)
master:
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m
replica:
  replicaCount: 2
  persistence:
    enabled: true
    size: 10Gi
metrics:
  enabled: true
EOF
    
    helm upgrade --install redis bitnami/redis \
        --namespace $NAMESPACE_INFRA \
        --values /tmp/redis-values.yaml \
        --wait
    
    # RabbitMQ
    cat <<EOF > /tmp/rabbitmq-values.yaml
auth:
  username: user
  password: $(openssl rand -base64 32)
persistence:
  enabled: true
  size: 10Gi
replicaCount: 3
resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 1Gi
    cpu: 500m
metrics:
  enabled: true
EOF
    
    helm upgrade --install rabbitmq bitnami/rabbitmq \
        --namespace $NAMESPACE_INFRA \
        --values /tmp/rabbitmq-values.yaml \
        --wait
    
    log_info "Infrastructure services deployed."
}

setup_istio_configs() {
    log_info "Setting up Istio configurations..."
    
    kubectl apply -f istio/gateway-virtualservices.yaml
    
    log_info "Istio configurations applied."
}

deploy_argocd_apps() {
    log_info "Deploying ArgoCD applications..."
    
    # Check if ArgoCD is installed
    if ! kubectl get namespace argocd &> /dev/null; then
        log_warn "ArgoCD namespace not found. Installing ArgoCD..."
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        # Wait for ArgoCD to be ready
        kubectl wait --for=condition=available --timeout=300s \
            deployment/argocd-server -n argocd
    fi
    
    # Apply ArgoCD applications
    kubectl apply -f argocd/app-of-apps.yaml
    
    log_info "ArgoCD applications deployed."
}

migrate_data() {
    log_info "Setting up data migration..."
    
    cat <<'EOF' > /tmp/migrate-data.sh
#!/bin/bash
# Data migration script
# This should be run carefully with proper backups

# Get source database credentials
SOURCE_DB_HOST="your-current-db-host"
SOURCE_DB_USER="root"
SOURCE_DB_PASS="your-password"

# Get target database credentials
TARGET_DB_HOST=$(kubectl get svc -n rgs-infrastructure postgresql -o jsonpath='{.spec.clusterIP}')
TARGET_DB_PASS=$(kubectl get secret -n rgs-infrastructure postgresql -o jsonpath='{.data.postgres-password}' | base64 -d)

# Dump databases
DATABASES=("office" "exchange" "history" "overlord" "pfr")

for db in "${DATABASES[@]}"; do
    echo "Migrating database: $db"
    
    # Create database in target
    kubectl run -it --rm psql-client --image=postgres:14 --restart=Never -- \
        psql -h $TARGET_DB_HOST -U postgres -c "CREATE DATABASE $db;"
    
    # Dump and restore
    pg_dump -h $SOURCE_DB_HOST -U $SOURCE_DB_USER -d $db | \
        kubectl run -it --rm psql-client --image=postgres:14 --restart=Never -- \
        psql -h $TARGET_DB_HOST -U postgres -d $db
done
EOF
    
    chmod +x /tmp/migrate-data.sh
    log_warn "Data migration script created at /tmp/migrate-data.sh"
    log_warn "Please review and run it manually after updating credentials."
}

validate_deployment() {
    log_info "Validating deployment..."
    
    # Check pods
    log_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE_INFRA
    kubectl get pods -n $NAMESPACE_CORE
    kubectl get pods -n $NAMESPACE_GAMES
    
    # Check services
    log_info "Checking services..."
    kubectl get svc -n $NAMESPACE_INFRA
    kubectl get svc -n $NAMESPACE_CORE
    kubectl get svc -n $NAMESPACE_GAMES
    
    # Check Istio
    log_info "Checking Istio configuration..."
    istioctl analyze -n $NAMESPACE_CORE
    istioctl analyze -n $NAMESPACE_GAMES
    
    # Check ArgoCD apps
    log_info "Checking ArgoCD applications..."
    kubectl get applications -n argocd
}

generate_game_manifests() {
    log_info "Generating game service manifests..."
    
    # Read game list from compose file
    games=(
        "delicious-bonanza"
        "paper-toss"
        "aviatron"
        "big-beak-guppy"
        "blackbeards-jackpot"
        "candy-crashout"
        # Add all games here
    )
    
    for game in "${games[@]}"; do
        mkdir -p "helm-charts/game-services/$game"
        
        # Generate Chart.yaml
        cat <<EOF > "helm-charts/game-services/$game/Chart.yaml"
apiVersion: v2
name: $game
description: Game service for $game
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF
        
        # Generate values.yaml
        cat <<EOF > "helm-charts/game-services/$game/values.yaml"
replicaCount: 2

server:
  image:
    repository: ${game}-server
    tag: latest
    pullPolicy: IfNotPresent

client:
  image:
    repository: ${game}-client
    tag: latest
    pullPolicy: IfNotPresent

service:
  type: ClusterIP
  serverPort: 8000
  clientPort: 80

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
EOF
        
        log_info "Generated manifests for $game"
    done
}

rollback() {
    log_warn "Rolling back deployment..."
    
    # Delete ArgoCD apps
    kubectl delete -f argocd/app-of-apps.yaml --ignore-not-found=true
    
    # Delete namespaces (this will delete all resources in them)
    kubectl delete namespace $NAMESPACE_GAMES --ignore-not-found=true
    kubectl delete namespace $NAMESPACE_CORE --ignore-not-found=true
    kubectl delete namespace $NAMESPACE_INFRA --ignore-not-found=true
    
    log_info "Rollback completed."
}

# Main execution
main() {
    echo "======================================="
    echo "RGS Platform Kubernetes Migration Tool"
    echo "======================================="
    echo
    
    PS3="Please select an option: "
    options=(
        "Full Migration"
        "Check Prerequisites"
        "Create Namespaces"
        "Create Secrets"
        "Migrate Configurations"
        "Deploy Infrastructure"
        "Setup Istio"
        "Deploy ArgoCD Apps"
        "Generate Game Manifests"
        "Migrate Data"
        "Validate Deployment"
        "Rollback"
        "Exit"
    )
    
    select opt in "${options[@]}"; do
        case $opt in
            "Full Migration")
                check_prerequisites
                create_namespaces
                create_secrets
                migrate_configs
                deploy_infrastructure
                setup_istio_configs
                deploy_argocd_apps
                generate_game_manifests
                migrate_data
                validate_deployment
                log_info "Full migration completed!"
                break
                ;;
            "Check Prerequisites")
                check_prerequisites
                ;;
            "Create Namespaces")
                create_namespaces
                ;;
            "Create Secrets")
                create_secrets
                ;;
            "Migrate Configurations")
                migrate_configs
                ;;
            "Deploy Infrastructure")
                deploy_infrastructure
                ;;
            "Setup Istio")
                setup_istio_configs
                ;;
            "Deploy ArgoCD Apps")
                deploy_argocd_apps
                ;;
            "Generate Game Manifests")
                generate_game_manifests
                ;;
            "Migrate Data")
                migrate_data
                ;;
            "Validate Deployment")
                validate_deployment
                ;;
            "Rollback")
                read -p "Are you sure you want to rollback? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    rollback
                fi
                ;;
            "Exit")
                break
                ;;
            *) echo "Invalid option $REPLY";;
        esac
    done
}

# Run main function
main
