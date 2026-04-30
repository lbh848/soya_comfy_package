#!/usr/bin/env python3
"""ComfyPack Model Downloader - Batch download models from CivitAI / HuggingFace.

Scans ComfyUI workflow JSONs, identifies required models,
and downloads them with interactive version selection.

Runs inside Docker container (no host Python needed).
Host usage:
    docker compose run --rm --entrypoint python -v ./scripts:/scripts \
        -e CIVITAI_API_KEY comfyui /scripts/download_models.py
"""

import json
import os
import re
import sys
import time
from urllib.request import Request, urlopen, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse

# ═══════════════════════════════════════════════════════════════
# Paths - auto-detect Docker vs host
# ═══════════════════════════════════════════════════════════════

if os.path.isdir("/app/comfyui/models"):
    MODELS_DIR = "/app/comfyui/models"
    WORKFLOWS_DIR = "/app/comfyui/user/default/workflows"
else:
    _HERE = os.path.dirname(os.path.abspath(__file__))
    _PROJECT = os.path.dirname(_HERE)
    MODELS_DIR = os.path.join(_PROJECT, "comfyui", "models")
    WORKFLOWS_DIR = os.path.join(_PROJECT, "comfyui", "workflows")

API_KEY_FILE = os.path.join(MODELS_DIR, ".civitai_api_key")

# ═══════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════

CIVITAI_API = "https://civitai.com/api/v1"
CHUNK = 1024 * 1024  # 1MB
MAX_RETRY = 3
RETRY_WAIT = 2

# ═══════════════════════════════════════════════════════════════
# Node type → (category, widget index list)
# ═══════════════════════════════════════════════════════════════

NODE_MAP = {
    "CheckpointLoaderSimple":       ("checkpoints", [0]),
    "LoraLoader":                   ("loras", [0]),
    "LoraLoaderModelOnly":          ("loras", [0]),
    "ControlNetLoader":             ("controlnet", [0]),
    "CLIPVisionLoader":             ("clip_vision", [0]),
    "IPAdapterModelLoader":         ("ipadapter", [0]),
    "UltralyticsDetectorProvider":  ("ultralytics/bbox", [0]),
    "UpscaleModelLoader":           ("upscale_models", [0]),
    "SAM2ModelLoader":              ("sam2", [0]),
    "UNETLoader":                   ("unet", [0]),
    "CLIPLoader":                   ("clip", [0]),
    "VAELoader":                    ("vae", [0]),
}

# UUID proxy nodes - new ComfyUI node registration format
# 5b336ea5... = Anima checkpoint loader (unet + clip + vae)
UUID_LOADERS = {
    "5b336ea5-b353-4ea6-9868-9300e0d90d67": [
        ("unet", 0),
        ("clip", 1),
        ("vae", 2),
    ],
}

# ═══════════════════════════════════════════════════════════════
# CivitAI model name → model ID  (from 요구사항/다운링크(civitai).md)
# ═══════════════════════════════════════════════════════════════

CIVITAI = {
    # ── Checkpoint (SD/XL) ──
    "dxjmxIllus_x8": 1236206,
    "illustriousXL_v01": 795765,
    "nlxl_v10": 1296947,
    "rinAnim8drawIllustrious_v31": 1673823,
    "rinAnim8drawIllustrious_v40B": 1673823,
    "rinFlanimeIllustrious_v30": 1544647,
    "waiIllustriousSDXL_v160": 827184,
    "zukiCuteILL_v20": 949488,
    # ── Checkpoint (Anima) ──
    "anima-preview": 2359125,
    "animaOfficial_preview3Base": 2458426,
    "animayume_v02": 2385278,
    "AnimaYume_tuned_v04": 2385278,
    # ── LoRA (SDXL/ILL) ──
    "Detailed anime style": 1547435,
    "DrunkenDream1llust": 1175632,
    "Ebora_Style_Lora_Epoch10": 1796373,
    "Eye_Enhancer": 1731594,
    "Eyes_for_Illustrious_Lora_Perfect_anime_eyes": 1826240,
    "FComic_1to1000_IL_V2": 585589,
    "GBF_Illustrious": 478058,
    "IFL_v1.0_IL": 1060551,
    "K NAI Soft Style": 1801848,
    "Niji_oil_animme": 1188058,
    "OT2_v2-000011": 1151943,
    "ROSprites-10": 1043663,
    "SocratesaxStyle2-000009": 1413099,
    "[Style] Mosouko [Illustrious-XL]": 1222076,
    "[Style] Tian Zhu2357 [Illustrious-XL]": 1152066,
    "caststation animation": 940588,
    "dmd2_sdxl_4step_lora": 1608870,
    "dz_nbv_ashima_(roro046)-000320": 1847070,
    "flat": 128794,
    "ip-adapter-faceid-plusv2_sdxl_lora": 301797,
    "kuromoto2-000010": 1355243,
    "niji_and_midj_mix217": 1261988,
    "pornmaster-Aesthetics-v2-lora": 998657,
    "suujiniku": 1589205,
    # ── LoRA (Anima) ──
    "anima-highres-aesthetic-boost": 2540444,
    "anima-masterpieces-nlmix2-e41": 929497,
    "anima_preview3_rdbt_finetuned_v0.24_dmd2": 2364703,
    "anima_preview_rdbt_finetuned_cfg_distilled_v0.12": 2364703,
    "kieed-anima-lokr-000018": 2383428,
    "mixed_styles_anima_v2": 723360,
    # ── LyCORIS ──
    "nyalia": 834822,
    # ── Embedding ──
    "Smooth_Quality": 1065154,
    "lazyhand": 1302719,
    "lazympos": 1302719,
    "lazyneg": 1302719,
    "lazynsfw": 1302719,
    "lazypos": 1302719,
    "lazywet": 1302719,
    # ── ControlNet ──
    "noobaiXLControlnet": 929685,
    "illustriousXL_v10_openpose": 1359846,
    # ── IP-Adapter ──
    "noobIPAMARK1_mark1": 1000401,
    # ── Upscale ──
    "2x-AnimeSharpV4_Fast_RCAN_PU": 1245815,
}

# Hardcoded version IDs for models used in our workflows.
# If a version is removed from CivitAI, user picks an alternative.
# Format: model_name → (version_id, filename)
REQUIRED_VERSIONS = {
    # ── Checkpoints / UNET ──
    "animayume_v02":                         (2782261, "animayume_v02.safetensors"),
    "rinAnim8drawIllustrious_v31":           (2622009, "rinAnim8drawIllustrious_v31.safetensors"),
    "rinFlanimeIllustrious_v30":             (2710976, "rinFlanimeIllustrious_v30.safetensors"),
    # ── LoRA ──
    "dmd2_sdxl_4step_lora":                  (1820705, "dmd2_sdxl_4step_lora.safetensors"),
    "DrunkenDream1llust":                    (2773975, "DrunkenDream1llust.safetensors"),
    "FComic_1to1000_IL_V2":                  (2166652, "FComic_1to1000_IL_V2.safetensors"),
    "kieed-anima-lokr-000018":               (2680198, "kieed-anima-lokr-000018.safetensors"),
    "suujiniku":                             (1798353, "suujiniku.safetensors"),
    "anima_preview_rdbt_finetuned_cfg_distilled_v0.12": (2700939, "anima_preview_rdbt_finetuned_cfg_distilled_v0.12.safetensors"),
    # ── ControlNet ──
    "illustriousXL_v10_openpose":            (1536174, "illustriousXL_v10_openpose.safetensors"),
    # ── IP-Adapter ──
    "noobIPAMARK1_mark1":                    (1121145, "noobIPAMARK1_mark1.safetensors"),
}

# ═══════════════════════════════════════════════════════════════
# HuggingFace direct downloads: (rel_path, url, description)
# ═══════════════════════════════════════════════════════════════

HUGGINGFACE = [
    ("vae/qwen_image_vae.safetensors",
     "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors",
     "Anima VAE"),
    ("clip/qwen_3_06b_base.safetensors",
     "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors",
     "Anima text encoder"),
    ("clip_vision/ViT-L14.safetensors",
     "https://huggingface.co/sentence-transformers/clip-ViT-L-14/resolve/main/0_CLIPModel/model.safetensors",
     "CLIP ViT-L14"),
    ("clip_vision/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors",
     "https://huggingface.co/axssel/IPAdapter_ClipVision_models/resolve/main/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors",
     "CLIP ViT-bigG-14 (~3.5GB)"),
    ("upscale_models/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors",
     "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/1a9339b5c308ab3990f6233be2c1169a75772878/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors",
     "2x Anime upscaler"),
    ("ultralytics/bbox/face_yolov8m.pt",
     "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt",
     "Face detection (medium)"),
    ("ultralytics/bbox/face_yolov8n.pt",
     "https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/face_yolov8n.pt",
     "Face detection (nano)"),
    ("ultralytics/bbox/hand_yolov8s.pt",
     "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt",
     "Hand detection"),
    ("soya_seg/eye_seg_v2.ckpt",
     "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eye_seg_v2.ckpt",
     "Eye segmentation"),
    ("soya_seg/eyebrow_seg.ckpt",
     "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eyebrow_seg.ckpt",
     "Eyebrow segmentation"),
]

# Names to always skip (embedded in nodes, display names, etc.)
SKIP_NAMES = {"wd-vit-tagger-v3", "buffalo_l", "GroundingDINO"}


# ═══════════════════════════════════════════════════════════════
# HTTP helpers - strip auth on cross-origin redirects
# (CivitAI → S3 CDN fails if Authorization header leaks to S3)
# ═══════════════════════════════════════════════════════════════

class _StripAuthRedirect(HTTPRedirectHandler):
    """Follow redirects but strip Authorization header for cross-origin."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new_req = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new_req is not None:
            old_host = urlparse(req.full_url).hostname
            new_host = urlparse(newurl).hostname
            if old_host != new_host:
                # Remove auth header when redirecting to different host
                new_req.remove_header("Authorization")
        return new_req


_URL_OPENER = build_opener(_StripAuthRedirect)


# ═══════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════

def human_size(n):
    """Format bytes to human-readable string."""
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(n) < 1024:
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024
    return f"{n:.1f} PB"


def strip_ext(name):
    """Remove common model file extensions."""
    for ext in (".safetensors", ".ckpt", ".pt", ".pth", ".bin", ".onnx"):
        if name.lower().endswith(ext):
            return name[:-len(ext)]
    return name


def ask(prompt, default=""):
    """Get user input with optional default value."""
    hint = f" [{default}]" if default else ""
    try:
        return input(f"{prompt}{hint}: ").strip() or default
    except (EOFError, KeyboardInterrupt):
        print()
        return default


def _exists(category, name):
    """Check if any file matching name (with any extension) exists in category dir."""
    cat_dir = os.path.join(MODELS_DIR, category)
    if not os.path.isdir(cat_dir):
        return False
    for ext in (".safetensors", ".ckpt", ".pt", ".pth", ".bin"):
        if os.path.isfile(os.path.join(cat_dir, name + ext)):
            return True
    return False


# ═══════════════════════════════════════════════════════════════
# API Key management
# ═══════════════════════════════════════════════════════════════

def load_api_key():
    """Get CivitAI API key: env var → file → None."""
    key = os.environ.get("CIVITAI_API_KEY", "").strip()
    if key:
        return key
    try:
        with open(API_KEY_FILE) as f:
            key = f.read().strip()
    except (FileNotFoundError, OSError):
        pass
    return key


def save_api_key(key):
    """Persist API key to file (stored in models/ which is bind-mounted)."""
    os.makedirs(os.path.dirname(API_KEY_FILE), exist_ok=True)
    with open(API_KEY_FILE, "w") as f:
        f.write(key.strip())


def prompt_api_key():
    """Ask user for API key and save it."""
    print()
    print("  CivitAI API key required for downloading models.")
    print("  Get yours at: https://civitai.com/user/account")
    print()
    key = ask("  Enter API key (or press Enter to skip)")
    if key and len(key) > 5:
        save_api_key(key)
        print("  Key saved!")
        return key
    print("  Skipped - CivitAI downloads will be unavailable.")
    return None


# ═══════════════════════════════════════════════════════════════
# Workflow scanner
# ═══════════════════════════════════════════════════════════════

def scan_workflows():
    """Scan workflow JSONs and extract required models.

    Returns list of (name, category, workflow_file) tuples.
    """
    found = {}  # (name, cat) → workflow_name

    if not os.path.isdir(WORKFLOWS_DIR):
        print(f"  [!] Workflows dir not found: {WORKFLOWS_DIR}")
        return []

    wf_files = sorted(f for f in os.listdir(WORKFLOWS_DIR) if f.endswith(".json"))
    if not wf_files:
        print("  [!] No workflow JSON files found.")
        return []

    print(f"  Scanning {len(wf_files)} workflow(s)...")

    for wf_name in wf_files:
        try:
            with open(os.path.join(WORKFLOWS_DIR, wf_name), encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            print(f"  [!] {wf_name}: {e}")
            continue

        for node in data.get("nodes", []):
            ntype = node.get("type", "")
            widgets = node.get("widgets_values") or []

            # Skip bypassed/muted nodes (mode=4)
            if node.get("mode") == 4:
                continue

            # Known node types
            if ntype in NODE_MAP:
                cat, indices = NODE_MAP[ntype]
                for idx in indices:
                    if idx >= len(widgets):
                        continue
                    val = widgets[idx]
                    if not isinstance(val, str) or not val:
                        continue
                    # Skip absolute paths
                    if val.startswith("/") or re.match(r"^[A-Za-z]:", val):
                        continue
                    name = strip_ext(os.path.basename(val))
                    if name not in SKIP_NAMES:
                        found.setdefault((name, cat), wf_name)

            # Known UUID proxy nodes
            elif ntype in UUID_LOADERS:
                for cat, idx in UUID_LOADERS[ntype]:
                    if idx >= len(widgets):
                        continue
                    val = widgets[idx]
                    if not isinstance(val, str) or not val:
                        continue
                    if val.startswith("/") or re.match(r"^[A-Za-z]:", val):
                        continue
                    name = strip_ext(os.path.basename(val))
                    if name not in SKIP_NAMES:
                        found.setdefault((name, cat), wf_name)

    return [(n, c, w) for (n, c), w in sorted(found.items())]


# ═══════════════════════════════════════════════════════════════
# CivitAI API
# ═══════════════════════════════════════════════════════════════

def api_get(url, api_key, timeout=30):
    """GET request with auth, returns parsed JSON. Retries on 503/timeout."""
    headers = {"User-Agent": "ComfyPack/1.0"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    req = Request(url, headers=headers)
    for attempt in range(MAX_RETRY):
        try:
            with urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode())
        except HTTPError as e:
            if e.code in (503, 429) and attempt < MAX_RETRY - 1:
                time.sleep(RETRY_WAIT * (attempt + 1))
                continue
            raise
        except (URLError, OSError):
            if attempt < MAX_RETRY - 1:
                time.sleep(RETRY_WAIT)
                continue
            raise


def get_versions(model_id, api_key):
    """Fetch model versions from CivitAI API.

    Returns list of {id, name, date, files: [{name, size_kb, download_url}]}
    """
    data = api_get(f"{CIVITAI_API}/models/{model_id}", api_key)
    versions = []
    for v in data.get("modelVersions", []):
        files = []
        for f in v.get("files", []):
            if f.get("type") == "Model":
                files.append({
                    "name": f["name"],
                    "size_kb": f.get("sizeKB", 0),
                    "download_url": f.get("downloadUrl", ""),
                })
        versions.append({
            "id": v["id"],
            "name": v.get("name", "?"),
            "date": v.get("createdAt", "")[:10],
            "files": files,
        })
    return versions


def select_version(model_name, model_id, versions):
    """Interactive version selection with '(required)' marker.

    If a version is in REQUIRED_VERSIONS, it's marked and default-selected.
    Returns (version_id, filename, download_url) or (None, None, None).
    """
    print(f"\n  -- {model_name} (CivitAI #{model_id}) --")
    if not versions:
        print("  [!] No versions found.")
        return None, None, None

    # Find the required version for this model
    req_info = REQUIRED_VERSIONS.get(model_name)
    req_version_id = req_info[0] if req_info else None
    default_idx = 1  # default to first (latest)

    for i, v in enumerate(versions, 1):
        info = f"{v['name']}  ({v['date']})"
        if v["files"]:
            f = v["files"][0]
            size = human_size(f["size_kb"] * 1024) if f["size_kb"] else "?"
            info += f"  [{size}]"
        if v["id"] == req_version_id:
            info += "  (required)"
            default_idx = i
        print(f"    {i}. {info}")
    print(f"    0. Skip (don't download this model)")

    choice = ask("  Select version", str(default_idx))
    if choice in ("0", "s", "skip"):
        print("  Skipped.")
        return None, None, None
    try:
        idx = int(choice) - 1
        assert 0 <= idx < len(versions)
    except (ValueError, AssertionError):
        print("  Using default.")
        idx = default_idx - 1

    v = versions[idx]
    if not v["files"]:
        print("  [!] No model files in this version.")
        return None, None, None

    # Multiple files → pick one
    f = v["files"][0]
    if len(v["files"]) > 1:
        print("  Multiple files:")
        for j, fi in enumerate(v["files"], 1):
            size = human_size(fi["size_kb"] * 1024) if fi["size_kb"] else "?"
            print(f"    {j}. {fi['name']} ({size})")
        fc = ask("  Select file", "1")
        try:
            fi = int(fc) - 1
            assert 0 <= fi < len(v["files"])
            f = v["files"][fi]
        except (ValueError, AssertionError):
            pass

    return v["id"], f["name"], f.get("download_url", "")


# ═══════════════════════════════════════════════════════════════
# File downloader
# ═══════════════════════════════════════════════════════════════

def download_file(url, dest, api_key=None):
    """Download with progress bar, resume, and retry.

    Uses .downloading temp file, renames on success.
    Returns True on success.
    """
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".downloading"

    headers = {"User-Agent": "ComfyPack/1.0"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    # Resume support
    existing = 0
    if os.path.isfile(tmp):
        existing = os.path.getsize(tmp)
        if existing > 0:
            headers["Range"] = f"bytes={existing}-"

    for attempt in range(MAX_RETRY):
        try:
            req = Request(url, headers=headers)
            resp = _URL_OPENER.open(req, timeout=3600)

            # Check if server supports Range (206) or ignored it (200)
            if existing > 0 and resp.status == 200:
                existing = 0  # server sent full file, discard partial

            total = int(resp.headers.get("Content-Length", 0))
            if existing > 0 and total > 0:
                total += existing  # Range response gives remaining bytes

            done = existing
            mode = "ab" if existing > 0 else "wb"
            t0 = time.time()

            with open(tmp, mode) as out:
                while True:
                    chunk = resp.read(CHUNK)
                    if not chunk:
                        break
                    out.write(chunk)
                    done += len(chunk)
                    if total > 0:
                        pct = done * 100 // total
                        bar = "=" * (pct // 5) + "-" * (20 - pct // 5)
                        speed = (done - existing) / max(time.time() - t0, 0.01)
                        print(f"\r    [{bar}] {pct:3d}%  "
                              f"{human_size(done)}/{human_size(total)}  "
                              f"{human_size(speed)}/s  ", end="", flush=True)
                    else:
                        print(f"\r    Downloaded {human_size(done)}  ", end="", flush=True)

            print()  # newline after progress

            # Validate minimum size (> 1MB for model files)
            final_size = os.path.getsize(tmp)
            if final_size < 1024 * 1024:
                print(f"    [!] File too small ({human_size(final_size)}), likely corrupted.")
                os.remove(tmp)
                return False

            os.rename(tmp, dest)
            print(f"    Done! ({human_size(final_size)})")
            return True

        except HTTPError as e:
            if e.code in (503, 429) and attempt < MAX_RETRY - 1:
                print(f"\n    Server busy, retry {attempt + 1}/{MAX_RETRY}...")
                time.sleep(RETRY_WAIT * (attempt + 1))
                continue
            print(f"\n    [!] HTTP {e.code}: {e.reason}")
            return False
        except (URLError, OSError) as e:
            if attempt < MAX_RETRY - 1:
                print(f"\n    Network error, retry {attempt + 1}/{MAX_RETRY}...")
                time.sleep(RETRY_WAIT)
                continue
            print(f"\n    [!] Failed: {e}")
            return False

    return False


# ═══════════════════════════════════════════════════════════════
# Model registry - builds list of all known models
# ═══════════════════════════════════════════════════════════════

def build_model_list(wf_models=None):
    """Build unified list of all known models.

    Returns list of dicts:
      {name, source, category, relpath, desc}
    - source: "civitai" or "huggingface"
    - relpath: path relative to MODELS_DIR (or None for CivitAI)
    """
    models = []
    seen = set()

    # CivitAI models from workflows
    if wf_models:
        for name, cat, wf in wf_models:
            if name in CIVITAI and name not in seen:
                req = REQUIRED_VERSIONS.get(name)
                relpath = os.path.join(cat, req[1]) if req else None
                models.append({
                    "name": name,
                    "source": "civitai",
                    "category": cat,
                    "relpath": relpath,
                    "desc": f"CivitAI #{CIVITAI[name]}",
                })
                seen.add(name)

    # HuggingFace models (always included)
    for relpath, url, desc in HUGGINGFACE:
        name = strip_ext(os.path.basename(relpath))
        if name not in seen:
            models.append({
                "name": name,
                "source": "huggingface",
                "category": os.path.dirname(relpath),
                "relpath": relpath,
                "desc": desc,
            })
            seen.add(name)

    return models


def find_existing_file(category, name):
    """Find actual file on disk for a model. Returns abspath or None."""
    cat_dir = os.path.join(MODELS_DIR, category)
    if not os.path.isdir(cat_dir):
        return None
    for ext in (".safetensors", ".ckpt", ".pt", ".pth", ".bin"):
        p = os.path.join(cat_dir, name + ext)
        if os.path.isfile(p):
            return p
    return None


# ═══════════════════════════════════════════════════════════════
# Commands: status, delete, download
# ═══════════════════════════════════════════════════════════════

def cmd_status():
    """Show status of all known models."""
    wf_models = scan_workflows()
    models = build_model_list(wf_models)

    print(f"\n  Model Status ({len(models)} tracked):\n")

    found = missing = 0
    for m in models:
        if m["relpath"]:
            fpath = os.path.join(MODELS_DIR, m["relpath"])
            if os.path.isfile(fpath):
                tag = "OK "
                found += 1
            else:
                tag = "   "
                missing += 1
            size = human_size(os.path.getsize(fpath)) if os.path.isfile(fpath) else ""
            src = "CivitAI" if m["source"] == "civitai" else "HF"
            print(f"    [{tag}] {m['name']:<50s} [{src}] {size}")
        else:
            # CivitAI model without hardcoded filename - check by name
            existing = find_existing_file(m["category"], m["name"])
            if existing:
                tag = "OK "
                found += 1
                size = human_size(os.path.getsize(existing))
            else:
                tag = "   "
                missing += 1
                size = ""
            print(f"    [{tag}] {m['name']:<50s} [CivitAI] {size}")

    print(f"\n    Found: {found} / {len(models)}   Missing: {missing}")


def cmd_delete():
    """Delete all tracked model files."""
    wf_models = scan_workflows()
    models = build_model_list(wf_models)

    print("\n  Files to delete:\n")

    to_delete = []
    for m in models:
        if m["relpath"]:
            fpath = os.path.join(MODELS_DIR, m["relpath"])
            if os.path.isfile(fpath):
                size = human_size(os.path.getsize(fpath))
                print(f"    [X] {m['relpath']}  ({size})")
                to_delete.append(fpath)
        else:
            existing = find_existing_file(m["category"], m["name"])
            if existing:
                relpath = os.path.relpath(existing, MODELS_DIR)
                size = human_size(os.path.getsize(existing))
                print(f"    [X] {relpath}  ({size})")
                to_delete.append(existing)

    if not to_delete:
        print("    No tracked model files found to delete.")
        return

    print(f"\n    {len(to_delete)} file(s) will be deleted.")
    confirm = ask("    Delete all? (Y/N)", "N")
    if confirm.upper() != "Y":
        print("  Cancelled.")
        return

    print()
    deleted = 0
    for fpath in to_delete:
        try:
            os.remove(fpath)
            print(f"    Deleted: {os.path.relpath(fpath, MODELS_DIR)}")
            deleted += 1
        except OSError as e:
            print(f"    [FAIL] {os.path.relpath(fpath, MODELS_DIR)}: {e}")

    print(f"\n    {deleted} file(s) deleted.")


def cmd_download():
    """Interactive download flow."""
    # ── Step 1: Scan workflows ──
    print("\n  Step 1/4: Scanning workflows...")
    wf_models = scan_workflows()

    # Build lookup: model_name → HF download info
    hf_by_name = {}
    for relpath, url, desc in HUGGINGFACE:
        hf_by_name[strip_ext(os.path.basename(relpath))] = (relpath, url, desc)

    # ── Step 2: Classify models ──
    print(f"\n  Step 2/4: Classifying {len(wf_models)} model(s) + {len(HUGGINGFACE)} baseline HF...\n")

    # Collect CivitAI models from workflows
    civitai_models = []  # (name, cat, wf, model_id)
    civitai_seen = set()

    for name, cat, wf in wf_models:
        if name in CIVITAI and name not in civitai_seen:
            civitai_models.append((name, cat, wf, CIVITAI[name]))
            civitai_seen.add(name)

    # Collect ALL HF downloads (baseline + workflow-matched)
    hf_downloads = []  # (relpath, url, desc)
    hf_seen = set()

    # Always include all baseline HF models
    for relpath, url, desc in HUGGINGFACE:
        rp_key = strip_ext(os.path.basename(relpath))
        if rp_key not in hf_seen:
            hf_downloads.append((relpath, url, desc))
            hf_seen.add(rp_key)

    # Unknown models from workflows (no CivitAI or HF match)
    unknown = []
    all_known = civitai_seen | hf_seen | SKIP_NAMES
    for name, cat, wf in wf_models:
        if name not in all_known:
            unknown.append((name, cat, wf))

    # ── Display classification ──
    if civitai_models:
        print("  [CivitAI]")
        for name, cat, wf, mid in civitai_models:
            tag = "OK " if _exists(cat, name) else "   "
            print(f"    [{tag}] {name}  ({cat})  <- {wf}  [#{mid}]")

    if hf_downloads:
        print("\n  [HuggingFace]")
        for relpath, url, desc in hf_downloads:
            fpath = os.path.join(MODELS_DIR, relpath)
            tag = "OK " if os.path.isfile(fpath) else "   "
            print(f"    [{tag}] {os.path.basename(relpath)}  ({desc})")

    if unknown:
        print("\n  [Unknown - manual download required]")
        for name, cat, wf in unknown:
            print(f"    [?? ] {name}  ({cat})  <- {wf}")

    # ── Step 3: Filter to missing ──
    missing_civitai = [(n, c, w, m) for n, c, w, m in civitai_models
                       if not _exists(c, n)]
    missing_hf = [(rp, u, d) for rp, u, d in hf_downloads
                  if not os.path.isfile(os.path.join(MODELS_DIR, rp))]

    total_missing = len(missing_civitai) + len(missing_hf)
    if total_missing == 0:
        print("\n  All models present! Nothing to download.")
        return

    # ── Step 3: CivitAI version selection ──
    print(f"\n  Step 3/4: Version selection ({len(missing_civitai)} CivitAI model(s))...")

    downloads = []  # (source, name, url, dest_path, api_key, label)

    if missing_civitai:
        api_key = load_api_key()
        if not api_key:
            api_key = prompt_api_key()
        if not api_key:
            print("\n  [!] API key required for CivitAI. Skipping CivitAI downloads.")
            missing_civitai = []
        else:
            for name, cat, wf, mid in missing_civitai:
                try:
                    versions = get_versions(mid, api_key)
                except Exception as e:
                    print(f"\n  [!] {name}: API error - {e}")
                    continue

                vid, filename, dl_url = select_version(name, mid, versions)
                if vid is None:
                    continue

                # Use workflow-expected filename if known, otherwise CivitAI filename
                req = REQUIRED_VERSIONS.get(name)
                save_name = req[1] if req else filename
                dest = os.path.join(MODELS_DIR, cat, save_name)
                # Use downloadUrl from API if available, otherwise use standard endpoint
                if not dl_url:
                    dl_url = f"https://civitai.com/api/download/models/{vid}"
                downloads.append(("civitai", name, dl_url, dest, api_key, cat))

    # Add HF downloads (with skip option)
    for relpath, url, desc in missing_hf:
        name = strip_ext(os.path.basename(relpath))
        print(f"\n  -- {name} (HuggingFace) --")
        print(f"    {desc}")
        ans = ask("    Download? (Y=download / S=skip)", "Y")
        if ans.upper() in ("S", "N", "0"):
            print("    Skipped.")
            continue
        dest = os.path.join(MODELS_DIR, relpath)
        downloads.append(("hf", name, url, dest, None, desc))

    if not downloads:
        print("\n  Nothing to download.")
        return

    # ── Summary ──
    print(f"\n  Step 4/4: Download {len(downloads)} file(s)\n")
    print("  Download queue:")
    for source, name, url, dest, _, label in downloads:
        src = "CivitAI" if source == "civitai" else "HF"
        print(f"    [{src}] {name}  -> {label}")
    print()

    confirm = ask("  Start download? (Y/N)", "Y")
    if confirm.upper() != "Y":
        print("  Cancelled.")
        return

    # ── Download ──
    print()
    ok = skip = fail = 0
    total = len(downloads)

    for i, (source, name, url, dest, api_key, label) in enumerate(downloads, 1):
        # Rate limit: pause before CivitAI downloads
        if source == "civitai" and i > 1:
            print("    Waiting 4s to avoid rate limit...")
            time.sleep(4)

        print(f"  [{i}/{total}] {name}  ({label})")

        if os.path.isfile(dest):
            print("    Already exists, skipping.")
            skip += 1
            continue

        if download_file(url, dest, api_key=api_key):
            ok += 1
        else:
            fail += 1

    print()
    print("  ========================================")
    print(f"    Done!  OK={ok}  Skip={skip}  Fail={fail}")
    print("  ========================================")
    print()


# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

def main():
    print()
    print("  ========================================")
    print("       ComfyPack Model Downloader")
    print("  ========================================")
    print()

    # Command-line mode
    if len(sys.argv) > 1:
        cmd = sys.argv[1].lower()
        if cmd == "status":
            cmd_status()
        elif cmd == "delete":
            cmd_delete()
        elif cmd == "download":
            cmd_download()
        else:
            print(f"  Unknown command: {cmd}")
            print("  Usage: download_models.py [status|delete|download]")
        return

    # Interactive menu
    while True:
        print()
        print("  1. Download missing models (CivitAI + HuggingFace)")
        print("  2. Show model status")
        print("  3. Delete all downloaded models")
        print("  0. Exit")
        print()
        choice = ask("  Select", "0")
        if choice == "1":
            cmd_download()
        elif choice == "2":
            cmd_status()
        elif choice == "3":
            cmd_delete()
        elif choice in ("0", "q", ""):
            break

    print("  Bye!")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n  Cancelled by user.")
        sys.exit(1)
