@echo off
chcp 65001 >nul 2>&1
title ComfyPack - Auto Model Downloader
setlocal enabledelayedexpansion

:: Initialize counters
set SUCCESS=0
set FAILED=0
set SKIPPED=0

echo.
echo ══════════════════════════════════════════════════════
echo    ComfyPack - Required Models Auto-Downloader
echo ══════════════════════════════════════════════════════
echo.

:: ─── 1. Check curl ──────────────────────────────────────
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] curl not found.
    echo     It is included by default on Windows 10 and later.
    echo     Please update Windows and try again.
    pause
    exit /b 1
)
echo [OK] curl is available

:: ─── 2. Set models directory ────────────────────────────
set "SCRIPT_DIR=%~dp0"
set "MODELS_DIR=%SCRIPT_DIR%.."
cd /d "%MODELS_DIR%"
set "MODELS_DIR=%cd%\models"

echo [OK] Models folder: %MODELS_DIR%

:: ─── 3. Create subdirectories ───────────────────────────
for %%d in (unet vae clip clip_vision ipadapter controlnet upscale_models bbox) do (
    if not exist "%MODELS_DIR%\%%d" mkdir "%MODELS_DIR%\%%d"
)
echo [OK] Folder structure ready
echo.

:: ─── 4. Display file list ───────────────────────────────
echo ─── Files to Download ─────────────────────────────────
echo.
echo  [Core Image Generation]
echo   1. anima-preview2.safetensors         - Core Anima image generation model
echo   2. qwen_image_vae.safetensors         - Image encoding/decoding
echo   3. qwen_3_06b_base.safetensors        - Text understanding AI (prompt analysis)
echo   4. ViT-L14.safetensors                - Image feature extraction
echo   5. CLIP-ViT-bigG-14-... (~3.5GB)      - IPAdapter vision model
echo.
echo  [Character / Pose Control]
echo   6. noobIPAMARK1_mark1                 - Character face/style reference
echo   7. illustriousXL_v10_openpose         - Pose control
echo.
echo  [Upscaling / Detection]
echo   8. 2x-AnimeSharpV4_Fast_RCAN_PU       - Image quality enhancement (2x upscale)
echo   9. face_yolov8m.pt                    - Face detection (accurate)
echo  10. face_yolov8n.pt                    - Face detection (lightweight)
echo  11. hand_yolov8s.pt                    - Hand detection
echo  12. eye_seg_v2.ckpt                    - Eye segmentation (accurate)
echo  13. eyebrow_seg.ckpt                   - Eyebrow segmentation
echo.
echo  Total: 13 files (~8-10GB)
echo  Already downloaded files will be skipped automatically.
echo.

:: ─── 5. User confirmation ───────────────────────────────
set "CONFIRM="
set /p "CONFIRM=Start download? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo Download cancelled.
    pause
    exit /b 0
)

echo.
echo Starting downloads. This may take a while depending on your internet speed.
echo If a download fails, the remaining files will still continue.
echo.

:: ══════════════════════════════════════════════════════════
:: File Downloads
:: ══════════════════════════════════════════════════════════

:: ─── #1 anima-preview2.safetensors (unet) ────────────────
set "FILE=%MODELS_DIR%\unet\anima-preview2.safetensors"
if exist "%FILE%" (
    echo [ 1/13] Skipping - anima-preview2.safetensors (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 1/13] Downloading - anima-preview2.safetensors (Core Anima image generation model)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-preview2.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #2 qwen_image_vae.safetensors (vae) ─────────────────
set "FILE=%MODELS_DIR%\vae\qwen_image_vae.safetensors"
if exist "%FILE%" (
    echo [ 2/13] Skipping - qwen_image_vae.safetensors (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 2/13] Downloading - qwen_image_vae.safetensors (Image encoding/decoding)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #3 qwen_3_06b_base.safetensors (clip) ───────────────
set "FILE=%MODELS_DIR%\clip\qwen_3_06b_base.safetensors"
if exist "%FILE%" (
    echo [ 3/13] Skipping - qwen_3_06b_base.safetensors (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 3/13] Downloading - qwen_3_06b_base.safetensors (Text understanding AI)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #4 ViT-L14.safetensors (clip) ───────────────────────
set "FILE=%MODELS_DIR%\clip\ViT-L14.safetensors"
if exist "%FILE%" (
    echo [ 4/13] Skipping - ViT-L14.safetensors (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 4/13] Downloading - ViT-L14.safetensors (Image feature extraction)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/sentence-transformers/clip-ViT-L-14/resolve/main/0_CLIPModel/model.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #5 CLIP-ViT-bigG-14 (clip_vision) ───────────────────
set "FILE=%MODELS_DIR%\clip_vision\CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
if exist "%FILE%" (
    echo [ 5/13] Skipping - CLIP-ViT-bigG-14 (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 5/13] Downloading - CLIP-ViT-bigG-14 (IPAdapter vision model, ~3.5GB)
    echo         * This is the largest file. It may take a long time.
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/axssel/IPAdapter_ClipVision_models/resolve/main/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #6 noobIPAMARK1_mark1.safetensors (ipadapter) ───────
set "FILE=%MODELS_DIR%\ipadapter\noobIPAMARK1_mark1.safetensors"
if exist "%FILE%" (
    echo [ 6/13] Skipping - noobIPAMARK1_mark1 (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 6/13] Downloading - noobIPAMARK1_mark1 (Character face/style reference)
    curl -L -# -C - -o "%FILE%" "https://civitai.com/api/download/models/1121145?type=Model&format=SafeTensor"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #7 illustriousXL_v10_openpose (controlnet) ──────────
:: Query Civitai API for version ID, then download
set "FILE=%MODELS_DIR%\controlnet\illustriousXL_v10_openpose.safetensors"
if exist "%FILE%" (
    echo [ 7/13] Skipping - illustriousXL_v10_openpose (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 7/13] illustriousXL_v10_openpose (Pose control)
    echo         Fetching download info from Civitai...

    set "VERSION_ID="
    for /f "delims=" %%v in ('powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'https://civitai.com/api/v1/models/1359846' -UseBasicParsing -TimeoutSec 15; $j = $r.Content | ConvertFrom-Json; Write-Host $j.modelVersions[0].id } catch { Write-Host 'ERROR' }"') do set "VERSION_ID=%%v"

    if "!VERSION_ID!"=="ERROR" (
        echo         Civitai API lookup failed.
        echo         Please download manually:
        echo         https://civitai.com/models/1359846
        set /a FAILED+=1
    ) else if "!VERSION_ID!"=="" (
        echo         Could not find version ID.
        echo         Please download manually:
        echo         https://civitai.com/models/1359846
        set /a FAILED+=1
    ) else (
        echo         Version ID: !VERSION_ID! - Downloading...
        curl -L -# -C - -o "%FILE%" "https://civitai.com/api/download/models/!VERSION_ID!?type=Model&format=SafeTensor"
        if !errorlevel! equ 0 (
            if exist "%FILE%" (
                echo         Done!
                set /a SUCCESS+=1
            ) else (
                echo         Failed - file was not created.
                set /a FAILED+=1
            )
        ) else (
            echo         Failed!
            set /a FAILED+=1
        )
    )
)

:: ─── #8 2x-AnimeSharpV4 (upscale_models) ─────────────────
set "FILE=%MODELS_DIR%\upscale_models\2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
if exist "%FILE%" (
    echo [ 8/13] Skipping - 2x-AnimeSharpV4 (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 8/13] Downloading - 2x-AnimeSharpV4 (Image quality enhancement)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/1a9339b5c308ab3990f6233be2c1169a75772878/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #9 face_yolov8m.pt (bbox) ───────────────────────────
set "FILE=%MODELS_DIR%\bbox\face_yolov8m.pt"
if exist "%FILE%" (
    echo [ 9/13] Skipping - face_yolov8m.pt (already exists)
    set /a SKIPPED+=1
) else (
    echo [ 9/13] Downloading - face_yolov8m.pt (Face detection - accurate)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #10 face_yolov8n.pt (bbox) ──────────────────────────
set "FILE=%MODELS_DIR%\bbox\face_yolov8n.pt"
if exist "%FILE%" (
    echo [10/13] Skipping - face_yolov8n.pt (already exists)
    set /a SKIPPED+=1
) else (
    echo [10/13] Downloading - face_yolov8n.pt (Face detection - lightweight)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/face_yolov8n.pt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #11 hand_yolov8s.pt (bbox) ──────────────────────────
set "FILE=%MODELS_DIR%\bbox\hand_yolov8s.pt"
if exist "%FILE%" (
    echo [11/13] Skipping - hand_yolov8s.pt (already exists)
    set /a SKIPPED+=1
) else (
    echo [11/13] Downloading - hand_yolov8s.pt (Hand detection)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #12 eye_seg_v2.ckpt (bbox) ──────────────────────────
set "FILE=%MODELS_DIR%\bbox\eye_seg_v2.ckpt"
if exist "%FILE%" (
    echo [12/13] Skipping - eye_seg_v2.ckpt (already exists)
    set /a SKIPPED+=1
) else (
    echo [12/13] Downloading - eye_seg_v2.ckpt (Eye segmentation - accurate)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eye_seg_v2.ckpt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ─── #13 eyebrow_seg.ckpt (bbox) ─────────────────────────
set "FILE=%MODELS_DIR%\bbox\eyebrow_seg.ckpt"
if exist "%FILE%" (
    echo [13/13] Skipping - eyebrow_seg.ckpt (already exists)
    set /a SKIPPED+=1
) else (
    echo [13/13] Downloading - eyebrow_seg.ckpt (Eyebrow segmentation)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eyebrow_seg.ckpt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         Failed - file corrupted (re-run to retry)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Failed - file was not created.
            set /a FAILED+=1
        )
    ) else (
        echo         Failed!
        set /a FAILED+=1
    )
)

:: ══════════════════════════════════════════════════════════
:: Summary
:: ══════════════════════════════════════════════════════════
echo.
echo ══════════════════════════════════════════════════════
echo    Download Results
echo ══════════════════════════════════════════════════════
echo.
echo    Success:  %SUCCESS%
echo    Skipped:  %SKIPPED% (already exists)
echo    Failed:   %FAILED%
echo.

:: ══════════════════════════════════════════════════════════
:: Manual download instructions
:: ══════════════════════════════════════════════════════════
echo ══════════════════════════════════════════════════════
echo    Manual Download Required
echo ══════════════════════════════════════════════════════
echo.
echo  The following files cannot be auto-downloaded due to
echo  copyright restrictions. Please open each link in your
echo  browser, download manually, and place in the specified
echo  folder.
echo.
echo  ─── Checkpoints (models/checkpoints/) ─────────────
echo.
echo   1. rinAnim8drawIllustrious_v31
echo      - Animation-style image generation checkpoint
echo      - Search and download from HuggingFace
echo.
echo   2. rinFlanimeIllustrious_v30
echo      - Flat animation-style image generation checkpoint
echo      - Search and download from HuggingFace
echo.
echo  ─── LoRA (models/loras/) ────────────────────────
echo.
echo   3. dmd2_sdxl_4step_lora.safetensors
echo      - Image generation speedup (4-step acceleration)
echo.
echo   * Additional LoRA files will be announced later.
echo.
echo ══════════════════════════════════════════════════════
echo.
pause
