#!/bin/bash
# ComfyPack - RunPod Start Script
# This script runs automatically when a RunPod instance starts.

set -e

PROJECT_DIR="${RUNPOD_PROJECT_DIR:-/workspace/comfypack}"
MODEL_DIR="${RUNPOD_MODEL_DIR:-/workspace/models}"
PATCH_DIR="${RUNPOD_PATCH_DIR:-/workspace/patch_data}"
CONFIG_DIR="${RUNPOD_CONFIG_DIR:-/workspace/config}"

echo "===================================================="
echo "   ComfyPack - RunPod Start"
echo "===================================================="

# ─── Create .env ─────────────────────────────────────────
cat > "$PROJECT_DIR/.env" << EOF
MODEL_PATH=$MODEL_DIR
PATCH_DATA_PATH=$PATCH_DIR
CONFIG_PATH=$CONFIG_DIR/config.json
COMFYUI_PORT=8188
HOOKING_PORT=8189
EOF

# ─── Ensure directories exist ───────────────────────────
mkdir -p "$MODEL_DIR"
mkdir -p "$PATCH_DIR"/{asset,asset_data,chain_presets,customprompt,pose_data,auto_complete,workflow,mode_workflow}
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    echo '{}' > "$CONFIG_DIR/config.json"
    echo "[OK] Created empty config.json"
fi

# ─── Start services ─────────────────────────────────────
cd "$PROJECT_DIR"
docker compose up -d

echo ""
echo "ComfyPack is running!"
echo "  ComfyUI:        http://localhost:8188"
echo "  Hooking Server:  http://localhost:8189"
echo ""
echo "Model directory: $MODEL_DIR"
echo "Patch directory: $PATCH_DIR"
echo "Config directory: $CONFIG_DIR"
echo ""

# Keep container alive
exec "$@"
