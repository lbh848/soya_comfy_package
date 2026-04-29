#!/bin/bash
set -e

echo "[hooking_server] Checking dependencies..."
pip install -q -r requirements.txt 2>/dev/null || true

echo "[hooking_server] Starting server..."
exec python server.py
