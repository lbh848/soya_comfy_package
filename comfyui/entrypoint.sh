#!/bin/bash
set -e

echo "=== ComfyPack Entrypoint ==="

# Pre-import impact modules so user nodes can use them without circular import
python -c "
import sys
sys.path.insert(0, '/app/comfyui/custom_nodes/ComfyUI-Impact-Pack/modules')
try:
    import impact.core
    import impact.impact_pack
    import impact.segs_nodes
    import impact.utils
    print('[entrypoint] Impact modules pre-loaded OK')
except Exception as e:
    print(f'[entrypoint] Impact pre-load skip: {e}')
"

# Restore user-installed custom nodes from persisted snapshot
echo "[entrypoint] Restoring custom nodes from snapshot..."
python /app/restore_nodes.py

# Initialize LoRA Manager settings if missing
python /app/init_lora_manager.py

# Start ComfyUI
echo "[entrypoint] Starting ComfyUI..."
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header '*' --fast
