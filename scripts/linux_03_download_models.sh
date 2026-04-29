#!/bin/bash
# ComfyPack - Model Manager (via Docker, no host Python needed)
# Runs download_models.py inside Docker container.
# Models are stored in a Docker named volume (comfyui_models).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "=========================================================="
echo "    ComfyPack - Model Manager"
echo "=========================================================="
echo ""

# --- Check Docker ---
if ! command -v docker &>/dev/null; then
    echo -e "${RED}[X] Docker not found. Install it first:${NC}"
    echo "    https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${RED}[X] Docker is not running. Start it first.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Docker is running"

# --- Check docker compose ---
if ! docker compose version &>/dev/null; then
    echo -e "${RED}[X] docker compose not found (requires Docker Compose v2).${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# --- Menu ---
while true; do
    echo ""
    echo "  1. Download models (CivitAI + HuggingFace)"
    echo "  2. Show model status"
    echo "  3. Delete downloaded models"
    echo "  0. Exit"
    echo ""
    read -p "  Select [0-3]: " CHOICE

    case "$CHOICE" in
        1) CMD="download" ;;
        2) CMD="status" ;;
        3) CMD="delete" ;;
        0) echo "  Bye!"; exit 0 ;;
        *) continue ;;
    esac

    echo ""
    echo "  Launching model manager inside Docker..."
    echo ""

    docker compose run --rm --entrypoint python \
        -e CIVITAI_API_KEY \
        -v "$PROJECT_DIR/scripts:/scripts" \
        comfyui /scripts/download_models.py "$CMD" || {
        echo ""
        echo -e "  ${YELLOW}[!] Docker command failed. Is the ComfyUI image built?${NC}"
        echo "      Run the install script first."
    }
done
