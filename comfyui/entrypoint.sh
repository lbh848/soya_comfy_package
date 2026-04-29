#!/bin/bash
set -e

echo "=== ComfyPack Entrypoint ==="

# Restore user-installed custom nodes from persisted snapshot
echo "[entrypoint] Restoring custom nodes from snapshot..."
python /app/restore_nodes.py

# Start ComfyUI
echo "[entrypoint] Starting ComfyUI..."
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header '*' --fast
