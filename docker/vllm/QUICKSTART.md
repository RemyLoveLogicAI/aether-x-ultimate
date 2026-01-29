# 🚀 Quick Start Guide - Get Running in 5 Minutes

## Prerequisites Check

```bash
# 1. Check GPU
nvidia-smi
# Should show your GPU and driver version ≥ 535.x

# 2. Check Docker
docker --version
# Should be ≥ 20.10

# 3. Check nvidia-docker
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
# Should show GPU info
```

If any of these fail, see [CUDA_COMPATIBILITY.md](docs/CUDA_COMPATIBILITY.md) for installation.

## Step-by-Step Deployment

### 1. Navigate to Directory

```bash
cd docker/vllm
```

### 2. Configure Environment

```bash
# Copy template
cp .env.example .env

# Edit configuration (use your preferred editor)
vim .env
```

**Minimal configuration** - only change these:

```bash
# Which model to use
MODEL_NAME=meta-llama/Llama-3.1-8B-Instruct

# Your Hugging Face token (for gated models)
HUGGINGFACE_TOKEN=hf_xxxxxxxxxxxxx

# How much GPU memory to use (0.0 to 1.0)
GPU_MEMORY_UTILIZATION=0.9
```

### 3. Deploy

```bash
# Make script executable
chmod +x scripts/run-gpu.sh

# Run deployment
./scripts/run-gpu.sh
```

The script will:
- ✅ Check prerequisites
- ✅ Pull vLLM Docker image
- ✅ Start services
- ✅ Wait for health check
- ✅ Display endpoint URLs

**Expected output:**
```
🎉 vLLM Server is Running Successfully!

API Endpoints:
  - OpenAI API: http://localhost:8000/v1
  - Health Check: http://localhost:8000/health
  - Metrics: http://localhost:8001/metrics
```

### 4. Test API

```bash
# Test with provided script
chmod +x scripts/test-api.sh
./scripts/test-api.sh

# Or manually
curl http://localhost:8000/v1/models
```

## That's It! 🎉

Your vLLM server is now running and ready to handle requests.

## Next Steps

### Use from Python

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy"  # Not required unless you set VLLM_API_KEY
)

response = client.chat.completions.create(
    model="aether-x-ultimate",
    messages=[
        {"role": "user", "content": "Hello! How are you?"}
    ]
)

print(response.choices[0].message.content)
```

### Use from cURL

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "aether-x-ultimate",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### View Logs

```bash
# Follow logs in real-time
docker-compose logs -f vllm-server

# View last 100 lines
docker-compose logs --tail=100 vllm-server
```

### Check Metrics

```bash
# Prometheus metrics
curl http://localhost:8001/metrics | grep vllm

# Health status
curl http://localhost:8000/health
```

## Common Issues

### "No GPU detected"

```bash
# Check NVIDIA driver
nvidia-smi

# If not working, reinstall drivers
sudo apt-get install nvidia-driver-535
sudo reboot
```

### "CUDA version mismatch"

The vLLM image has CUDA 12.9.1 built-in. You just need driver ≥ 535.x.

```bash
# Check driver version
nvidia-smi | grep "Driver Version"

# Should be ≥ 535.x
```

### "Out of memory"

```bash
# Edit .env and reduce utilization
GPU_MEMORY_UTILIZATION=0.7  # Instead of 0.9

# Restart
docker-compose restart vllm-server
```

### "Service won't start"

```bash
# Check logs
docker-compose logs vllm-server

# Common fixes:
# 1. Wrong model name
# 2. Missing HuggingFace token for gated models
# 3. Insufficient GPU memory
```

## Stopping Services

```bash
# Stop but keep data
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Full cleanup
./scripts/cleanup.sh --all
```

## Getting Help

1. **Read the docs**: `README.md`, `CUDA_COMPATIBILITY.md`
2. **Check logs**: `docker-compose logs vllm-server`
3. **Run tests**: `./scripts/test-api.sh`
4. **Benchmark**: `./scripts/benchmark.sh`

## Pro Tips

### Use Different Models

Edit `.env`:
```bash
MODEL_NAME=mistralai/Mistral-7B-Instruct-v0.3
# or
MODEL_NAME=Qwen/Qwen2-7B-Instruct
```

Then restart:
```bash
docker-compose restart vllm-server
```

### Multiple GPUs

Edit `.env`:
```bash
GPU_COUNT=2
TENSOR_PARALLEL_SIZE=2
CUDA_VISIBLE_DEVICES=0,1
```

### Enable Monitoring

```bash
# Start with Prometheus + Grafana
docker-compose --profile monitoring up -d

# Access Grafana
open http://localhost:3000
# Login: admin/admin
```

### Quantization (Less Memory)

Edit `.env`:
```bash
MODEL_NAME=TheBloke/Llama-2-7B-AWQ
QUANTIZATION=awq
```

## Production Checklist

- [ ] Set `VLLM_API_KEY` in `.env` for authentication
- [ ] Configure resource limits in `docker-compose.yml`
- [ ] Enable monitoring with `--profile monitoring`
- [ ] Set up log rotation
- [ ] Configure backup for model cache
- [ ] Test failover scenarios
- [ ] Document your API endpoints
- [ ] Set up health check monitoring

See [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) for full production guide.

---

**You're ready to go! 🚀**

Need more details? See the [full README](README.md).
