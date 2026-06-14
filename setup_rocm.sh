#!/bin/bash
set -e

echo "========================================="
echo "Initializing Ubuntu 26.04 RDNA 4 ROCm Setup"
echo "========================================="

# 1. Clean out any legacy/broken AMD repository files
echo "[*] Purging broken third-party repositories..."
sudo rm -f /etc/apt/sources.list.d/amdgpu*.list /etc/apt/sources.list.d/rocm*.list
sudo apt-get purge -y amdgpu-dkms || true
sudo apt autoremove -y

# 2. Install Native Ubuntu ROCm Core Libraries & HIP Compiler
echo "[*] Installing native Ubuntu user-space ROCm stacks..."
sudo apt update
sudo apt install --no-install-recommends -y \
    rocm-core \
    libamdhip64-dev \
    hipcc \
    rocminfo \
    rocm-smi \
    python3-pip \
    python3-venv

# 3. Establish standard symlinks for external tools looking in /opt/rocm
echo "[*] Creating fallback symbolic links under /opt/rocm..."
sudo mkdir -p /opt/rocm/bin
sudo ln -sf /usr/bin/rocminfo /opt/rocm/bin/rocminfo
sudo ln -sf /usr/bin/rocm-smi /opt/rocm/bin/rocm-smi
sudo ln -sf /usr/bin/hipcc /opt/rocm/bin/hipcc
sudo ln -sf /usr/bin/hipconfig /opt/rocm/bin/hipconfig

# 4. Add user to hardware rendering groups
echo "[*] Configuring hardware access permissions..."
sudo usermod -aG video,render $USER

# 5. Inject permanent RDNA 4 Compatibility Envs into .bashrc
echo "[*] Writing RDNA 4 architecture overrides to profile..."
sed -i '/HSA_OVERRIDE_GFX_VERSION/d' ~/.bashrc
sed -i '/PYTORCH_ROCM_ARCH/d' ~/.bashrc
sed -i '/ROCM_PATH/d' ~/.bashrc

echo 'export ROCM_PATH=/usr' >> ~/.bashrc
echo 'export HSA_OVERRIDE_GFX_VERSION=12.0.0' >> ~/.bashrc
echo 'export PYTORCH_ROCM_ARCH=gfx1201' >> ~/.bashrc
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc

# 6. Install PyTorch Nightly with ROCm 7.2 support globally
echo "[*] Deploying PyTorch Nightly for ROCm 7.2 (System-wide)..."
pip install --pre torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/rocm7.2 \
    --break-system-packages

echo "========================================="
echo "Setup complete! Please run: source ~/.bashrc"
echo "========================================="
