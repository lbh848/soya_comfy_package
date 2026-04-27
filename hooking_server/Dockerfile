# Hooking Server Docker Image for ComfyPack
# comfyui_hooking_server - ComfyUI proxy/middleware

FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
ENV REAL_COMFY_HOST=comfyui
ENV REAL_COMFY_PORT=8188

# ─── System packages (for OpenCV, ONNX, etc.) ────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# ─── App ──────────────────────────────────────────────────
WORKDIR /app
RUN git clone https://github.com/lbh848/comfyui_hooking_server.git . \
    && pip install --no-cache-dir -r requirements.txt

# ─── Data directories (mounted from host) ─────────────────
# These will be overlaid by volume mounts at runtime:
#   /app/asset/, /app/asset_data/, /app/chain_presets/,
#   /app/customprompt/, /app/pose_data/, /app/auto_complete/,
#   /app/workflow/, /app/mode_workflow/, /app/key/, /app/logs/
RUN mkdir -p asset asset_data chain_presets customprompt \
    pose_data auto_complete workflow mode_workflow \
    current_work current_mode_workflow workflow_backup \
    workflow_backup_static key logs frontend modes

# ─── Config (overridable via volume mount) ────────────────
# If user mounts their own config.json, it overrides this one.
RUN echo '{}' > /app/config.json

# ─── Ports ───────────────────────────────────────────────
EXPOSE 8189

# ─── Startup ─────────────────────────────────────────────
CMD ["python", "server.py"]
