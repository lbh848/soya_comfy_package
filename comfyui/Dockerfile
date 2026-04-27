# ComfyUI Docker Image for ComfyPack
# ComfyUI v0.16.4 + Custom Nodes + CUDA 12.4

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ─── System packages + Python 3.12 (deadsnakes PPA) ─────
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev \
    git wget curl \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender1 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && rm -rf /var/lib/apt/lists/*

# ─── PyTorch + CUDA ─────────────────────────────────────
RUN pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu124

# ─── ComfyUI ─────────────────────────────────────────────
WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git comfyui \
    && cd comfyui \
    && git checkout v0.16.4 \
    && pip install --no-cache-dir -r requirements.txt

WORKDIR /app/comfyui

# ─── ComfyUI-Manager ─────────────────────────────────────
RUN cd custom_nodes \
    && git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
    && cd ComfyUI-Manager \
    && pip install --no-cache-dir -r requirements.txt

# ─── Custom Nodes (Manager-installed) ────────────────────
RUN cd custom_nodes \
    && git clone https://github.com/kijai/ComfyUI-KJNodes.git \
    && cd ComfyUI-KJNodes && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git \
    && cd ComfyUI_IPAdapter_plus && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git \
    && cd comfyui_controlnet_aux && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    && cd ComfyUI-Impact-Pack && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git comfyui-impact-subpack \
    && cd comfyui-impact-subpack && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/rgthree/rgthree-comfy.git \
    && cd rgthree-comfy && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/yolain/ComfyUI-Easy-Use.git \
    && cd ComfyUI-Easy-Use && pip install --no-cache-dir -r requirements.txt && cd .. \
    && git clone https://github.com/willmiao/ComfyUI-Lora-Manager.git \
    && cd ComfyUI-Lora-Manager && pip install --no-cache-dir -r requirements.txt || true && cd ..

# ─── Custom Nodes (Manual clone - Soya) ──────────────────
RUN cd custom_nodes \
    && git clone -b V3.1 https://github.com/lbh848/Comfyui-soya-custom-nodes.git comfyui-soya-custom-nodes \
    && cd comfyui-soya-custom-nodes && pip install --no-cache-dir -r requirements.txt || true && cd .. \
    && git clone https://github.com/lbh848/comfyui-workflow-to-api-converter-endpoint.git \
    && cd comfyui-workflow-to-api-converter-endpoint && pip install --no-cache-dir -r requirements.txt || true && cd ..

# ─── Extra model paths (mount point) ─────────────────────
COPY extra_model_paths.yaml /app/comfyui/extra_model_paths.yaml

# ─── Ports ───────────────────────────────────────────────
EXPOSE 8188

# ─── Startup ─────────────────────────────────────────────
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188"]
