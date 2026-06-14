# Ubuntu 26.04 ROCm Deployment for AMD RDNA 4 GPUs

## Hardware Profile
* **OS:** Ubuntu 26.04 LTS (Resolute)
* **Kernel:** Linux 7.0.0+ Generic
* **GPU:** AMD Radeon RX 9000 Series (RDNA 4 / `gfx1201`)
* **Target Stack:** ROCm 7.2 + PyTorch 2.14+ (Nightly)

## The Post-Mortem: What Fails vs. What Works

### ❌ What Breaks the System
1. **The Official AMD Repository Installer (`amdgpu-dkms`):** The proprietary kernel module build system crashes on the Linux 7.0 upstream kernel due to missing/deprecated legacy APIs. Forcing it breaks `apt`.
2. **Standard RDNA 3 Overrides (`11.0.0`):** Passing RDNA 3 compilation instructions directly to RDNA 4 silicon causes an instant illegal instruction exception, triggering a kernel panic (system freeze).
3. **Vanilla PyTorch Wheels:** Standard stable PyTorch wheels do not yet package binaries targeting Python 3.14 or native ROCm 7.2 runtimes out-of-the-box.

### ✅ What Works Natively
1. **No-DKMS User-space Layout:** Ubuntu 26.04 natively handles graphics processing in-kernel. We only need the user-space libraries (`rocm-core`, `libamdhip64-dev`) passed via `--no-install-recommends`.
2. **Explicit RDNA 4 Environmental Targets:** Forcing `HSA_OVERRIDE_GFX_VERSION=12.0.0` maps tensors directly onto the hardware without kernel faults.
3. **PyTorch Nightly Indexing:** Utilizing the dedicated `/whl/nightly/rocm7.2` storage index cleanly aligns the Python compute bindings.
