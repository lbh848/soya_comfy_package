#!/bin/bash
# ComfyPack - Linux Installer
# ComfyUI + Hooking Server Docker Deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Branch Configuration (change these for deployment) ---
SOYA_NODES_BRANCH="main"
WF_CONVERTER_BRANCH="main"
HOOKING_SERVER_BRANCH="main"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "===================================================="
echo "   ComfyPack Linux Installer"
echo "===================================================="
echo ""
echo "   New install: 2 -> 3"
echo "   Update:      6"
echo ""
echo "   Other menus:"
echo "     1 - Build images locally (slow, use when offline)"
echo "     4 - Stop ComfyPack (containers)"
echo "     5 - Check running status"
echo "     7 - Reset settings (delete .env and regenerate)"
echo ""
echo "===================================================="
echo ""

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "  ${RED}[XX]${NC} $1"; }

# ─── NVIDIA GPU ──────────────────────────────────────────
echo "[1/5] Checking NVIDIA GPU..."
if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,no-header 2>/dev/null | head -1)
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,no-header,nounits 2>/dev/null | head -1)
    ok "GPU: $GPU_NAME"
    ok "VRAM: ${VRAM}MB"
else
    fail "NVIDIA GPU not found. Install NVIDIA drivers first."
    echo "  sudo apt install nvidia-driver-535  # or latest for your system"
    exit 1
fi

# ─── RAM ─────────────────────────────────────────────────
echo ""
echo "[2/5] Checking RAM..."
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$RAM_GB" -ge 32 ]; then
    ok "RAM: ${RAM_GB}GB"
elif [ "$RAM_GB" -ge 16 ]; then
    warn "RAM: ${RAM_GB}GB (32GB+ recommended)"
else
    fail "RAM: ${RAM_GB}GB (32GB+ required)"
fi

# ─── Docker ──────────────────────────────────────────────
echo ""
echo "[3/5] Checking Docker..."
if ! command -v docker &>/dev/null; then
    echo "  Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    ok "Docker installed"
else
    ok "Docker installed"
fi

if ! docker info &>/dev/null; then
    fail "Docker is not running"
    echo "  sudo systemctl start docker"
    exit 1
fi
ok "Docker is running"

# ─── NVIDIA Container Toolkit ────────────────────────────
echo ""
echo "[4/5] Checking NVIDIA Container Toolkit..."
if docker info 2>/dev/null | grep -qi "NVIDIA"; then
    ok "NVIDIA Container Toolkit installed"
else
    echo "  Installing NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ok "NVIDIA Container Toolkit installed"
fi

# ─── Docker Compose ──────────────────────────────────────
echo ""
echo "[5/5] Checking Docker Compose..."
if docker compose version &>/dev/null; then
    ok "Docker Compose available"
else
    fail "Docker Compose not available"
    echo "  Install Docker Compose plugin: sudo apt-get install docker-compose-plugin"
    exit 1
fi

# ─── Configuration ───────────────────────────────────────
ENV_FILE="$PROJECT_DIR/.env"
CONFIG_DIR="$PROJECT_DIR/config"
MODEL_DIR="$PROJECT_DIR/comfyui/models"
PATCH_DIR="$PROJECT_DIR/hooking_server/patch_data"
CONFIG_FILE="$CONFIG_DIR/config.json"

if [ ! -f "$ENV_FILE" ]; then
    echo ""
    echo "--- Initial Setup ---"
    echo ""

    cat > "$ENV_FILE" << EOF
# ComfyPack Configuration
MODEL_PATH=$MODEL_DIR
PATCH_DATA_PATH=$PATCH_DIR
CONFIG_PATH=$CONFIG_FILE
COMFYUI_PORT=8188
HOOKING_PORT=8189
EOF

    ok ".env file created: $ENV_FILE"

    mkdir -p "$MODEL_DIR"
    mkdir -p "$PATCH_DIR"/{asset,asset_data,chain_presets,customprompt,pose_data,auto_complete,workflow,mode_workflow,workflow_backup,workflow_backup_static,current_work,current_mode_workflow}
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{}' > "$CONFIG_FILE"
        ok "Created empty config.json"
    fi

    ok "Initial setup complete."
fi

# ─── Clone repos if missing ──────────────────────────────
USER_NODES_DIR="$PROJECT_DIR/comfyui/user_nodes"
HOOKING_APP_DIR="$PROJECT_DIR/hooking_server/app"

mkdir -p "$USER_NODES_DIR"

if [ ! -d "$USER_NODES_DIR/comfyui-soya-custom-nodes/.git" ]; then
    echo ""
    echo "[CLONE] comfyui-soya-custom-nodes..."
    if git clone -b "$SOYA_NODES_BRANCH" https://github.com/lbh848/Comfyui-soya-custom-nodes.git "$USER_NODES_DIR/comfyui-soya-custom-nodes"; then
        ok "soya-custom-nodes cloned"
    else
        fail "Failed to clone soya-custom-nodes"
    fi
fi

if [ ! -d "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint/.git" ]; then
    echo ""
    echo "[CLONE] comfyui-workflow-to-api-converter-endpoint..."
    if git clone -b "$WF_CONVERTER_BRANCH" https://github.com/lbh848/comfyui-workflow-to-api-converter-endpoint.git "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint"; then
        ok "workflow-to-api-converter-endpoint cloned"
    else
        fail "Failed to clone workflow-to-api-converter-endpoint"
    fi
fi

if [ ! -d "$HOOKING_APP_DIR/.git" ]; then
    mkdir -p "$HOOKING_APP_DIR"
    echo ""
    echo "[CLONE] comfyui_hooking_server..."
    if git clone -b "$HOOKING_SERVER_BRANCH" https://github.com/lbh848/comfyui_hooking_server.git "$HOOKING_APP_DIR"; then
        ok "hooking_server cloned"
    else
        fail "Failed to clone hooking_server"
    fi
fi

# ─── Menu ────────────────────────────────────────────────
while true; do
    echo ""
    echo "===================================================="
    echo "   ComfyPack Menu"
    echo "===================================================="
    echo ""
    echo "  1. Build Docker images (local)"
    echo "  2. Pull images from Docker Hub (recommended)"
    echo "  3. Start ComfyPack (containers)"
    echo "  4. Stop ComfyPack (containers)"
    echo "  5. Running status"
    echo "  6. Update to latest version"
    echo "  7. Reset settings"
    echo "  8. Remove containers"
    echo "  9. Remove images (free disk space)"
    echo "  0. Exit"
    echo ""
    read -p "Select [0-9]: " CHOICE

    case "$CHOICE" in
        1)
            echo "Building Docker images..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" build --no-cache
            echo "Cleaning up unused old images..."
            docker image prune -f
            ok "Build complete!"
            ;;
        2)
            echo "Pulling images from Docker Hub..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" pull
            echo "Cleaning up unused old images..."
            docker image prune -f
            ok "Download complete!"
            ;;
        3)
            echo "Starting ComfyPack (containers)..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d
            echo ""
            echo "===================================================="
            echo "   ComfyPack (containers) is running!"
            echo "===================================================="
            echo ""
            echo "   ComfyUI:        http://localhost:8188"
            echo "   Hooking Server:  http://localhost:8189"
            echo ""
            ;;
        4)
            echo "Stopping ComfyPack (containers)..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" down
            ok "Stopped."
            ;;
        5)
            docker compose -f "$PROJECT_DIR/docker-compose.yml" ps
            ;;
        6)
            UPD_OK=0
            UPD_FAIL=0
            UPD_SKIP=0

            echo "===================================================="
            echo "   ComfyPack Update"
            echo "===================================================="
            echo ""

            echo "[1/6] Stopping containers..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" stop 2>/dev/null || true

            echo ""
            echo "[2/6] Updating scripts (git pull)..."
            if git -C "$PROJECT_DIR" pull --rebase --autostash 2>/dev/null; then
                ok "Scripts updated."
                ((UPD_OK++))
            else
                warn "Skip (downloaded as ZIP, or no updates available)."
                ((UPD_SKIP++))
            fi

            echo ""
            echo "[3/6] Updating Docker images..."
            if docker compose -f "$PROJECT_DIR/docker-compose.yml" pull 2>/dev/null; then
                ok "Images updated."
                ((UPD_OK++))
            else
                warn "Image pull failed or images not on Docker Hub yet."
                ((UPD_FAIL++))
            fi

            echo ""
            echo "[4/6] Updating custom nodes..."
            USER_NODES_DIR="$PROJECT_DIR/comfyui/user_nodes"
            HOOKING_APP_DIR="$PROJECT_DIR/hooking_server/app"

            echo ""
            echo "  Target: soya-custom-nodes=$SOYA_NODES_BRANCH, workflow=$WF_CONVERTER_BRANCH, hooking=$HOOKING_SERVER_BRANCH"
            echo "  Current:"
            if [ -d "$USER_NODES_DIR/comfyui-soya-custom-nodes/.git" ]; then
                BRANCH=$(git -C "$USER_NODES_DIR/comfyui-soya-custom-nodes" rev-parse --abbrev-ref HEAD 2>/dev/null)
                echo "    soya-custom-nodes: $BRANCH"
            fi
            if [ -d "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint/.git" ]; then
                BRANCH=$(git -C "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint" rev-parse --abbrev-ref HEAD 2>/dev/null)
                echo "    workflow-to-api-converter-endpoint: $BRANCH"
            fi
            if [ -d "$HOOKING_APP_DIR/.git" ]; then
                BRANCH=$(git -C "$HOOKING_APP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
                echo "    hooking_server: $BRANCH"
            fi
            echo ""

            if [ -d "$USER_NODES_DIR/comfyui-soya-custom-nodes/.git" ]; then
                echo "  - soya-custom-nodes..."
                git -C "$USER_NODES_DIR/comfyui-soya-custom-nodes" fetch --all 2>/dev/null
                git -C "$USER_NODES_DIR/comfyui-soya-custom-nodes" checkout "$SOYA_NODES_BRANCH" 2>/dev/null || git -C "$USER_NODES_DIR/comfyui-soya-custom-nodes" checkout -b "$SOYA_NODES_BRANCH" "origin/$SOYA_NODES_BRANCH"
                if git -C "$USER_NODES_DIR/comfyui-soya-custom-nodes" pull --rebase --autostash; then
                    ok "soya-custom-nodes updated"
                    ((UPD_OK++))
                else
                    fail "soya-custom-nodes update failed. Check for conflicts."
                    ((UPD_FAIL++))
                fi
            else
                warn "soya-custom-nodes not found. Skipping."
                ((UPD_SKIP++))
            fi

            if [ -d "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint/.git" ]; then
                echo "  - workflow-to-api-converter-endpoint..."
                git -C "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint" fetch --all 2>/dev/null
                git -C "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint" checkout "$WF_CONVERTER_BRANCH" 2>/dev/null || git -C "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint" checkout -b "$WF_CONVERTER_BRANCH" "origin/$WF_CONVERTER_BRANCH"
                if git -C "$USER_NODES_DIR/comfyui-workflow-to-api-converter-endpoint" pull --rebase --autostash; then
                    ok "workflow-to-api-converter-endpoint updated"
                    ((UPD_OK++))
                else
                    fail "workflow-to-api-converter-endpoint update failed."
                    ((UPD_FAIL++))
                fi
            else
                warn "workflow-to-api-converter-endpoint not found. Skipping."
                ((UPD_SKIP++))
            fi

            if [ -d "$HOOKING_APP_DIR/.git" ]; then
                echo "  - hooking_server..."
                git -C "$HOOKING_APP_DIR" fetch --all 2>/dev/null
                git -C "$HOOKING_APP_DIR" checkout "$HOOKING_SERVER_BRANCH" 2>/dev/null || git -C "$HOOKING_APP_DIR" checkout -b "$HOOKING_SERVER_BRANCH" "origin/$HOOKING_SERVER_BRANCH"
                if git -C "$HOOKING_APP_DIR" pull --rebase --autostash; then
                    ok "hooking_server updated"
                    ((UPD_OK++))
                else
                    fail "hooking_server update failed."
                    ((UPD_FAIL++))
                fi
            else
                warn "hooking_server not found. Skipping."
                ((UPD_SKIP++))
            fi

            echo ""
            echo "[5/6] Cleaning up old images..."
            docker image prune -f >/dev/null

            echo ""
            echo "[6/6] Restarting containers..."
            if docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d; then
                ok "Containers started."
                ((UPD_OK++))
            else
                fail "Failed to start containers."
                ((UPD_FAIL++))
            fi

            echo ""
            echo "===================================================="
            echo "   Update Results"
            echo "   OK: $UPD_OK   Failed: $UPD_FAIL   Skipped: $UPD_SKIP"
            echo "===================================================="
            echo ""

            if [ "$UPD_FAIL" -gt 0 ]; then
                warn "Some updates failed. The app may still work."
                echo "  Check the messages above for details."
            else
                ok "Update complete!"
                echo ""
                echo "  ComfyUI:        http://localhost:8188"
                echo "  Hooking Server:  http://localhost:8189"
            fi
            ;;
        7)
            echo ""
            echo "[!] Delete .env file?"
            echo "    It will be regenerated with defaults on next run."
            echo ""
            read -p "Are you sure? (y/N): " CONFIRM_RESET
            if [ "$CONFIRM_RESET" = "y" ] || [ "$CONFIRM_RESET" = "Y" ]; then
                rm -f "$ENV_FILE"
                ok ".env deleted. Run again to reconfigure."
            fi
            ;;
        8)
            echo "Removing ComfyPack (containers)..."
            docker compose -f "$PROJECT_DIR/docker-compose.yml" down
            ok "Containers removed. Select menu 3 to start again."
            ;;
        9)
            echo ""
            echo "[!] This will remove ComfyPack Docker images."
            echo "    Models, patch data, and config will be kept. Only images are removed."
            echo ""
            read -p "Are you sure? (y/N): " CONFIRM
            if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
                docker compose -f "$PROJECT_DIR/docker-compose.yml" down --rmi all
                echo ""
                ok "Images removed. Disk space freed."
                echo "  Use menu 1 or 2 to download images again."
                echo ""
                echo "Cleaning up remaining unused images..."
                docker image prune -f
            fi
            ;;
        0)
            exit 0
            ;;
    esac
done
