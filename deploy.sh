#!/bin/bash

# Aether-X Ultimate Deployment Script

set -e

echo "🚀 Starting Aether-X Ultimate Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="aether-x"
IMAGE_TAG="latest"

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
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
}

deploy_infrastructure() {
    log_info "Deploying infrastructure components..."
    
    # Deploy databases
    log_info "Deploying databases..."
    kubectl apply -f k8s/databases/ -n $NAMESPACE
    
    # Deploy message queue
    log_info "Deploying message queue..."
    kubectl apply -f k8s/kafka/ -n $NAMESPACE
    
    # Deploy monitoring
    log_info "Deploying monitoring stack..."
    kubectl apply -f k8s/monitoring/ -n $NAMESPACE
    
    # Wait for infrastructure to be ready
    log_info "Waiting for infrastructure to be ready..."
    kubectl wait --for=condition=available deployment --all -n $NAMESPACE --timeout=300s
}

deploy_services() {
    log_info "Building and deploying services..."
    
    # Build Docker images
    log_info "Building Docker images..."
    docker build -t aether-x/text-generation:$IMAGE_TAG services/text-generation/
    docker build -t aether-x/image-generation:$IMAGE_TAG services/image-generation/
    docker build -t aether-x/video-generation:$IMAGE_TAG services/video-generation/
    docker build -t aether-x/ai-models:$IMAGE_TAG services/ai-models/
    docker build -t aether-x/no-code-development:$IMAGE_TAG services/no-code-development/
    docker build -t aether-x/security:$IMAGE_TAG services/security/
    docker build -t aether-x/data-processing:$IMAGE_TAG services/data-processing/
    docker build -t aether-x/api-gateway:$IMAGE_TAG services/api-gateway/
    
    # Push to registry (if needed)
    # docker push aether-x/text-generation:$IMAGE_TAG
    
    # Deploy services
    log_info "Deploying microservices..."
    kubectl apply -f k8s/deployment.yaml -n $NAMESPACE
    kubectl apply -f k8s/api-gateway.yaml -n $NAMESPACE
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    kubectl wait --for=condition=available deployment --all -n $NAMESPACE --timeout=600s
}

configure_ingress() {
    log_info "Configuring ingress..."
    
    # Check if ingress controller exists
    if ! kubectl get ingressclass nginx &> /dev/null; then
        log_warn "Nginx ingress controller not found. Please install it manually."
        log_info "You can install it with: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"
    else
        kubectl apply -f k8s/ingress.yaml -n $NAMESPACE
    fi
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check pod status
    log_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    
    # Check service status
    log_info "Checking service status..."
    kubectl get services -n $NAMESPACE
    
    # Check ingress status
    log_info "Checking ingress status..."
    kubectl get ingress -n $NAMESPACE
    
    # Test API connectivity
    log_info "Testing API connectivity..."
    API_SERVICE=$(kubectl get service api-gateway-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    
    if curl -f "http://$API_SERVICE/health" &> /dev/null; then
        log_info "API Gateway is accessible at http://$API_SERVICE"
    else
        log_warn "API Gateway test failed. Please check the service status."
    fi
}

show_usage() {
    log_info "Deployment completed successfully!"
    echo ""
    echo "📋 Usage Information:"
    echo "   Namespace: $NAMESPACE"
    echo "   API Gateway: http://<INGRESS_IP>/api"
    echo "   Dashboard: http://<INGRESS_IP>/dashboard"
    echo ""
    echo "🔧 Management Commands:"
    echo "   View logs: kubectl logs -f deployment/<service-name> -n $NAMESPACE"
    echo "   Scale service: kubectl scale deployment <service-name> --replicas=<count> -n $NAMESPACE"
    echo "   Delete deployment: kubectl delete namespace $NAMESPACE"
    echo ""
    echo "📊 Monitoring:"
    echo "   Grafana: kubectl port-forward service/grafana 3001:80 -n $NAMESPACE"
    echo "   Prometheus: kubectl port-forward service/prometheus 9090:9090 -n $NAMESPACE"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    # Add cleanup logic if needed
}

# Main execution
main() {
    case "${1:-deploy}" in
        "deploy")
            check_prerequisites
            create_namespace
            deploy_infrastructure
            deploy_services
            configure_ingress
            verify_deployment
            show_usage
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            kubectl get all -n $NAMESPACE
            ;;
        *)
            echo "Usage: $0 {deploy|cleanup|status}"
            echo ""
            echo "Commands:"
            echo "  deploy    - Deploy Aether-X Ultimate"
            echo "  cleanup   - Clean up deployment"
            echo "  status    - Show deployment status"
            exit 1
            ;;
    esac
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"