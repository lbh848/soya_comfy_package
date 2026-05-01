#!/bin/bash
set -e

echo "=== ComfyPack Entrypoint ==="

# Restore user-installed custom nodes from persisted snapshot
echo "[entrypoint] Restoring custom nodes from snapshot..."
python /app/restore_nodes.py

# Initialize LoRA Manager settings if missing
python /app/init_lora_manager.py

# Download InsightFace buffalo_l model if missing (needed by IPAdapter Plus)
INSIGHTFACE_MARKER="/app/comfyui/models/insightface/.downloaded"
if [ ! -f "$INSIGHTFACE_MARKER" ]; then
    echo "[entrypoint] Downloading InsightFace buffalo_l model (~280MB, first run only)..."
    python -c "
from insightface.app import FaceAnalysis
model = FaceAnalysis(name='buffalo_l', root='/app/comfyui/models/insightface', providers=['CPUExecutionProvider'])
model.prepare(ctx_id=-1, det_size=(640, 640))
" \
    && touch "$INSIGHTFACE_MARKER" \
    && echo "[entrypoint] InsightFace buffalo_l model ready." \
    || echo "[entrypoint] WARNING: InsightFace model download failed. Face analysis may not work."
fi

# Start ComfyUI
echo "[entrypoint] Starting ComfyUI..."
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header '*' --fast
