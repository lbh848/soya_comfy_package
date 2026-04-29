# ComfyUI Docker Image for ComfyPack
# ComfyUI v0.16.4 + Custom Nodes + CUDA 12.8 + SageAttention
#
# Multi-stage build:
#   Stage 1 (builder): Compile SageAttention (needs nvcc from devel image)
#   Stage 2 (runtime): Final image using lightweight runtime base

# ─── Stage 1: Build SageAttention (needs nvcc from devel image) ──
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/sources.list.d/cuda* /etc/apt/sources.list.d/nvidia* \
    && apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-dev git curl \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && rm -rf /var/lib/apt/lists/*

# PyTorch needed for SageAttention build (setup.py imports torch)
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

# Build SageAttention V1 from PyPI (Triton-based, no nvcc issues)
RUN pip wheel --no-cache-dir sageattention \
    -w /wheels

# ─── Stage 2: Runtime ─────────────────────────────────
FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ─── System packages + Python 3.12 (deadsnakes PPA) ─────
RUN rm -f /etc/apt/sources.list.d/cuda* /etc/apt/sources.list.d/nvidia* \
    && apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev \
    git wget curl g++ \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender1 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && rm -rf /var/lib/apt/lists/*

# ─── PyTorch + CUDA 12.8 ────────────────────────────────
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128

# ─── SageAttention (from builder) ───────────────────────
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-deps --find-links=/wheels sageattention \
    && rm -rf /wheels

# ─── ComfyUI ────────────────────────────────────────────
WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git comfyui \
    && cd comfyui \
    && git checkout v0.16.4 \
    && pip install --no-cache-dir -r requirements.txt

WORKDIR /app/comfyui

# ─── ComfyUI-Manager ────────────────────────────────────
RUN cd custom_nodes \
    && git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    && cd ComfyUI-Manager \
    && pip install --no-cache-dir -r requirements.txt

# ─── Custom Nodes (Manager-installed) ────────────────────
# Each node's pip install has || true so a missing requirements.txt doesn't skip remaining nodes
RUN cd custom_nodes \
    && git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    && cd ComfyUI-KJNodes && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git \
    && cd ComfyUI_IPAdapter_plus && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    && cd comfyui_controlnet_aux && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    && cd ComfyUI-Impact-Pack && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git comfyui-impact-subpack \
    && cd comfyui-impact-subpack && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/rgthree/rgthree-comfy.git \
    && cd rgthree-comfy && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/yolain/ComfyUI-Easy-Use.git \
    && cd ComfyUI-Easy-Use && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/willmiao/ComfyUI-Lora-Manager.git \
    && cd ComfyUI-Lora-Manager && pip install --no-cache-dir -r requirements.txt || true && cd ..

# ─── Extra model paths (mount point) ─────────────────────
COPY extra_model_paths.yaml /app/comfyui/extra_model_paths.yaml

# ─── Save builtin node list for entrypoint ───────────────
RUN cd custom_nodes && ls -1d */ | sed 's/\/$//' > /app/builtin_nodes.txt

# ─── Entrypoint: symlink user_nodes + restore deps ───────
COPY restore_nodes.py /app/restore_nodes.py
COPY entrypoint.sh /app/comfyui/entrypoint.sh
RUN chmod +x /app/comfyui/entrypoint.sh

# ─── Ports ───────────────────────────────────────────────
EXPOSE 8188

# ─── Startup ─────────────────────────────────────────────
ENTRYPOINT ["/app/comfyui/entrypoint.sh"]
