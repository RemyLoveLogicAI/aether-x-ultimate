#!/bin/bash
# ==============================================================================
# Benchmark Script for vLLM Server
# ==============================================================================
# Tests throughput and latency with various configurations
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
echo -e "${BLUE}   vLLM Performance Benchmark${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo -e "Base URL: ${YELLOW}${BASE_URL}${NC}"
echo ""

# Check if server is running
if ! curl -s -f "${BASE_URL}/health" > /dev/null; then
  echo -e "${RED}Error: vLLM server is not responding${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Server is healthy${NC}"
echo ""

# Install dependencies if needed
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}Installing jq for JSON parsing...${NC}"
  sudo apt-get update && sudo apt-get install -y jq
fi

# SECURITY FIX: Ensure 'bc' is installed for math calculations
if ! command -v bc &> /dev/null; then
  echo -e "${YELLOW}Installing bc for calculations...${NC}"
  sudo apt-get update && sudo apt-get install -y bc
fi

# Benchmark function
run_benchmark() {
  local test_name=$1
  local prompt=$2
  local max_tokens=$3
  local n_requests=${4:-10}
  
  echo -e "\n${YELLOW}=== $test_name ===${NC}"
  echo "Configuration:"
  echo "  - Requests: $n_requests"
  echo "  - Max Tokens: $max_tokens"
  echo "  - Prompt Length: ${#prompt} chars"
  echo ""
  
  local total_time=0
  local total_tokens=0
  local successful=0
  
  for i in $(seq 1 $n_requests); do
    start=$(date +%s.%N)
    
    response=$(curl -s "${BASE_URL}/v1/completions" \
      -H "Content-Type: application/json" \
      ${API_KEY:+-H "Authorization: Bearer $API_KEY"} \
      -d "{
        \"model\": \"aether-x-ultimate\",
        \"prompt\": \"$prompt\",
        \"max_tokens\": $max_tokens,
        \"temperature\": 0.7
      }")
    
    end=$(date +%s.%N)
    duration=$(echo "$end - $start" | bc)
    
    # Extract tokens from response
    tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
    
    if [ "$tokens" -gt 0 ]; then
      total_time=$(echo "$total_time + $duration" | bc)
      total_tokens=$(echo "$total_tokens + $tokens" | bc)
      successful=$((successful + 1))
      echo -n "."
    else
      echo -n "x"
    fi
  done
  
  echo ""
  echo ""
  echo "Results:"
  echo "  - Successful: $successful/$n_requests"
  
  if [ "$successful" -gt 0 ]; then
    avg_latency=$(echo "scale=3; $total_time / $successful" | bc)
    avg_tokens=$(echo "scale=0; $total_tokens / $successful" | bc)
    tokens_per_sec=$(echo "scale=2; $total_tokens / $total_time" | bc)
    
    echo -e "  - Avg Latency: ${GREEN}${avg_latency}s${NC}"
    echo -e "  - Avg Tokens: ${GREEN}${avg_tokens}${NC}"
    echo -e "  - Throughput: ${GREEN}${tokens_per_sec} tokens/sec${NC}"
  fi
}

# Run benchmarks
echo -e "${BLUE}Starting benchmarks...${NC}"
echo "This will take a few minutes."

# Test 1: Short prompts, short completions
run_benchmark \
  "Short Prompt + Short Completion" \
  "Hello, how are you?" \
  50 \
  10

# Test 2: Medium prompts, medium completions
run_benchmark \
  "Medium Prompt + Medium Completion" \
  "Write a detailed explanation of how transformers work in deep learning, covering attention mechanisms and positional encodings." \
  200 \
  10

# Test 3: Long prompts, long completions
run_benchmark \
  "Long Prompt + Long Completion" \
  "$(cat << 'EOF'
You are an expert software architect. Design a complete microservices architecture 
for an e-commerce platform. Include details about service boundaries, communication 
patterns, data storage strategies, API design, security considerations, and scalability 
approaches. Be thorough and specific.
EOF
)" \
  500 \
  5

# Test 4: Concurrent requests (if gnu parallel is available)
if command -v parallel &> /dev/null; then
  echo -e "\n${YELLOW}=== Concurrent Requests Test ===${NC}"
  echo "Running 20 concurrent requests..."
  
  start=$(date +%s.%N)
  
  seq 1 20 | parallel -j 20 "curl -s '${BASE_URL}/v1/completions' \
    -H 'Content-Type: application/json' \
    ${API_KEY:+-H 'Authorization: Bearer $API_KEY'} \
    -d '{
      \"model\": \"aether-x-ultimate\",
      \"prompt\": \"Count to 10\",
      \"max_tokens\": 50
    }' > /dev/null"
  
  end=$(date +%s.%N)
  duration=$(echo "$end - $start" | bc)
  
  echo ""
  echo "Results:"
  echo -e "  - Total Time: ${GREEN}${duration}s${NC}"
  echo -e "  - Requests/sec: ${GREEN}$(echo "scale=2; 20 / $duration" | bc)${NC}"
fi

# Get server metrics
echo -e "\n${YELLOW}=== Server Metrics ===${NC}"
metrics=$(curl -s "http://${VLLM_HOST}:${METRICS_PORT:-8001}/metrics")

echo "Key Metrics:"
echo "$metrics" | grep "vllm:num_requests" | head -n 5
echo "$metrics" | grep "vllm:gpu_cache_usage" | head -n 2
echo "$metrics" | grep "vllm:time_to_first_token" | head -n 2
echo "$metrics" | grep "vllm:time_per_output_token" | head -n 2

# Summary
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}   Benchmark Complete${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "Full metrics available at: http://${VLLM_HOST}:${METRICS_PORT:-8001}/metrics"
echo ""
