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

