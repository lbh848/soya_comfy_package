@echo off
REM Prevent window from closing
if "%~1"=="_RUN_" goto main
start "ComfyPack" cmd /k "%~f0" _RUN_
goto :EOF

:main
chcp 65001 >nul 2>&1
title ComfyPack - Model Manager
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "MODELS_DIR=%SCRIPT_DIR%.."
cd /d "%MODELS_DIR%"
set "MODELS_DIR=%cd%\comfyui\models"

echo.
echo ==========================================================
echo    ComfyPack - Model Manager
echo    Folder: %MODELS_DIR%
echo ==========================================================
echo.
echo [Manual Download Required - download these first]
echo.
echo   checkpoints folder: comfyui/models/checkpoints/
echo     rinAnim8drawIllustrious_v31
echo     rinFlanimeIllustrious_v30
echo     (Search on HuggingFace)
echo.
echo   ipadapter folder: comfyui/models/ipadapter/
echo     noobIPAMARK1_mark1.safetensors
echo     https://civitai.com/models/1121145
echo.
echo   controlnet folder: comfyui/models/controlnet/
echo     illustriousXL_v10_openpose.safetensors
echo     https://civitai.com/models/1359846
echo.
echo   loras folder: comfyui/models/loras/
echo     dmd2_sdxl_4step_lora.safetensors
echo.
echo ==========================================================
echo.

:menu
echo.
echo   1. Download models (10 files, ~5-7GB)
echo   2. Delete downloaded models
echo   3. Show model status
echo   0. Exit
echo.
set "CHOICE="
set /p "CHOICE=Select [0-3]: "
if "%CHOICE%"=="1" goto download
if "%CHOICE%"=="2" goto delete
if "%CHOICE%"=="3" goto status
if "%CHOICE%"=="0" exit /b
goto menu

:: ==========================================================
:: STATUS
:: ==========================================================
:status
echo.
echo --- Model Status ---
echo.
set "FOUND=0"
set "MISSING=0"
for %%f in (
    "vae\qwen_image_vae.safetensors"
    "clip\qwen_3_06b_base.safetensors"
    "clip\ViT-L14.safetensors"
    "clip_vision\CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    "upscale_models\2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    "bbox\face_yolov8m.pt"
    "bbox\face_yolov8n.pt"
    "bbox\hand_yolov8s.pt"
    "bbox\eye_seg_v2.ckpt"
    "bbox\eyebrow_seg.ckpt"
) do (
    if exist "%MODELS_DIR%\%%~f" (
        echo   [OK] %%~f
        set /a FOUND+=1
    ) else (
        echo   [  ] %%~f
        set /a MISSING+=1
    )
)
echo.
echo   Found: %FOUND% / 10
echo.
pause
goto menu

:: ==========================================================
:: DOWNLOAD
:: ==========================================================
:download
echo.
set SUCCESS=0
set FAILED=0
set SKIPPED=0

where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] curl not found. Update Windows and try again.
    pause
    goto menu
)

for %%d in (checkpoints loras unet vae clip clip_vision ipadapter controlnet upscale_models bbox) do (
    if not exist "%MODELS_DIR%\%%d" mkdir "%MODELS_DIR%\%%d"
)

echo.
set "CONFIRM="
set /p "CONFIRM=Start download? (Y/N): "
if /i not "%CONFIRM%"=="Y" goto menu

echo.
echo Starting downloads...
echo.

:: --- #1 qwen_image_vae (vae) ---
set "FILE=%MODELS_DIR%\vae\qwen_image_vae.safetensors"
if exist "%FILE%" (
    echo [ 1/10] Skip - qwen_image_vae (exists)
    set /a SKIPPED+=1
) else (
    echo [ 1/10] Downloading - qwen_image_vae (Anima VAE)
    set "URL=https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #2 qwen_3_06b_base (clip) ---
set "FILE=%MODELS_DIR%\clip\qwen_3_06b_base.safetensors"
if exist "%FILE%" (
    echo [ 2/10] Skip - qwen_3_06b_base (exists)
    set /a SKIPPED+=1
) else (
    echo [ 2/10] Downloading - qwen_3_06b_base (Anima text encoder)
    set "URL=https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #3 ViT-L14 (clip) ---
set "FILE=%MODELS_DIR%\clip\ViT-L14.safetensors"
if exist "%FILE%" (
    echo [ 3/10] Skip - ViT-L14 (exists)
    set /a SKIPPED+=1
) else (
    echo [ 3/10] Downloading - ViT-L14 (Image feature extraction)
    set "URL=https://huggingface.co/sentence-transformers/clip-ViT-L-14/resolve/main/0_CLIPModel/model.safetensors"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #4 CLIP-ViT-bigG-14 (clip_vision) ---
set "FILE=%MODELS_DIR%\clip_vision\CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
if exist "%FILE%" (
    echo [ 4/10] Skip - CLIP-ViT-bigG-14 (exists)
    set /a SKIPPED+=1
) else (
    echo [ 4/10] Downloading - CLIP-ViT-bigG-14 (~3.5GB, largest file)
    set "URL=https://huggingface.co/axssel/IPAdapter_ClipVision_models/resolve/main/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #5 2x-AnimeSharpV4 (upscale_models) ---
set "FILE=%MODELS_DIR%\upscale_models\2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
if exist "%FILE%" (
    echo [ 5/10] Skip - 2x-AnimeSharpV4 (exists)
    set /a SKIPPED+=1
) else (
    echo [ 5/10] Downloading - 2x-AnimeSharpV4 (2x upscale)
    set "URL=https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/1a9339b5c308ab3990f6233be2c1169a75772878/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #6 face_yolov8m (bbox) ---
set "FILE=%MODELS_DIR%\bbox\face_yolov8m.pt"
if exist "%FILE%" (
    echo [ 6/10] Skip - face_yolov8m (exists)
    set /a SKIPPED+=1
) else (
    echo [ 6/10] Downloading - face_yolov8m (Face detection)
    set "URL=https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #7 face_yolov8n (bbox) ---
set "FILE=%MODELS_DIR%\bbox\face_yolov8n.pt"
if exist "%FILE%" (
    echo [ 7/10] Skip - face_yolov8n (exists)
    set /a SKIPPED+=1
) else (
    echo [ 7/10] Downloading - face_yolov8n (Face detection lightweight)
    set "URL=https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/face_yolov8n.pt"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #8 hand_yolov8s (bbox) ---
set "FILE=%MODELS_DIR%\bbox\hand_yolov8s.pt"
if exist "%FILE%" (
    echo [ 8/10] Skip - hand_yolov8s (exists)
    set /a SKIPPED+=1
) else (
    echo [ 8/10] Downloading - hand_yolov8s (Hand detection)
    set "URL=https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #9 eye_seg_v2 (bbox) ---
set "FILE=%MODELS_DIR%\bbox\eye_seg_v2.ckpt"
if exist "%FILE%" (
    echo [ 9/10] Skip - eye_seg_v2 (exists)
    set /a SKIPPED+=1
) else (
    echo [ 9/10] Downloading - eye_seg_v2 (Eye segmentation)
    set "URL=https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eye_seg_v2.ckpt"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

:: --- #10 eyebrow_seg (bbox) ---
set "FILE=%MODELS_DIR%\bbox\eyebrow_seg.ckpt"
if exist "%FILE%" (
    echo [10/10] Skip - eyebrow_seg (exists)
    set /a SKIPPED+=1
) else (
    echo [10/10] Downloading - eyebrow_seg (Eyebrow segmentation)
    set "URL=https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eyebrow_seg.ckpt"
    curl -L -# -C - -o "%FILE%" "!URL!"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if "!FSize:~6!"=="" (
                echo         Fail - corrupted
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         Done!
                set /a SUCCESS+=1
            )
        ) else (
            echo         Fail - file not created
            set /a FAILED+=1
        )
    ) else (
        echo         Fail!
        set /a FAILED+=1
    )
)

echo.
echo ==========================================================
echo    Results: OK=%SUCCESS%  Skip=%SKIPPED%  Fail=%FAILED%
echo ==========================================================
echo.
pause
goto menu

:: ==========================================================
:: DELETE
:: ==========================================================
:delete
echo.
echo --- Files to delete ---
echo.
set "DEL_COUNT=0"
set "DEL_SIZE=0"
for %%f in (
    "vae\qwen_image_vae.safetensors"
    "clip\qwen_3_06b_base.safetensors"
    "clip\ViT-L14.safetensors"
    "clip_vision\CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    "upscale_models\2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    "bbox\face_yolov8m.pt"
    "bbox\face_yolov8n.pt"
    "bbox\hand_yolov8s.pt"
    "bbox\eye_seg_v2.ckpt"
    "bbox\eyebrow_seg.ckpt"
) do (
    if exist "%MODELS_DIR%\%%~f" (
        echo   [X] %%~f
        set /a DEL_COUNT+=1
    )
)
echo.
if !DEL_COUNT!==0 (
    echo   No model files found to delete.
    echo.
    pause
    goto menu
)
echo   !DEL_COUNT! file(s) will be deleted.
echo.
set "CONFIRM="
set /p "CONFIRM=Delete all? (Y/N): "
if /i not "!CONFIRM!"=="Y" (
    echo Cancelled.
    pause
    goto menu
)

echo.
set "DELETED=0"
for %%f in (
    "vae\qwen_image_vae.safetensors"
    "clip\qwen_3_06b_base.safetensors"
    "clip\ViT-L14.safetensors"
    "clip_vision\CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    "upscale_models\2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    "bbox\face_yolov8m.pt"
    "bbox\face_yolov8n.pt"
    "bbox\hand_yolov8s.pt"
    "bbox\eye_seg_v2.ckpt"
    "bbox\eyebrow_seg.ckpt"
) do (
    if exist "%MODELS_DIR%\%%~f" (
        del "%MODELS_DIR%\%%~f" 2>nul
        if not exist "%MODELS_DIR%\%%~f" (
            echo   [OK] Deleted: %%~f
            set /a DELETED+=1
        ) else (
            echo   [FAIL] Could not delete: %%~f
        )
    )
)
echo.
echo   !DELETED! file(s) deleted.
echo.
pause
goto menu
