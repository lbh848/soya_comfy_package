#!/bin/bash
# ComfyPack - RunPod Start Script
# This script runs automatically when a RunPod instance starts.

set -e

# --- Branch Configuration ---
SOYA_NODES_BRANCH="v3.1"
WF_CONVERTER_BRANCH="main"
HOOKING_SERVER_BRANCH="main"

PROJECT_DIR="${RUNPOD_PROJECT_DIR:-/workspace/comfypack}"
MODEL_DIR="${RUNPOD_MODEL_DIR:-/workspace/comfyui/models}"
PATCH_DIR="${RUNPOD_PATCH_DIR:-/workspace/hooking_server/patch_data}"
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
mkdir -p "$PATCH_DIR"/{asset,asset_data,chain_presets,customprompt,pose_data,auto_complete,workflow,mode_workflow,workflow_backup,workflow_backup_static,current_work,current_mode_workflow}
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
    echo '{}' > "$CONFIG_DIR/config.json"
    echo "[OK] Created empty config.json"
fi

# ─── Clone repos if missing ─────────────────────────────
USER_NODES_DIR="$PROJECT_DIR/comfyui/user_nodes"
HOOKING_APP_DIR="$PROJECT_DIR/hooking_server/app"

mkdir -p "$USER_NODES_DIR"

if [ ! -d "$USER_NODES_DIR/comfyui-soya-custom-nodes/.git" ]; then
    echo "[CLONE] soya-custom-nodes..."
    git clone -b "$SOYA_NODES_BRANCH" https://github.com/lbh848/Comfyui-soya-custom-nodes.git "$USER_NODES_DIR/comfyui-soya-custom-nodes" || echo "[WARN] Clone failed"
fi

if [ ! -d "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint/.git" ]; then
    echo "[CLONE] workflow-to-api-converter-endpoint..."
    git clone -b "$WF_CONVERTER_BRANCH" https://github.com/lbh848/comfyui-workflow-to-api-converter-endpoint.git "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint" || echo "[WARN] Clone failed"
fi

if [ ! -d "$HOOKING_APP_DIR/.git" ]; then
    mkdir -p "$HOOKING_APP_DIR"
    echo "[CLONE] hooking_server..."
    git clone -b "$HOOKING_SERVER_BRANCH" https://github.com/lbh848/comfyui_hooking_server.git "$HOOKING_APP_DIR" || echo "[WARN] Clone failed"
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
