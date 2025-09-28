# RGS Platform Kubernetes Migration Kit

## Overview
Complete migration toolkit for moving the RGS Gaming Platform from Docker Compose to Kubernetes with Istio service mesh and ArgoCD GitOps.

## Migration Architecture

### Target Stack
- **Kubernetes**: Container orchestration (Hetzner Cloud)
- **Istio**: Service mesh for traffic management, security, and observability
- **ArgoCD**: GitOps continuous delivery
- **Helm**: Package management for Kubernetes applications
- **Sealed Secrets**: Secure secret management in Git

## Directory Structure
```
rgs-k8s/
├── argocd/                 # ArgoCD application definitions
│   ├── apps/              # Individual app definitions
│   └── app-of-apps.yaml   # Main ArgoCD application
├── helm-charts/           # Helm charts for services
│   ├── core-services/     # Core platform services
│   ├── game-services/     # Game server charts
│   └── infrastructure/    # Infrastructure components
├── base/                  # Base Kubernetes manifests
│   ├── namespaces/
│   ├── secrets/
│   └── configmaps/
├── overlays/              # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── production/
├── istio/                 # Istio configuration
│   ├── gateways/
│   ├── virtual-services/
│   └── destination-rules/
└── scripts/               # Migration utilities
```

## Migration Phases

### Phase 1: Infrastructure Setup (Week 1)
- [ ] Create namespaces and RBAC
- [ ] Deploy infrastructure services (PostgreSQL, Redis, RabbitMQ)
- [ ] Configure Istio gateways and routing
- [ ] Set up persistent volumes
- [ ] Configure secrets management

### Phase 2: Core Services (Week 2)
- [ ] Migrate Office/Backoffice service
- [ ] Migrate Exchange service
- [ ] Migrate History service
- [ ] Migrate Launch service
- [ ] Migrate Overlord service
- [ ] Migrate PFR service
- [ ] Migrate RNG service
- [ ] Migrate Adaptor service

### Phase 3: Game Services (Week 3-4)
- [ ] Create game service template
- [ ] Migrate EJAW games (29 games)
- [ ] Migrate Proga games (31 games)
- [ ] Migrate NCS games (30 games)

### Phase 4: Traffic Cutover (Week 5)
- [ ] Blue-green deployment setup
- [ ] Traffic shadowing for testing
- [ ] Gradual traffic migration
- [ ] Rollback procedures

### Phase 5: Optimization (Week 6)
- [ ] Auto-scaling configuration
- [ ] Resource optimization
- [ ] Observability setup
- [ ] Performance tuning

## Key Improvements in K8s Architecture

### 1. High Availability
- Multi-replica deployments for all services
- Pod disruption budgets
- Anti-affinity rules for distribution
- Automatic failover with Istio

### 2. Scalability
- Horizontal Pod Autoscaler (HPA) for dynamic scaling
- Vertical Pod Autoscaler (VPA) for right-sizing
- Cluster autoscaling with Hetzner

### 3. Traffic Management (Istio)
- Advanced load balancing (least request, consistent hash)
- Circuit breakers and retry policies
- Canary deployments
- A/B testing capabilities

### 4. Observability
- Distributed tracing with Jaeger
- Metrics with Prometheus
- Logging with Fluentd/Loki
- Service mesh visualization with Kiali

### 5. Security
- mTLS between all services
- Network policies
- Pod security policies
- Secret encryption at rest

## Prerequisites

### Required Tools
```bash
# Install required CLI tools
kubectl version --client
helm version
istioctl version
argocd version
kubeseal --version
```

### Cluster Requirements
- Kubernetes 1.27+
- Istio 1.19+
- ArgoCD 2.8+
- Minimum 3 worker nodes (8 vCPU, 32GB RAM each)

## Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/your-org/rgs-k8s.git
cd rgs-k8s
```

### 2. Configure ArgoCD
```bash
kubectl apply -f argocd/app-of-apps.yaml
```

### 3. Deploy Infrastructure
```bash
./scripts/deploy-infrastructure.sh
```

### 4. Deploy Core Services
```bash
./scripts/deploy-core-services.sh
```

### 5. Deploy Game Services
```bash
./scripts/deploy-games.sh
```

## Migration Checklist

### Pre-Migration
- [ ] Backup all databases
- [ ] Document current configurations
- [ ] Create rollback plan
- [ ] Set up monitoring dashboards
- [ ] Test disaster recovery

### During Migration
- [ ] Deploy in staging first
- [ ] Run parallel environments
- [ ] Perform load testing
- [ ] Validate data integrity
- [ ] Monitor error rates

### Post-Migration
- [ ] Decommission old infrastructure
- [ ] Update documentation
- [ ] Train operations team
- [ ] Optimize costs
- [ ] Schedule post-mortem

## Risk Mitigation

### Data Migration
- Use database replication for zero-downtime migration
- Implement data validation checks
- Keep backups of original data

### Service Dependencies
- Map all service dependencies
- Migrate in dependency order
- Use service virtualization for testing

### Rollback Strategy
- Keep Docker Compose environment running
- Use Istio traffic splitting for gradual migration
- Maintain database replication until stable

## Support

For questions or issues during migration:
- Documentation: [Internal Wiki]
- Slack: #rgs-migration
- Email: platform-team@company.com
