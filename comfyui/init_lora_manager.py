"""
Initialize ComfyUI-Lora-Manager settings with all model folder paths.
Runs on every container start - only creates/updates if settings are missing.
"""
import json
import os

SETTINGS_DIR = "/root/.config/ComfyUI-LoRA-Manager"
SETTINGS_FILE = os.path.join(SETTINGS_DIR, "settings.json")

MODEL_FOLDERS = {
    "loras": ["/app/comfyui/models/loras"],
    "checkpoints": ["/app/comfyui/models/checkpoints"],
    "unet": ["/app/comfyui/models/diffusion_models", "/app/comfyui/models/unet"],
    "embeddings": ["/app/comfyui/models/embeddings"],
    "controlnet": ["/app/comfyui/models/controlnet"],
    "ipadapter": ["/app/comfyui/models/ipadapter"],
    "upscale_models": ["/app/comfyui/models/upscale_models"],
    "vae": ["/app/comfyui/models/vae"],
    "clip": ["/app/comfyui/models/clip"],
    "clip_vision": ["/app/comfyui/models/clip_vision"],
}


def init_settings():
    os.makedirs(SETTINGS_DIR, exist_ok=True)

    settings = {}
    if os.path.isfile(SETTINGS_FILE):
        with open(SETTINGS_FILE) as f:
            settings = json.load(f)

    # Add missing folder paths
    changed = False
    for key, paths in MODEL_FOLDERS.items():
        if key not in settings.get("folder_paths", {}):
            settings.setdefault("folder_paths", {})[key] = paths
            changed = True

    # Also update libraries.comfyui.folder_paths
    lib = settings.setdefault("libraries", {}).setdefault("comfyui", {})
    for key, paths in MODEL_FOLDERS.items():
        if key not in lib.get("folder_paths", {}):
            lib.setdefault("folder_paths", {})[key] = paths
            changed = True

    if changed:
        with open(SETTINGS_FILE, "w") as f:
            json.dump(settings, f, indent=2)
        print("[init_lora_manager] Settings initialized with model folder paths")
    else:
        print("[init_lora_manager] Settings already configured")


if __name__ == "__main__":
    init_settings()
