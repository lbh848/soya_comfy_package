#!/bin/bash
set -e

echo "=== ComfyPack Entrypoint ==="

# Add Impact Pack modules to PYTHONPATH so user nodes can import impact.*
export PYTHONPATH="/app/comfyui/custom_nodes/ComfyUI-Impact-Pack/modules${PYTHONPATH:+:$PYTHONPATH}"

# Restore user-installed custom nodes from persisted snapshot
echo "[entrypoint] Restoring custom nodes from snapshot..."
python /app/restore_nodes.py

# Initialize LoRA Manager settings if missing
python /app/init_lora_manager.py

# Download InsightFace buffalo_l model if missing (needed by IPAdapter Plus)
INSIGHTFACE_DIR="/app/comfyui/models/insightface/models/buffalo_l"
INSIGHTFACE_MARKER="/app/comfyui/models/insightface/.downloaded"
if [ ! -f "$INSIGHTFACE_MARKER" ]; then
    echo "[entrypoint] Downloading InsightFace buffalo_l model (~280MB, first run only)..."
    mkdir -p "$INSIGHTFACE_DIR"
    wget -q --show-progress -O /tmp/buffalo_l.zip \
        "https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip" \
    && unzip -q -o /tmp/buffalo_l.zip -d /tmp/buffalo_l_extracted \
    && cp -r /tmp/buffalo_l_extracted/buffalo_l/* "$INSIGHTFACE_DIR/" \
    && touch "$INSIGHTFACE_MARKER" \
    && echo "[entrypoint] InsightFace buffalo_l model ready." \
    || echo "[entrypoint] WARNING: InsightFace model download failed. Face analysis may not work."
    rm -rf /tmp/buffalo_l.zip /tmp/buffalo_l_extracted
fi

# Start ComfyUI
echo "[entrypoint] Starting ComfyUI..."
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header '*' --fast
