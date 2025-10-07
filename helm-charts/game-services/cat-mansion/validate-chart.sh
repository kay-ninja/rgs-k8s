#!/bin/bash
# Cat-Mansion Helm Chart Validation Script

set -e

CHART_DIR="./cat-mansion"
NAMESPACE="rgs-games"

echo "================================"
echo "Cat-Mansion Chart Validation"
echo "================================"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is not installed"
    exit 1
fi
echo "✅ Helm is installed"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi
echo "✅ kubectl is installed"

# Check if chart directory exists
if [ ! -d "$CHART_DIR" ]; then
    echo "❌ Chart directory not found: $CHART_DIR"
    exit 1
fi
echo "✅ Chart directory found"

# Lint the chart
echo ""
echo "Running helm lint..."
if helm lint "$CHART_DIR"; then
    echo "✅ Chart passed linting"
else
    echo "❌ Chart failed linting"
    exit 1
fi

# Dry run
echo ""
echo "Running dry-run installation..."
if helm install cat-mansion-test "$CHART_DIR" -n "$NAMESPACE" --dry-run > /dev/null 2>&1; then
    echo "✅ Dry-run successful"
else
    echo "❌ Dry-run failed"
    exit 1
fi

# Check namespace exists
echo ""
echo "Checking namespace..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "✅ Namespace $NAMESPACE exists"
else
    echo "⚠️  Namespace $NAMESPACE does not exist"
    echo "   Create it with: kubectl create namespace $NAMESPACE"
fi

# Check registry secret
echo ""
echo "Checking registry credentials..."
if kubectl get secret docker-registry-credentials -n "$NAMESPACE" &> /dev/null; then
    echo "✅ Registry secret exists"
else
    echo "⚠️  Registry secret not found"
    echo "   Create it with:"
    echo "   kubectl create secret docker-registry docker-registry-credentials \\"
    echo "     --docker-server=registry.ejaw.net \\"
    echo "     --docker-username=<username> \\"
    echo "     --docker-password=<password> \\"
    echo "     -n $NAMESPACE"
fi

# Render templates
echo ""
echo "Rendering templates..."
if helm template cat-mansion "$CHART_DIR" > /tmp/cat-mansion-rendered.yaml 2>&1; then
    echo "✅ Templates rendered successfully"
    echo "   Output saved to: /tmp/cat-mansion-rendered.yaml"
else
    echo "❌ Template rendering failed"
    exit 1
fi

# Check template files
echo ""
echo "Checking template files..."
REQUIRED_TEMPLATES=(
    "templates/configmap.yaml"
    "templates/deployment-server.yaml"
    "templates/deployment-client.yaml"
    "templates/service-server.yaml"
    "templates/service-client.yaml"
    "templates/virtualservice.yaml"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
    if [ -f "$CHART_DIR/$template" ]; then
        echo "✅ $template"
    else
        echo "❌ $template - MISSING"
    fi
done

echo ""
echo "================================"
echo "⚠️  CRITICAL: PORT VERIFICATION"
echo "================================"
echo ""
echo "Before deploying, verify the client port:"
echo ""
echo "docker run --rm registry.ejaw.net/rgs/frontend/slots/ninjagaming/cat-mansion:1.0.109 \\"
echo "  sh -c \"sleep 5 && ss -tulpn | grep nginx\""
echo ""
echo "If nginx listens on port 8089 (not 80), update values.yaml:"
echo "  client.port: 8089"
echo ""
echo "================================"
echo "Validation Complete!"
echo "================================"
