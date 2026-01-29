#!/bin/bash
# ==============================================================================
# Cleanup Script for vLLM Docker Setup
# ==============================================================================
# Removes containers, volumes, and cached data
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$DOCKER_DIR"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   vLLM Docker Cleanup${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Parse arguments
REMOVE_VOLUMES=false
REMOVE_IMAGES=false
REMOVE_MODELS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --volumes)
      REMOVE_VOLUMES=true
      shift
      ;;
    --images)
      REMOVE_IMAGES=true
      shift
      ;;
    --models)
      REMOVE_MODELS=true
      shift
      ;;
    --all)
      REMOVE_VOLUMES=true
      REMOVE_IMAGES=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --volumes    Remove Docker volumes (Hugging Face cache)"
      echo "  --images     Remove Docker images"
      echo "  --models     Remove downloaded models"
      echo "  --all        Remove everything except models"
      echo "  --help       Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                # Stop containers only"
      echo "  $0 --volumes      # Stop containers and remove volumes"
      echo "  $0 --all          # Full cleanup except models"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Confirm if removing data
if [ "$REMOVE_VOLUMES" = true ] || [ "$REMOVE_IMAGES" = true ] || [ "$REMOVE_MODELS" = true ]; then
  echo -e "${YELLOW}WARNING: This will remove:${NC}"
  [ "$REMOVE_VOLUMES" = true ] && echo "  - Docker volumes (Hugging Face cache)"
  [ "$REMOVE_IMAGES" = true ] && echo "  - Docker images"
  [ "$REMOVE_MODELS" = true ] && echo "  - Downloaded models"
  echo ""
  read -p "Are you sure? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 0
  fi
fi

# Stop and remove containers
echo -e "${YELLOW}[1/5] Stopping containers...${NC}"
if docker-compose down; then
  echo -e "${GREEN}✓ Containers stopped${NC}"
else
  echo -e "${RED}Failed to stop containers${NC}"
  exit 1
fi

# Remove volumes if requested
if [ "$REMOVE_VOLUMES" = true ]; then
  echo -e "\n${YELLOW}[2/5] Removing volumes...${NC}"
  docker-compose down -v
  echo -e "${GREEN}✓ Volumes removed${NC}"
else
  echo -e "\n${YELLOW}[2/5] Skipping volume removal${NC}"
fi

# Remove images if requested
if [ "$REMOVE_IMAGES" = true ]; then
  echo -e "\n${YELLOW}[3/5] Removing images...${NC}"
  
  # Remove vLLM images
  docker images | grep vllm | awk '{print $3}' | xargs -r docker rmi -f || true
  
  # Remove custom images
  docker images | grep aether | awk '{print $3}' | xargs -r docker rmi -f || true
  
  echo -e "${GREEN}✓ Images removed${NC}"
else
  echo -e "\n${YELLOW}[3/5] Skipping image removal${NC}"
fi

# Remove downloaded models if requested
if [ "$REMOVE_MODELS" = true ]; then
  echo -e "\n${YELLOW}[4/5] Removing downloaded models...${NC}"
  
  if [ -d "./models" ]; then
    rm -rf ./models/*
    echo -e "${GREEN}✓ Models removed${NC}"
  else
    echo -e "${YELLOW}No models directory found${NC}"
  fi
else
  echo -e "\n${YELLOW}[4/5] Keeping downloaded models${NC}"
fi

# Clean up logs
echo -e "\n${YELLOW}[5/5] Cleaning logs...${NC}"
if [ -d "./logs" ]; then
  rm -rf ./logs/*.log ./logs/*.txt
  echo -e "${GREEN}✓ Logs cleaned${NC}"
else
  echo -e "${YELLOW}No logs directory found${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}   ✓ Cleanup Complete${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""

# Show remaining resources
echo "Remaining resources:"
echo ""
echo "Docker containers:"
docker ps -a --filter "name=aether" --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" || echo "  None"
echo ""
echo "Docker volumes:"
docker volume ls --filter "name=vllm" --format "table {{.Name}}\t{{.Size}}" || echo "  None"
echo ""
echo "Disk usage:"
du -sh ./models 2>/dev/null || echo "  Models: 0 bytes"
du -sh ./logs 2>/dev/null || echo "  Logs: 0 bytes"
du -sh ~/.cache/huggingface 2>/dev/null || echo "  HF Cache: 0 bytes"
echo ""

echo -e "${BLUE}To fully reset:${NC}"
echo -e "  ${YELLOW}$0 --all --models${NC}"
echo ""
