# Hooking Server Docker Image for ComfyPack
# comfyui_hooking_server - ComfyUI proxy/middleware
#
# Source code is bind-mounted from host at runtime (hooking_server/app/)
# This Dockerfile only installs system + Python base dependencies.

FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV REAL_COMFY_HOST=comfyui
ENV REAL_COMFY_PORT=8188

# ─── System packages (for OpenCV, ONNX, etc.) ────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# ─── Base dependencies (cloned at build time for pip install) ──
WORKDIR /app
RUN git clone https://github.com/lbh848/comfyui_hooking_server.git /tmp/hooking_build \
    && pip install --no-cache-dir -r /tmp/hooking_build/requirements.txt \
    && rm -rf /tmp/hooking_build

# ─── Data directories (mounted from host) ─────────────────
RUN mkdir -p asset asset_data chain_presets customprompt \
    pose_data auto_complete workflow mode_workflow \
    current_work current_mode_workflow workflow_backup \
    workflow_backup_static key logs frontend modes

# ─── Config (overridable via volume mount) ────────────────
RUN echo '{}' > /app/config.json

# ─── Entrypoint (outside /app to survive bind mount) ─────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ─── Ports ───────────────────────────────────────────────
EXPOSE 8189

# ─── Startup ─────────────────────────────────────────────
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
