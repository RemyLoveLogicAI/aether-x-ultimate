#!/bin/bash
# ==============================================================================
# GPU Runtime Script for vLLM-Powered Aether-X-Ultimate
# ==============================================================================
# This script provides easy GPU-accelerated deployment with validation
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$(dirname "$DOCKER_DIR")")"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   vLLM GPU Runtime for Aether-X-Ultimate${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# Check Prerequisites
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓ Docker found: $(docker --version)${NC}"

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose found: $(docker-compose --version)${NC}"

# Check NVIDIA Docker Runtime
if ! docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: NVIDIA Docker runtime is not properly configured${NC}"
    echo "Please install nvidia-docker2: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
    exit 1
fi
echo -e "${GREEN}✓ NVIDIA Docker runtime configured${NC}"

# Check GPU availability
if ! nvidia-smi &> /dev/null; then
    echo -e "${RED}Error: No NVIDIA GPU detected${NC}"
    echo "Please ensure:"
    echo "  1. You have an NVIDIA GPU installed"
    echo "  2. NVIDIA drivers are installed"
    echo "  3. nvidia-smi command works"
    exit 1
fi
echo -e "${GREEN}✓ GPU detected:${NC}"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | head -n 1

# ------------------------------------------------------------------------------
# Environment Setup
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/6] Setting up environment...${NC}"

cd "$DOCKER_DIR"

# Check for .env file
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env file${NC}"
        echo -e "${YELLOW}⚠ Please edit .env to configure your deployment${NC}"
    else
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Found .env file${NC}"
fi

# Load environment variables
source .env

# ------------------------------------------------------------------------------
# Create Required Directories
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/6] Creating required directories...${NC}"

mkdir -p "${MODEL_CACHE_DIR:-./models}"
mkdir -p "${LOGS_DIR:-./logs}"
mkdir -p "${CONFIG_DIR:-./config}"

echo -e "${GREEN}✓ Directories created${NC}"
echo "  - Models: ${MODEL_CACHE_DIR:-./models}"
echo "  - Logs: ${LOGS_DIR:-./logs}"
echo "  - Config: ${CONFIG_DIR:-./config}"

# ------------------------------------------------------------------------------
# Pull Latest vLLM Image
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/6] Pulling vLLM Docker image...${NC}"

VLLM_IMAGE="vllm/vllm-openai:${VLLM_VERSION:-v0.11.0}"
echo "Image: $VLLM_IMAGE"

if docker pull "$VLLM_IMAGE"; then
    echo -e "${GREEN}✓ Image pulled successfully${NC}"
else
    echo -e "${RED}Error: Failed to pull vLLM image${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Validate Configuration
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/6] Validating configuration...${NC}"

echo "GPU Configuration:"
echo "  - GPU Count: ${GPU_COUNT:-1}"
echo "  - CUDA Devices: ${CUDA_VISIBLE_DEVICES:-0}"
echo "  - Memory Utilization: ${GPU_MEMORY_UTILIZATION:-0.9}"
echo ""
echo "Model Configuration:"
echo "  - Model: ${MODEL_NAME:-meta-llama/Llama-3.1-8B-Instruct}"
echo "  - Served Name: ${SERVED_MODEL_NAME:-aether-x-ultimate}"
echo "  - Max Length: ${MAX_MODEL_LEN:-4096}"
echo ""
echo "Port Configuration:"
echo "  - vLLM API: ${VLLM_PORT:-8000}"
echo "  - Metrics: ${METRICS_PORT:-8001}"
echo "  - App Server: ${APP_PORT:-8080}"

# ------------------------------------------------------------------------------
# Start Services
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/6] Starting services...${NC}"

echo -e "${BLUE}Starting Docker Compose...${NC}"
if docker-compose -f docker-compose.yml up -d; then
    echo -e "${GREEN}✓ Services started successfully${NC}"
else
    echo -e "${RED}Error: Failed to start services${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Wait for Health Check
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}Waiting for services to be healthy...${NC}"
echo "This may take a minute while the model loads..."

MAX_WAIT=300  # 5 minutes
WAIT_TIME=0
SLEEP_INTERVAL=5

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if curl -s http://localhost:${VLLM_PORT:-8000}/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ vLLM server is healthy!${NC}"
        break
    fi
    echo -n "."
    sleep $SLEEP_INTERVAL
    WAIT_TIME=$((WAIT_TIME + SLEEP_INTERVAL))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo -e "\n${RED}Error: Service did not become healthy within ${MAX_WAIT}s${NC}"
    echo "Check logs with: docker-compose logs vllm-server"
    exit 1
fi

# ------------------------------------------------------------------------------
# Success Message
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}   🎉 vLLM Server is Running Successfully!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "API Endpoints:"
echo -e "  - OpenAI API: ${BLUE}http://localhost:${VLLM_PORT:-8000}/v1${NC}"
echo -e "  - Health Check: ${BLUE}http://localhost:${VLLM_PORT:-8000}/health${NC}"
echo -e "  - Metrics: ${BLUE}http://localhost:${METRICS_PORT:-8001}/metrics${NC}"
echo ""
echo "Quick Commands:"
echo -e "  - View logs: ${BLUE}docker-compose logs -f vllm-server${NC}"
echo -e "  - Stop services: ${BLUE}docker-compose down${NC}"
echo -e "  - Restart: ${BLUE}docker-compose restart${NC}"
echo ""
echo "Test the API:"
echo -e "${BLUE}curl http://localhost:${VLLM_PORT:-8000}/v1/models${NC}"
echo ""
echo -e "${GREEN}Happy inferencing! 🚀${NC}"
echo ""
