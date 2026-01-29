#!/bin/bash
# ==============================================================================
# API Testing Script for vLLM Server
# ==============================================================================
# Tests the vLLM OpenAI-compatible API with various endpoints
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
VLLM_HOST=${VLLM_HOST:-localhost}
VLLM_PORT=${VLLM_PORT:-8000}
BASE_URL="http://${VLLM_HOST}:${VLLM_PORT}"
API_KEY=${VLLM_API_KEY:-}

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Testing vLLM API Server${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "Base URL: ${YELLOW}${BASE_URL}${NC}"
echo ""

# ------------------------------------------------------------------------------
# Test 1: Health Check
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 1: Health Check${NC}"
if curl -s -f "${BASE_URL}/health" > /dev/null; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    curl -s "${BASE_URL}/health" | jq .
else
    echo -e "${RED}✗ Health check failed${NC}"
    exit 1
fi
echo ""

# ------------------------------------------------------------------------------
# Test 2: List Models
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 2: List Models${NC}"
curl -s "${BASE_URL}/v1/models" \
    -H "Content-Type: application/json" \
    ${API_KEY:+-H "Authorization: Bearer $API_KEY"} \
    | jq .
echo ""

# ------------------------------------------------------------------------------
# Test 3: Simple Completion
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 3: Simple Completion${NC}"
curl -s "${BASE_URL}/v1/completions" \
    -H "Content-Type: application/json" \
    ${API_KEY:+-H "Authorization: Bearer $API_KEY"} \
    -d '{
        "model": "aether-x-ultimate",
        "prompt": "Once upon a time",
        "max_tokens": 50,
        "temperature": 0.7
    }' | jq .
echo ""

# ------------------------------------------------------------------------------
# Test 4: Chat Completion
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 4: Chat Completion${NC}"
curl -s "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    ${API_KEY:+-H "Authorization: Bearer $API_KEY"} \
    -d '{
        "model": "aether-x-ultimate",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "What is the capital of France?"}
        ],
        "max_tokens": 100,
        "temperature": 0.7
    }' | jq .
echo ""

# ------------------------------------------------------------------------------
# Test 5: Streaming Chat Completion
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 5: Streaming Chat Completion${NC}"
echo "Response (streaming):"
curl -s -N "${BASE_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    ${API_KEY:+-H "Authorization: Bearer $API_KEY"} \
    -d '{
        "model": "aether-x-ultimate",
        "messages": [
            {"role": "user", "content": "Count from 1 to 5."}
        ],
        "max_tokens": 50,
        "stream": true
    }'
echo ""
echo ""

# ------------------------------------------------------------------------------
# Test 6: Embeddings (if supported)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 6: Embeddings (optional)${NC}"
curl -s "${BASE_URL}/v1/embeddings" \
    -H "Content-Type: application/json" \
    ${API_KEY:+-H "Authorization: Bearer $API_KEY"} \
    -d '{
        "model": "aether-x-ultimate",
        "input": "The quick brown fox jumps over the lazy dog"
    }' 2>/dev/null | jq . || echo -e "${YELLOW}Embeddings not supported by this model${NC}"
echo ""

# ------------------------------------------------------------------------------
# Test 7: Metrics Endpoint
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Test 7: Metrics Endpoint${NC}"
if curl -s -f "http://${VLLM_HOST}:${METRICS_PORT:-8001}/metrics" > /dev/null; then
    echo -e "${GREEN}✓ Metrics endpoint accessible${NC}"
    echo "Sample metrics:"
    curl -s "http://${VLLM_HOST}:${METRICS_PORT:-8001}/metrics" | head -n 20
else
    echo -e "${YELLOW}Metrics endpoint not available${NC}"
fi
echo ""

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}   ✓ API Tests Complete${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "For more tests, see the OpenAI API documentation:"
echo "https://platform.openai.com/docs/api-reference"
echo ""
