#!/bin/bash
# ComfyPack - Required Models Auto-Downloader (Linux)
# Downloads 13 model files needed for ComfyPack

set +e  # Don't exit on error - continue downloading remaining files

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SUCCESS=0
FAILED=0
SKIPPED=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/comfyui/models"

echo ""
echo "══════════════════════════════════════════════════════"
echo "   ComfyPack - Required Models Auto-Downloader"
echo "══════════════════════════════════════════════════════"
echo ""

# ─── 1. Check curl ──────────────────────────────────────
if ! command -v curl &>/dev/null; then
    echo -e "${RED}[X] curl not found. Please install it:${NC}"
    echo "    sudo apt install curl   # Debian/Ubuntu"
    echo "    sudo yum install curl   # CentOS/RHEL"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} curl is available"

# ─── 2. Check python3 (for Civitai API) ─────────────────
PYTHON_CMD=""
if command -v python3 &>/dev/null; then
    PYTHON_CMD="python3"
elif command -v python &>/dev/null; then
    PYTHON_CMD="python"
fi

# ─── 3. Set models directory ────────────────────────────
echo -e "${GREEN}[OK]${NC} Models folder: $MODELS_DIR"

# ─── 4. Create subdirectories ───────────────────────────
for dir in checkpoints loras unet vae clip clip_vision ipadapter controlnet upscale_models bbox; do
    mkdir -p "$MODELS_DIR/$dir"
done
echo -e "${GREEN}[OK]${NC} Folder structure ready"
echo ""

# ─── 5. Display file list ───────────────────────────────
echo "─── Files to Download ─────────────────────────────────"
echo ""
echo " [Core Image Generation]"
echo "  1. anima-preview2.safetensors         - Core Anima image generation model"
echo "  2. qwen_image_vae.safetensors         - Image encoding/decoding"
echo "  3. qwen_3_06b_base.safetensors        - Text understanding AI (prompt analysis)"
echo "  4. ViT-L14.safetensors                - Image feature extraction"
echo "  5. CLIP-ViT-bigG-14-... (~3.5GB)      - IPAdapter vision model"
echo ""
echo " [Upscaling / Detection]"
echo "  6. 2x-AnimeSharpV4_Fast_RCAN_PU       - Image quality enhancement (2x upscale)"
echo "  7. face_yolov8m.pt                    - Face detection (accurate)"
echo "  8. face_yolov8n.pt                    - Face detection (lightweight)"
echo "  9. hand_yolov8s.pt                    - Hand detection"
echo " 10. eye_seg_v2.ckpt                    - Eye segmentation (accurate)"
echo " 11. eyebrow_seg.ckpt                   - Eyebrow segmentation"
echo ""
echo " Total: 11 files (~8-10GB)"
echo " Already downloaded files will be skipped automatically."
echo ""

# ─── 6. User confirmation ───────────────────────────────
read -p "Start download? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Download cancelled."
    exit 0
fi

echo ""
echo "Starting downloads. This may take a while depending on your internet speed."
echo "If a download fails, the remaining files will still continue."
echo ""

# ══════════════════════════════════════════════════════════
# Download helper
# ══════════════════════════════════════════════════════════
download() {
    local file_path="$1"
    local url="$2"
    local desc="$3"
    local num="$4"

    if [ -f "$file_path" ]; then
        echo -e " [${num}/11] ${YELLOW}Skipping${NC} - $(basename "$file_path") (already exists)"
        ((SKIPPED++))
        return 0
    fi

    echo -e " [${num}/11] Downloading - $(basename "$file_path") (${desc})"
    curl -L -# -C - -o "$file_path" "$url"
    local rc=$?

    if [ $rc -eq 0 ] && [ -f "$file_path" ]; then
        local fsize=$(stat -c%s "$file_path" 2>/dev/null || echo 0)
        if [ "$fsize" -lt 1048576 ]; then
            echo -e "         ${RED}Failed - file corrupted${NC} (re-run to retry)"
            rm -f "$file_path" 2>/dev/null
            ((FAILED++))
        else
            echo "         Done!"
            ((SUCCESS++))
        fi
    else
        echo -e "         ${RED}Failed!${NC}"
        rm -f "$file_path" 2>/dev/null
        ((FAILED++))
    fi
}

# ══════════════════════════════════════════════════════════
# File Downloads
# ══════════════════════════════════════════════════════════

# #1 anima-preview2.safetensors (unet)
download "$MODELS_DIR/unet/anima-preview2.safetensors" \
    "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-preview2.safetensors" \
    "Core Anima image generation model" "1"

# #2 qwen_image_vae.safetensors (vae)
download "$MODELS_DIR/vae/qwen_image_vae.safetensors" \
    "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
    "Image encoding/decoding" "2"

# #3 qwen_3_06b_base.safetensors (clip)
download "$MODELS_DIR/clip/qwen_3_06b_base.safetensors" \
    "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors" \
    "Text understanding AI" "3"

# #4 ViT-L14.safetensors (clip)
download "$MODELS_DIR/clip/ViT-L14.safetensors" \
    "https://huggingface.co/sentence-transformers/clip-ViT-L-14/resolve/main/0_CLIPModel/model.safetensors" \
    "Image feature extraction" "4"

# #5 CLIP-ViT-bigG-14 (clip_vision) - largest file
FILE="$MODELS_DIR/clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
if [ -f "$FILE" ]; then
    echo -e " [ 5/11] ${YELLOW}Skipping${NC} - CLIP-ViT-bigG-14 (already exists)"
    ((SKIPPED++))
else
    echo -e " [ 5/11] Downloading - CLIP-ViT-bigG-14 (IPAdapter vision model, ${YELLOW}~3.5GB${NC})"
    echo "         * This is the largest file. It may take a long time."
    curl -L -# -C - -o "$FILE" "https://huggingface.co/axssel/IPAdapter_ClipVision_models/resolve/main/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    if [ $? -eq 0 ] && [ -f "$FILE" ]; then
        fsize=$(stat -c%s "$FILE" 2>/dev/null || echo 0)
        if [ "$fsize" -lt 1048576 ]; then
            echo -e "         ${RED}Failed - file corrupted${NC} (re-run to retry)"
            rm -f "$FILE" 2>/dev/null
            ((FAILED++))
        else
            echo "         Done!"
            ((SUCCESS++))
        fi
    else
        echo -e "         ${RED}Failed!${NC}"
        rm -f "$FILE" 2>/dev/null
        ((FAILED++))
    fi
fi

# #6 2x-AnimeSharpV4 (upscale_models)
download "$MODELS_DIR/upscale_models/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors" \
    "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/1a9339b5c308ab3990f6233be2c1169a75772878/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors" \
    "Image quality enhancement" "6"

# #7 face_yolov8m.pt (bbox)
download "$MODELS_DIR/bbox/face_yolov8m.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt" \
    "Face detection (accurate)" "7"

# #8 face_yolov8n.pt (bbox)
download "$MODELS_DIR/bbox/face_yolov8n.pt" \
    "https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/face_yolov8n.pt" \
    "Face detection (lightweight)" "8"

# #9 hand_yolov8s.pt (bbox)
download "$MODELS_DIR/bbox/hand_yolov8s.pt" \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt" \
    "Hand detection" "9"

# #10 eye_seg_v2.ckpt (bbox)
download "$MODELS_DIR/bbox/eye_seg_v2.ckpt" \
    "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eye_seg_v2.ckpt" \
    "Eye segmentation (accurate)" "10"

# #11 eyebrow_seg.ckpt (bbox)
download "$MODELS_DIR/bbox/eyebrow_seg.ckpt" \
    "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eyebrow_seg.ckpt" \
    "Eyebrow segmentation" "11"

# ══════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "   Download Results"
echo "══════════════════════════════════════════════════════"
echo ""
echo -e "   ${GREEN}Success:${NC}  $SUCCESS"
echo -e "   ${YELLOW}Skipped:${NC}  $SKIPPED (already exists)"
echo -e "   ${RED}Failed:${NC}   $FAILED"
echo ""

# ══════════════════════════════════════════════════════════
# Manual download instructions
# ══════════════════════════════════════════════════════════
echo "══════════════════════════════════════════════════════"
echo "   Manual Download Required"
echo "══════════════════════════════════════════════════════"
echo ""
echo " The following files cannot be auto-downloaded due to"
echo " copyright/login requirements. Please open each link"
echo " in your browser, download manually, and place in the"
echo " specified folder."
echo ""
echo " ─── Checkpoints (comfyui/models/checkpoints/) ──────"
echo ""
echo "  1. rinAnim8drawIllustrious_v31"
echo "     - Animation-style image generation checkpoint"
echo "     - Search and download from HuggingFace"
echo ""
echo "  2. rinFlanimeIllustrious_v30"
echo "     - Flat animation-style image generation checkpoint"
echo "     - Search and download from HuggingFace"
echo ""
echo " ─── IPAdapter (comfyui/models/ipadapter/) ────────"
echo ""
echo "  3. noobIPAMARK1_mark1.safetensors"
echo "     - Character face/style reference"
echo "     - Civitai login required: https://civitai.com/models/1121145"
echo ""
echo " ─── ControlNet (comfyui/models/controlnet/) ──────"
echo ""
echo "  4. illustriousXL_v10_openpose.safetensors"
echo "     - Pose control"
echo "     - Civitai login required: https://civitai.com/models/1159846"
echo ""
echo " ─── LoRA (comfyui/models/loras/) ─────────────────"
echo ""
echo "  5. dmd2_sdxl_4step_lora.safetensors"
echo "     - Image generation speedup (4-step acceleration)"
echo ""
echo "  * Additional LoRA files will be announced later."
echo ""
echo "══════════════════════════════════════════════════════"
echo ""
