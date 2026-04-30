#!/bin/bash
# ComfyPack - Self Update Script
# Commits local changes and pulls latest version from GitHub

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[--]${NC} $1"; }
fail() { echo -e "  ${RED}[X]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "===================================================="
echo "   ComfyPack Self-Update"
echo "   This will commit your changes and pull the latest"
echo "   version from GitHub."
echo "===================================================="
echo ""
echo "  Project: $PROJECT_DIR"
echo ""

# --- Check git ---
if [ ! -d ".git" ]; then
    fail "This folder is not a git repository."
    echo "  Cannot update. You may have downloaded as ZIP."
    echo "  Download from GitHub for auto-update support."
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

cd "$PROJECT_DIR"

# --- Check for changes ---
CHANGES=$(git status --porcelain 2>/dev/null | wc -l)

echo "[1/2] Committing local changes..."
if [ "$CHANGES" -gt 0 ]; then
    git add -A
    git commit -m "auto-save before update" --allow-empty-message --no-gpg-sign
    if [ $? -eq 0 ]; then
        ok "Local changes saved."
    else
        warn "Nothing to commit, or commit skipped."
    fi
else
    warn "No local changes to save."
fi

echo ""
echo "[2/2] Pulling latest version from GitHub..."
if git pull --rebase --autostash; then
    echo ""
    echo "===================================================="
    echo "   [OK] Update complete!"
    echo "===================================================="
else
    echo ""
    echo "===================================================="
    echo "   [X] Update failed."
    echo "   Check the error messages above."
    echo "   You may need to resolve conflicts manually."
    echo "===================================================="
fi

echo ""
read -p "Press Enter to exit..."
