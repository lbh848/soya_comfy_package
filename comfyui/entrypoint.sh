#!/bin/bash
set -e

echo "=== ComfyPack Entrypoint ==="

# Restore user-installed custom nodes from persisted snapshot
echo "[entrypoint] Restoring custom nodes from snapshot..."
python /app/restore_nodes.py

# Initialize LoRA Manager settings if missing
python /app/init_lora_manager.py

# Download InsightFace buffalo_l model on first run (needed by IPAdapter Plus)
INSIGHTFACE_MODEL="/app/comfyui/models/insightface/models/buffalo_l/det_10g.onnx"
if [ ! -f "$INSIGHTFACE_MODEL" ]; then
    echo "[entrypoint] Downloading InsightFace buffalo_l model (~280MB, first run only)..."
    python -c "
from insightface.app import FaceAnalysis
FaceAnalysis(name='buffalo_l', root='/app/comfyui/models/insightface', providers=['CPUExecutionProvider'])
" && echo "[entrypoint] InsightFace model ready." \
    || echo "[entrypoint] WARNING: InsightFace download failed. Will retry when IPAdapterInsightFaceLoader is used."
fi

# Start ComfyUI
echo "[entrypoint] Starting ComfyUI..."
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header '*' --fast
