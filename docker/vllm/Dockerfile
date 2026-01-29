# ==============================================================================
# vLLM-Powered Docker Setup for Aether-X-Ultimate
# ==============================================================================
# This Dockerfile uses the official vLLM OpenAI-compatible API server image
# to eliminate torch dependency conflicts and CUDA version mismatches.
#
# Official vLLM images include:
# - Pre-compiled torch with correct CUDA versions
# - Optimized kernels (FlashAttention, PagedAttention)
# - All necessary CUDA libraries
# - Production-ready configuration
# ==============================================================================

# ==============================================================================
# Stage 1: Base vLLM Image
# ==============================================================================
ARG VLLM_VERSION=v0.11.0
FROM vllm/vllm-openai:${VLLM_VERSION} AS vllm-base

# Image metadata
LABEL maintainer="Jeremy Morgan-Jones SR <remy@lovelogicai.com>"
LABEL description="Aether-X-Ultimate with vLLM - Production-Ready LLM Inference"
LABEL version="1.0.0"

# Set environment variables for CUDA and Python
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

# ==============================================================================
# Stage 2: Application Layer
# ==============================================================================
FROM vllm-base AS app-builder

# Install additional system dependencies if needed
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    vim \
    tmux \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /workspace/aether-x-ultimate

# Copy application code
COPY services/ ./services/
COPY infrastructure/ ./infrastructure/
COPY docs/ ./docs/
COPY *.sh ./
COPY *.md ./

# Install application-specific Python dependencies
# (vLLM and torch are already installed in the base image)
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary directories
RUN mkdir -p /workspace/models /workspace/logs /workspace/cache

# Set proper permissions
RUN chmod +x *.sh

# ==============================================================================
# Stage 3: Production Image
# ==============================================================================
FROM app-builder AS production

# Configure vLLM environment variables
ENV VLLM_WORKER_MULTIPROC_METHOD=spawn \
    VLLM_ATTENTION_BACKEND=FLASHINFER \
    VLLM_USE_MODELSCOPE=False \
    VLLM_USAGE_SOURCE=production \
    VLLM_NCCL_SO_PATH=/usr/local/lib/libnccl.so \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0" \
    MAX_JOBS=4

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose ports
# 8000: vLLM OpenAI API server
# 8001: vLLM metrics endpoint
EXPOSE 8000 8001

# Set working directory
WORKDIR /workspace/aether-x-ultimate

# Default command: Start vLLM OpenAI API server
CMD ["python", "-m", "vllm.entrypoints.openai.api_server", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--model", "/workspace/models/default", \
     "--served-model-name", "aether-x-ultimate", \
     "--max-model-len", "4096", \
     "--gpu-memory-utilization", "0.9", \
     "--trust-remote-code"]

# ==============================================================================
# Build Instructions:
# ==============================================================================
# Build with default version (v0.11.0):
#   docker build -t aether-x-ultimate:vllm -f docker/vllm/Dockerfile .
#
# Build with latest vLLM:
#   docker build --build-arg VLLM_VERSION=latest -t aether-x-ultimate:vllm-latest -f docker/vllm/Dockerfile .
#
# Build with specific CUDA version:
#   docker build --build-arg VLLM_VERSION=v0.11.0 -t aether-x-ultimate:vllm-cu121 -f docker/vllm/Dockerfile .
# ==============================================================================