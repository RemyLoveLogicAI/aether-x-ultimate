#!/bin/bash

# Aether-X Ultimate Testing Suite

set -e

echo "🧪 Running Aether-X Ultimate Test Suite..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TEST_TIMEOUT=30
SERVICES=(
    "text-generation:8000"
    "image-generation:8001"
    "video-generation:8002"
    "ai-models:8003"
    "no-code-development:8004"
    "security:8005"
    "data-processing:8006"
)

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

check_service_health() {
    local service_name=$1
    local port=$2
    local url="http://localhost:$port/health"
    
    log_info "Testing $service_name health check..."
    
    if curl -f -s --max-time $TEST_TIMEOUT "$url" > /dev/null; then
        log_info "✅ $service_name is healthy"
        return 0
    else
        log_error "❌ $service_name failed health check"
        return 1
    fi
}

test_text_generation() {
    log_info "Testing text generation service..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"prompt": "Hello, this is a test.", "language": "en"}' \
        http://localhost:8000/generate)
    
    if echo "$response" | grep -q "generated_text"; then
        log_info "✅ Text generation test passed"
        return 0
    else
        log_error "❌ Text generation test failed"
        echo "Response: $response"
        return 1
    fi
}

test_image_generation() {
    log_info "Testing image generation service..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"prompt": "a beautiful landscape"}' \
        http://localhost:8001/generate)
    
    if echo "$response" | grep -q "image_base64"; then
        log_info "✅ Image generation test passed"
        return 0
    else
        log_error "❌ Image generation test failed"
        echo "Response: $response"
        return 1
    fi
}

test_security_features() {
    log_info "Testing security service..."
    
    # Test user registration
    local register_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"username": "testuser", "password": "testpass123", "email": "test@example.com"}' \
        http://localhost:8005/register)
    
    if echo "$register_response" | grep -q "User registered successfully"; then
        log_info "✅ User registration test passed"
    else
        log_error "❌ User registration test failed"
        echo "Response: $register_response"
        return 1
    fi
    
    # Test user login
    local login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"username": "testuser", "password": "testpass123"}' \
        http://localhost:8005/login)
    
    if echo "$login_response" | grep -q "token"; then
        log_info "✅ User login test passed"
        
        # Extract token
        local token=$(echo "$login_response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        
        # Test protected endpoint
        local protected_response=$(curl -s -H "Authorization: Bearer $token" \
            http://localhost:8005/security-logs)
        
        if echo "$protected_response" | grep -q "security_logs"; then
            log_info "✅ Protected endpoint test passed"
        else
            log_error "❌ Protected endpoint test failed"
            echo "Response: $protected_response"
            return 1
        fi
    else
        log_error "❌ User login test failed"
        echo "Response: $login_response"
        return 1
    fi
    
    return 0
}

test_data_processing() {
    log_info "Testing data processing service..."
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"type": "test", "data": {"test": "data"}}' \
        http://localhost:8006/ingest)
    
    if echo "$response" | grep -q "message_id"; then
        log_info "✅ Data ingestion test passed"
        return 0
    else
        log_error "❌ Data ingestion test failed"
        echo "Response: $response"
        return 1
    fi
}

test_api_gateway() {
    log_info "Testing API gateway..."
    
    # Test health check
    local health_response=$(curl -s http://localhost/health)
    if echo "$health_response" | grep -q "healthy"; then
        log_info "✅ API gateway health check passed"
    else
        log_error "❌ API gateway health check failed"
        echo "Response: $health_response"
        return 1
    fi
    
    # Test service proxy
    local proxy_response=$(curl -s http://localhost/api/text-generation/health)
    if echo "$proxy_response" | grep -q "healthy"; then
        log_info "✅ Service proxy test passed"
        return 0
    else
        log_error "❌ Service proxy test failed"
        echo "Response: $proxy_response"
        return 1
    fi
}

run_integration_tests() {
    log_info "Running integration tests..."
    
    local failed_tests=0
    local total_tests=0
    
    # Test each service
    for service in "${SERVICES[@]}"; do
        total_tests=$((total_tests + 1))
        if ! check_service_health $service; then
            failed_tests=$((failed_tests + 1))
        fi
    done
    
    # Test specific functionality
    total_tests=$((total_tests + 1))
    if ! test_text_generation; then
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if ! test_image_generation; then
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if ! test_security_features; then
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if ! test_data_processing; then
        failed_tests=$((failed_tests + 1))
    fi
    
    total_tests=$((total_tests + 1))
    if ! test_api_gateway; then
        failed_tests=$((failed_tests + 1))
    fi
    
    # Report results
    log_info "Integration tests completed"
    log_info "Total tests: $total_tests"
    log_info "Failed tests: $failed_tests"
    log_info "Passed tests: $((total_tests - failed_tests))"
    
    if [ $failed_tests -eq 0 ]; then
        log_info "🎉 All integration tests passed!"
        return 0
    else
        log_error "❌ Some integration tests failed"
        return 1
    fi
}

run_load_tests() {
    log_info "Running load tests..."
    
    # Simple load test for API gateway
    local start_time=$(date +%s)
    local requests=100
    local success_count=0
    
    log_info "Sending $requests requests to API gateway..."
    
    for i in $(seq 1 $requests); do
        if curl -f -s --max-time 5 http://localhost/health > /dev/null; then
            success_count=$((success_count + 1))
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local rate=$((requests / duration))
    
    log_info "Load test results:"
    log_info "  Requests: $requests"
    log_info "  Success: $success_count"
    log_info "  Duration: ${duration}s"
    log_info "  Rate: ${rate} req/s"
    
    if [ $success_count -eq $requests ]; then
        log_info "✅ Load test passed"
        return 0
    else
        log_error "❌ Load test failed"
        return 1
    fi
}

show_test_summary() {
    log_info "Test suite completed!"
    echo ""
    echo "📊 Test Summary:"
    echo "   - Service health checks"
    echo "   - Text generation functionality"
    echo "   - Image generation functionality"
    echo "   - Security features (auth, encryption)"
    echo "   - Data processing pipeline"
    echo "   - API gateway proxy functionality"
    echo "   - Load testing"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   - Check service logs: docker-compose logs <service>"
    echo "   - Verify service status: docker-compose ps"
    echo "   - Restart services: docker-compose restart"
}

# Main execution
main() {
    case "${1:-all}" in
        "health")
            log_info "Running health checks only..."
            for service in "${SERVICES[@]}"; do
                check_service_health $service
            done
            ;;
        "integration")
            run_integration_tests
            ;;
        "load")
            run_load_tests
            ;;
        "all"|"")
            log_info "Running full test suite..."
            run_integration_tests
            run_load_tests
            ;;
        *)
            echo "Usage: $0 {health|integration|load|all}"
            echo ""
            echo "Commands:"
            echo "  health      - Run service health checks only"
            echo "  integration - Run integration tests"
            echo "  load        - Run load tests"
            echo "  all         - Run all tests (default)"
            exit 1
            ;;
    esac
    
    show_test_summary
}

# Run main function
main "$@"