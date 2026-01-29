# CUDA Compatibility Guide

## 🎯 Understanding the Problem

### The Torch/CUDA Dependency Challenge

When building AI applications, you often face a complex dependency chain:

```
Your Application
    |
    v
PyTorch (torch)
    |
    v
CUDA Runtime
    |
    v
CUDA Driver
    |
    v
NVIDIA GPU
```

**The Problem**: Each layer has version requirements:
- PyTorch 2.9.1 requires CUDA 12.9.x or 11.8.x
- PyTorch 1.13.1 requires CUDA 11.7.x or 11.8.x
- Your code may use features from specific PyTorch versions
- Pre-compiled wheels are built for specific CUDA versions

### Why vLLM Solves This

vLLM Docker images come with:
- ✅ **Pre-compiled PyTorch** (2.9.1) with CUDA 12.9.1 bindings
- ✅ **All CUDA libraries** bundled (cuDNN, cuBLAS, NCCL, etc.)
- ✅ **Optimized kernels** pre-built (FlashAttention, etc.)
- ✅ **No compilation** required at runtime

## 📊 Version Matrix

### vLLM Official Images

| vLLM Version | PyTorch | CUDA | Python | Base Image |
|--------------|---------|------|--------|------------|
| v0.11.0      | 2.9.1   | 12.9 | 3.12   | nvidia/cuda:12.9.1-devel-ubuntu22.04 |
| v0.10.4      | 2.8.1   | 12.4 | 3.11   | nvidia/cuda:12.4.1-devel-ubuntu22.04 |
| latest       | Latest  | 12.x | 3.12   | Latest CUDA devel |

### NVIDIA Driver Requirements

| CUDA Version | Min Driver (Linux) | Min Driver (Windows) |
|--------------|-------------------|---------------------|
| 12.9         | ≥ 535.x          | ≥ 536.x            |
| 12.4         | ≥ 530.x          | ≥ 531.x            |
| 12.1         | ≥ 525.x          | ≥ 527.x            |
| 11.8         | ≥ 520.x          | ≥ 522.x            |

### GPU Compute Capability

| GPU Architecture | Compute Capability | Supported | Recommended CUDA |
|------------------|-------------------|-----------|------------------|
| Ada (RTX 40xx)   | 8.9               | ✅        | 12.x             |
| Hopper (H100)    | 9.0               | ✅        | 12.x             |
| Ampere (A100, RTX 30xx) | 8.0, 8.6   | ✅        | 11.8+ or 12.x    |
| Turing (RTX 20xx)| 7.5               | ✅        | 11.8 or 12.x     |
| Volta (V100)     | 7.0               | ✅        | 11.8 or 12.x     |
| Pascal (P100)    | 6.0               | ⚠️        | 11.8 only        |

## 🔍 Checking Your System

### 1. Check NVIDIA Driver

```bash
nvidia-smi
```

Look for:
- **Driver Version**: Should be ≥ 535.x for CUDA 12.9
- **CUDA Version**: This is the MAX CUDA version supported

### 2. Check GPU Compute Capability

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv
```

Or using Python:
```python
import torch
if torch.cuda.is_available():
    cap = torch.cuda.get_device_capability(0)
    print(f"Compute Capability: {cap[0]}.{cap[1]}")
```

### 3. Verify nvidia-docker

```bash
docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu22.04 nvidia-smi
```

If this works, you're ready to use vLLM!

## 🛠️ Installation Guide

### Prerequisites

#### 1. Install NVIDIA Drivers

**Ubuntu/Debian:**
```bash
# Add NVIDIA package repositories
sudo apt-get update
sudo apt-get install -y nvidia-driver-535

# Reboot
sudo reboot

# Verify
nvidia-smi
```

**RHEL/CentOS:**
```bash
# Enable EPEL
sudo dnf install epel-release

# Install driver
sudo dnf install nvidia-driver

# Reboot
sudo reboot
```

#### 2. Install Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Log out and back in for group changes
```

#### 3. Install NVIDIA Container Toolkit

```bash
# Configure repository
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Install
sudo apt-get update
sudo apt-get install -y nvidia-docker2

# Restart Docker
sudo systemctl restart docker

# Test
docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu22.04 nvidia-smi
```

## 🔧 Compatibility Scenarios

### Scenario 1: Older GPU (Compute < 7.0)

**Problem**: Pascal GPUs (GTX 10xx) have limited support in CUDA 12.x

**Solution**: Use vLLM with CUDA 11.8
```bash
# Use older vLLM version
VLLM_VERSION=v0.9.0
docker-compose up -d
```

### Scenario 2: Older NVIDIA Driver

**Problem**: Driver 525.x doesn't support CUDA 12.9

**Solution A**: Upgrade driver
```bash
sudo apt-get install nvidia-driver-535
sudo reboot
```

**Solution B**: Use older vLLM version
```bash
VLLM_VERSION=v0.10.0  # Uses CUDA 12.4
```

### Scenario 3: Mixed GPU Types

**Problem**: Running A100 + V100 in same system

**Solution**: Use CUDA 12.x with backward compatibility
```bash
# In .env
TORCH_CUDA_ARCH_LIST=7.0;8.0  # Both Volta and Ampere
CUDA_VISIBLE_DEVICES=0  # Use specific GPU
```

### Scenario 4: CPU-Only Testing

**Problem**: No GPU available for testing

**Solution**: Use vLLM CPU mode (limited)
```bash
# Not recommended for production, but works for testing
docker run --rm vllm/vllm-openai:latest \
  --model facebook/opt-125m \
  --dtype float32 \
  --device cpu
```

## 🚨 Common Issues

### Issue 1: "CUDA driver version is insufficient"

**Error:**
```
CUDA driver version is insufficient for CUDA runtime version
```

**Cause**: Driver too old for CUDA 12.9

**Fix**:
```bash
# Check current driver
nvidia-smi | grep "Driver Version"

# Upgrade to 535+
sudo apt-get install nvidia-driver-535
sudo reboot
```

### Issue 2: "nvidia-smi not found in container"

**Error:**
```
nvidia-smi: command not found
```

**Cause**: nvidia-docker not properly configured

**Fix**:
```bash
# Reinstall nvidia-docker2
sudo apt-get install --reinstall nvidia-docker2
sudo systemctl restart docker

# Configure Docker daemon
sudo vi /etc/docker/daemon.json
```

Add:
```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia"
}
```

### Issue 3: "Unsupported GPU architecture"

**Error:**
```
RuntimeError: CUDA error: no kernel image is available
```

**Cause**: PyTorch not compiled for your GPU architecture

**Fix**: Rebuild with correct arch list
```bash
# In .env, add your GPU's compute capability
TORCH_CUDA_ARCH_LIST=8.6  # For RTX 3090

# Restart
docker-compose down
docker-compose up --build -d
```

### Issue 4: "Out of memory"

**Error:**
```
CUDA out of memory
```

**Cause**: GPU memory insufficient for model

**Fix**: Reduce utilization or use quantization
```bash
# In .env
GPU_MEMORY_UTILIZATION=0.7  # Reduce from 0.9
QUANTIZATION=awq  # Use 4-bit quantization
MAX_MODEL_LEN=2048  # Reduce context length
```

## 📈 Performance Optimization

### CUDA Graphs (Faster Inference)

```bash
# Enable CUDA graphs for fixed batch sizes
export VLLM_USE_CUDA_GRAPH=1
```

### Tensor Cores (Faster Matrix Ops)

```bash
# Automatic on Ampere+ GPUs
# Ensure using appropriate dtype
TORCH_DTYPE=float16  # or bfloat16 on Ampere+
```

### NCCL Tuning (Multi-GPU)

```bash
export NCCL_DEBUG=INFO
export NCCL_P2P_DISABLE=0  # Enable peer-to-peer
export NCCL_IB_DISABLE=1   # If not using InfiniBand
```

## 🔬 Testing Compatibility

### Quick Test Script

```bash
#!/bin/bash
set -e

echo "=== GPU Information ==="
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv

echo "\n=== CUDA Version ==="
nvcc --version 2>/dev/null || echo "nvcc not in PATH (OK in container)"

echo "\n=== Docker GPU Test ==="
docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu22.04 nvidia-smi

echo "\n=== vLLM Container Test ==="
docker run --rm --gpus all vllm/vllm-openai:v0.11.0 \
  python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"

echo "\n✅ All tests passed!"
```

Save as `test-compatibility.sh` and run:
```bash
chmod +x test-compatibility.sh
./test-compatibility.sh
```

## 📚 Further Reading

- [NVIDIA CUDA Compatibility Guide](https://docs.nvidia.com/deploy/cuda-compatibility/)
- [PyTorch Installation Guide](https://pytorch.org/get-started/locally/)
- [vLLM Installation Docs](https://docs.vllm.ai/en/latest/getting_started/installation.html)
- [NVIDIA Container Toolkit Docs](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html)

---

**💡 Pro Tip**: When in doubt, use the latest vLLM image with `VLLM_VERSION=latest`. It's tested and maintained by the vLLM team.
