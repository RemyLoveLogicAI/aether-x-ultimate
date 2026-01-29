# vLLM-Powered Docker Setup for Aether-X-Ultimate

## 🎯 Overview

This directory contains a **production-ready Docker setup** that uses official vLLM images to eliminate torch dependency conflicts and CUDA version mismatches. Instead of managing PyTorch and CUDA dependencies manually, we leverage vLLM's pre-built, optimized Docker images.

## 🔥 Why This Approach?

### Problems Solved

1. **Torch Dependency Conflicts** ❌ → ✅
   - **Before**: Managing `torch==1.13.1` vs `torch==2.9.1` conflicts
   - **After**: Using vLLM's pre-compiled torch (2.9.1) with correct CUDA bindings

2. **CUDA Version Mismatches** ❌ → ✅
   - **Before**: CUDA 11.x vs 12.x compatibility issues
   - **After**: vLLM images ship with CUDA 12.9.1 and all necessary libraries

3. **Build Complexity** ❌ → ✅
   - **Before**: Compiling PyTorch extensions, managing nvcc, cmake, etc.
   - **After**: Pre-compiled binaries, instant deployment

4. **Reproducibility** ❌ → ✅
   - **Before**: "Works on my machine" syndrome
   - **After**: Identical environment across dev, staging, production

### Key Benefits

✅ **Zero Build Time** - No compilation of C++/CUDA extensions
✅ **Optimized Performance** - FlashAttention, PagedAttention pre-configured
✅ **Production Ready** - Used by thousands of companies in production
✅ **OpenAI Compatible** - Drop-in replacement for OpenAI API
✅ **Multi-GPU Support** - Built-in tensor parallelism and pipeline parallelism
✅ **Easy Scaling** - Docker Compose orchestration included

## 📋 Prerequisites

### Required

- **Docker** >= 20.10
- **Docker Compose** >= 2.0
- **NVIDIA GPU** with Compute Capability >= 7.0 (Volta+)
- **NVIDIA Driver** >= 530.x (for CUDA 12.x)
- **nvidia-docker2** (NVIDIA Container Toolkit)

### Recommended

- **GPU Memory**: >= 16GB for 7B models, >= 24GB for 13B models
- **System RAM**: >= 32GB
- **Disk Space**: >= 50GB for models and cache

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Navigate to vLLM docker directory
cd docker/vllm

# Copy environment template
cp .env.example .env

# Edit configuration
vim .env  # or your preferred editor
```

### 2. Configure Your Model

Edit `.env` to specify your model:

```bash
# Example: Llama 3.1 8B
MODEL_NAME=meta-llama/Llama-3.1-8B-Instruct
SERVED_MODEL_NAME=aether-x-ultimate
MAX_MODEL_LEN=4096
GPU_MEMORY_UTILIZATION=0.9
```

### 3. Start Services

```bash
# Option A: Using the helper script (recommended)
chmod +x scripts/run-gpu.sh
./scripts/run-gpu.sh

# Option B: Using docker-compose directly
docker-compose up -d
```

### 4. Verify Deployment

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f vllm-server

# Test API
chmod +x scripts/test-api.sh
./scripts/test-api.sh
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Aether-X-Ultimate                        │
│                    (Your Application)                       │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP/REST
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              vLLM OpenAI API Server                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  • OpenAI-Compatible Endpoints (/v1/chat/completions)│  │
│  │  • Async Request Handling                            │  │
│  │  • Token Streaming                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  vLLM Engine Core                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  • PagedAttention (Memory Management)                │  │
│  │  • Continuous Batching                               │  │
│  │  • FlashAttention-2/FlashInfer                      │  │
│  │  • Tensor Parallelism                                │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              PyTorch + CUDA Runtime                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  • torch 2.9.1 (pre-compiled)                        │  │
│  │  • CUDA 12.9.1 libraries                             │  │
│  │  • cuDNN, NCCL optimized                             │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  NVIDIA GPU(s)                              │
│              (Managed by nvidia-docker)                     │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
docker/vllm/
├── Dockerfile                 # Multi-stage production build
├── docker-compose.yml         # Service orchestration
├── .env.example              # Configuration template
├── README.md                 # This file
├── config/                   # Configuration files
│   ├── prometheus.yml        # Monitoring config
│   └── grafana/              # Grafana dashboards
├── scripts/
│   ├── run-gpu.sh           # GPU deployment script
│   ├── test-api.sh          # API testing script
│   ├── benchmark.sh         # Performance benchmarking
│   └── cleanup.sh           # Cleanup script
└── docs/
    ├── ARCHITECTURE.md       # Detailed architecture
    ├── TROUBLESHOOTING.md   # Common issues
    └── PERFORMANCE.md        # Optimization guide
```

## 🔧 Configuration

### Environment Variables

Key configuration options in `.env`:

#### Model Settings
```bash
MODEL_NAME=meta-llama/Llama-3.1-8B-Instruct
SERVED_MODEL_NAME=aether-x-ultimate
MAX_MODEL_LEN=4096
GPU_MEMORY_UTILIZATION=0.9
```

#### GPU Settings
```bash
GPU_COUNT=1
CUDA_VISIBLE_DEVICES=0
TENSOR_PARALLEL_SIZE=1
```

#### Performance Settings
```bash
ATTENTION_BACKEND=FLASHINFER  # or FLASH_ATTN, XFORMERS
ENABLE_PREFIX_CACHING=true
MAX_NUM_SEQS=256
```

### Supported Models

vLLM supports a wide range of models:

- **Llama 3.x** (8B, 70B, 405B)
- **Mistral/Mixtral** (7B, 8x7B, 8x22B)
- **Qwen 2.x** (7B, 72B)
- **Phi-3** (3.8B, 14B)
- **Command-R** (35B, 104B)
- **And many more...**

See [vLLM model support](https://docs.vllm.ai/en/latest/models/supported_models.html)

## 🎮 Usage Examples

### Python Client

```python
from openai import OpenAI

# Point to local vLLM server
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy"  # Not required unless you set VLLM_API_KEY
)

# Chat completion
response = client.chat.completions.create(
    model="aether-x-ultimate",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    max_tokens=500,
    temperature=0.7
)

print(response.choices[0].message.content)
```

### cURL

```bash
# Chat completion
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "aether-x-ultimate",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'

# Streaming
curl -N http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "aether-x-ultimate",
    "messages": [{"role": "user", "content": "Count to 10"}],
    "stream": true
  }'
```

### JavaScript/TypeScript

```typescript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://localhost:8000/v1',
  apiKey: 'dummy'
});

const response = await client.chat.completions.create({
  model: 'aether-x-ultimate',
  messages: [{ role: 'user', content: 'Hello!' }],
});

console.log(response.choices[0].message.content);
```

## 🔬 Advanced Usage

### Multi-GPU Deployment

```bash
# In .env
GPU_COUNT=4
TENSOR_PARALLEL_SIZE=4
CUDA_VISIBLE_DEVICES=0,1,2,3

# Start services
docker-compose up -d
```

### Quantization (Reduced Memory)

```bash
# AWQ 4-bit quantization
MODEL_NAME=TheBloke/Llama-2-7B-AWQ
QUANTIZATION=awq

# GPTQ quantization
MODEL_NAME=TheBloke/Llama-2-7B-GPTQ
QUANTIZATION=gptq
```

### With Monitoring Stack

```bash
# Start with Prometheus + Grafana
docker-compose --profile monitoring up -d

# Access Grafana
open http://localhost:3000  # admin/admin
```

## 📊 Monitoring & Observability

### Health Checks

```bash
# Service health
curl http://localhost:8000/health

# Model info
curl http://localhost:8000/v1/models
```

### Metrics

```bash
# Prometheus metrics
curl http://localhost:8001/metrics

# Key metrics:
# - vllm:num_requests_running
# - vllm:num_requests_waiting
# - vllm:gpu_cache_usage_perc
# - vllm:time_to_first_token_seconds
# - vllm:time_per_output_token_seconds
```

### Logs

```bash
# Follow logs
docker-compose logs -f vllm-server

# Last 100 lines
docker-compose logs --tail=100 vllm-server

# Export logs
docker-compose logs vllm-server > vllm.log
```

## 🐛 Troubleshooting

### Service Won't Start

```bash
# Check GPU availability
nvidia-smi

# Verify nvidia-docker
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi

# Check logs
docker-compose logs vllm-server
```

### Out of Memory

```bash
# Reduce memory utilization in .env
GPU_MEMORY_UTILIZATION=0.7  # Instead of 0.9

# Use quantized model
QUANTIZATION=awq

# Reduce max length
MAX_MODEL_LEN=2048  # Instead of 4096
```

### Slow Performance

```bash
# Check GPU utilization
nvidia-smi dmon

# Enable prefix caching
ENABLE_PREFIX_CACHING=true

# Use better attention backend
ATTENTION_BACKEND=FLASHINFER
```

### Connection Refused

```bash
# Check if service is running
docker-compose ps

# Check port mapping
docker-compose port vllm-server 8000

# Test from inside container
docker-compose exec vllm-server curl localhost:8000/health
```

## 🚦 Performance Optimization

### Batch Size Tuning

```bash
# Increase for throughput
MAX_NUM_SEQS=512  # Default: 256

# Decrease for latency
MAX_NUM_SEQS=64
```

### Attention Backend

```bash
# Best: FlashInfer (if supported)
ATTENTION_BACKEND=FLASHINFER

# Good: FlashAttention-2
ATTENTION_BACKEND=FLASH_ATTN

# Fallback: xFormers
ATTENTION_BACKEND=XFORMERS
```

### KV Cache Optimization

```bash
# Enable FP8 KV cache (saves memory)
KV_CACHE_DTYPE=fp8

# Enable chunked prefill (better latency)
ENABLE_CHUNKED_PREFILL=true
```

## 📚 Additional Resources

- [vLLM Documentation](https://docs.vllm.ai/)
- [vLLM GitHub](https://github.com/vllm-project/vllm)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)

## 🤝 Support

### Issues?

1. Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Review [vLLM GitHub Issues](https://github.com/vllm-project/vllm/issues)
3. Join [vLLM Discord](https://discord.gg/vllm)

### Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## 📄 License

This Docker setup is part of Aether-X-Ultimate.
See main repository LICENSE for details.

vLLM is licensed under Apache 2.0.

---

**Built with ❤️ by LoveLogic AI**

*Last Updated: January 2026*
