@echo off
REM 창 자동 종료 방지 - 에러 발생 시 창이 유지됩니다
if "%~1"=="_RUN_" goto main
start "ComfyPack" cmd /k "%~f0" _RUN_
goto :EOF

:main
chcp 65001 >nul 2>&1
title ComfyPack - 필수 모델 자동 다운로드
setlocal enabledelayedexpansion

:: 카운터 초기화
set SUCCESS=0
set FAILED=0
set SKIPPED=0

echo.
echo ══════════════════════════════════════════════════════
echo    ComfyPack - 필수 모델 자동 다운로드
echo ══════════════════════════════════════════════════════
echo.

:: ─── 1. curl 확인 ────────────────────────────────────────
where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] curl을 찾을 수 없습니다.
    echo     Windows 10 이상에서는 기본 제공됩니다.
    echo     Windows 업데이트 후 다시 시도하세요.
    pause
    exit
)
echo [OK] curl 사용 가능

:: ─── 2. 모델 폴더 경로 설정 ──────────────────────────────
set "SCRIPT_DIR=%~dp0"
set "MODELS_DIR=%SCRIPT_DIR%.."
cd /d "%MODELS_DIR%"
set "MODELS_DIR=%cd%\models"

echo [OK] 모델 폴더: %MODELS_DIR%

:: ─── 3. 하위 폴더 생성 ──────────────────────────────────
for %%d in (checkpoints loras unet vae clip clip_vision ipadapter controlnet upscale_models bbox) do (
    if not exist "%MODELS_DIR%\%%d" mkdir "%MODELS_DIR%\%%d"
)
echo [OK] 폴더 구조 준비 완료
echo.

:: ─── 4. 다운로드할 파일 목록 표시 ───────────────────────
echo ─── 다운로드할 파일 목록 ──────────────────────────────
echo.
echo  [이미지 생성 핵심]
echo   1. anima-preview2.safetensors         - Anima 이미지 생성 핵심 모델
echo   2. qwen_image_vae.safetensors         - 이미지 인코딩/디코딩
echo   3. qwen text encoder 3.06B            - Text understanding AI
echo   4. ViT-L14.safetensors                - 이미지 특징 추출
echo   5. CLIP-ViT-bigG-14-... (~3.5GB)      - IPAdapter용 비전 모델
echo.
echo  [캐릭터/포즈 제어]
echo   6. noobIPAMARK1_mark1                 - 캐릭터 얼굴/스타일 참조
echo   7. illustriousXL_v10_openpose         - 포즈 제어용
echo.
echo  [화질 개선 / 감지]
echo   8. 2x-AnimeSharpV4_Fast_RCAN_PU       - 이미지 화질 개선 (2배 확대)
echo   9. face_yolov8m.pt                    - 얼굴 감지 (정밀형)
echo  10. face_yolov8n.pt                    - 얼굴 감지 (경량형)
echo  11. hand_yolov8s.pt                    - 손 감지
echo  12. eye_seg_v2.ckpt                    - 눈 segmentation (정밀형)
echo  13. eyebrow_seg.ckpt                   - 눈썹 segmentation
echo.
echo  총 13개 파일 (약 8~10GB)
echo  이미 다운로드된 파일은 자동으로 건너뜁니다.
echo.

:: ─── 5. 사용자 확인 ──────────────────────────────────────
set "CONFIRM="
set /p "CONFIRM=다운로드를 시작할까요? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo.
    echo 다운로드를 취소합니다.
    pause
    exit
)

echo.
echo 다운로드를 시작합니다. 인터넷 속도에 따라 시간이 걸릴 수 있습니다.
echo 중간에 실패해도 나머지 파일은 계속 다운로드합니다.
echo.

:: ══════════════════════════════════════════════════════════
:: 파일 다운로드
:: ══════════════════════════════════════════════════════════

:: ─── #1 anima-preview2.safetensors (unet) ────────────────
set "FILE=%MODELS_DIR%\unet\anima-preview2.safetensors"
if exist "%FILE%" (
    echo [ 1/13] 건너뛰기 - anima-preview2.safetensors (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 1/13] 다운로드 중 - anima-preview2.safetensors (Anima 이미지 생성 핵심 모델)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-preview2.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #2 qwen_image_vae.safetensors (vae) ─────────────────
set "FILE=%MODELS_DIR%\vae\qwen_image_vae.safetensors"
if exist "%FILE%" (
    echo [ 2/13] 건너뛰기 - qwen_image_vae.safetensors (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 2/13] 다운로드 중 - qwen_image_vae.safetensors (이미지 인코딩/디코딩)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #3 qwen_3_06b_base.safetensors (clip) ───────────────
set "FILE=%MODELS_DIR%\clip\qwen_3_06b_base.safetensors"
if exist "%FILE%" (
    echo [ 3/13] 건너뛰기 - qwen_3_06b_base.safetensors (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 3/13] 다운로드 중 - qwen_3_06b_base.safetensors (텍스트 이해 AI)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #4 ViT-L14.safetensors (clip) ───────────────────────
set "FILE=%MODELS_DIR%\clip\ViT-L14.safetensors"
if exist "%FILE%" (
    echo [ 4/13] 건너뛰기 - ViT-L14.safetensors (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 4/13] 다운로드 중 - ViT-L14.safetensors (이미지 특징 추출)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/sentence-transformers/clip-ViT-L-14/resolve/main/0_CLIPModel/model.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #5 CLIP-ViT-bigG-14 (clip_vision) ───────────────────
set "FILE=%MODELS_DIR%\clip_vision\CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
if exist "%FILE%" (
    echo [ 5/13] 건너뛰기 - CLIP-ViT-bigG-14 (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 5/13] 다운로드 중 - CLIP-ViT-bigG-14 (IPAdapter용 비전 모델, ~3.5GB)
    echo         * 이 파일이 가장 큽니다. 시간이 오래 걸릴 수 있습니다.
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/axssel/IPAdapter_ClipVision_models/resolve/main/CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #6 noobIPAMARK1_mark1.safetensors (ipadapter) ───────
set "FILE=%MODELS_DIR%\ipadapter\noobIPAMARK1_mark1.safetensors"
if exist "%FILE%" (
    echo [ 6/13] 건너뛰기 - noobIPAMARK1_mark1 (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 6/13] 다운로드 중 - noobIPAMARK1_mark1 (캐릭터 얼굴/스타일 참조)
    curl -L -# -C - -o "%FILE%" "https://civitai.com/api/download/models/1121145?type=Model&format=SafeTensor"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #7 illustriousXL_v10_openpose (controlnet) ──────────
:: Civitai API로 버전 ID 조회 후 다운로드
set "FILE=%MODELS_DIR%\controlnet\illustriousXL_v10_openpose.safetensors"
if exist "%FILE%" (
    echo [ 7/13] 건너뛰기 - illustriousXL_v10_openpose (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 7/13] illustriousXL_v10_openpose (포즈 제어용)
    echo         Civitai에서 다운로드 정보를 조회하는 중...

    set "VERSION_ID="
    for /f "delims=" %%v in ('powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri 'https://civitai.com/api/v1/models/1359846' -UseBasicParsing -TimeoutSec 15; $j = $r.Content | ConvertFrom-Json; Write-Host $j.modelVersions[0].id } catch { Write-Host 'ERROR' }"') do set "VERSION_ID=%%v"

    if "!VERSION_ID!"=="ERROR" (
        echo         Civitai API 조회 실패.
        echo         수동으로 다운로드해주세요:
        echo         https://civitai.com/models/1359846
        set /a FAILED+=1
    ) else if "!VERSION_ID!"=="" (
        echo         버전 ID를 찾을 수 없습니다.
        echo         수동으로 다운로드해주세요:
        echo         https://civitai.com/models/1359846
        set /a FAILED+=1
    ) else (
        echo         버전 ID: !VERSION_ID! - 다운로드 중...
        curl -L -# -C - -o "%FILE%" "https://civitai.com/api/download/models/!VERSION_ID!?type=Model&format=SafeTensor"
        if !errorlevel! equ 0 (
            if exist "%FILE%" (
                set "FSize=0"
                for %%s in ("!FILE!") do set "FSize=%%~zs"
                if !FSize! LSS 1048576 (
                    echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                    del "!FILE!" 2>nul
                    set /a FAILED+=1
                ) else (
                    echo         완료!
                    set /a SUCCESS+=1
                )
            ) else (
                echo         실패 - 파일이 생성되지 않았습니다.
                set /a FAILED+=1
            )
        ) else (
            echo         실패!
            set /a FAILED+=1
        )
    )
)

:: ─── #8 2x-AnimeSharpV4 (upscale_models) ─────────────────
set "FILE=%MODELS_DIR%\upscale_models\2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
if exist "%FILE%" (
    echo [ 8/13] 건너뛰기 - 2x-AnimeSharpV4 (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 8/13] 다운로드 중 - 2x-AnimeSharpV4 (이미지 화질 개선)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/1a9339b5c308ab3990f6233be2c1169a75772878/2x-AnimeSharpV4_Fast_RCAN_PU.safetensors"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #9 face_yolov8m.pt (bbox) ───────────────────────────
set "FILE=%MODELS_DIR%\bbox\face_yolov8m.pt"
if exist "%FILE%" (
    echo [ 9/13] 건너뛰기 - face_yolov8m.pt (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [ 9/13] 다운로드 중 - face_yolov8m.pt (얼굴 감지 - 정밀형)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #10 face_yolov8n.pt (bbox) ──────────────────────────
set "FILE=%MODELS_DIR%\bbox\face_yolov8n.pt"
if exist "%FILE%" (
    echo [10/13] 건너뛰기 - face_yolov8n.pt (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [10/13] 다운로드 중 - face_yolov8n.pt (얼굴 감지 - 경량형)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/face_yolov8n.pt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #11 hand_yolov8s.pt (bbox) ──────────────────────────
set "FILE=%MODELS_DIR%\bbox\hand_yolov8s.pt"
if exist "%FILE%" (
    echo [11/13] 건너뛰기 - hand_yolov8s.pt (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [11/13] 다운로드 중 - hand_yolov8s.pt (손 감지)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #12 eye_seg_v2.ckpt (bbox) ──────────────────────────
set "FILE=%MODELS_DIR%\bbox\eye_seg_v2.ckpt"
if exist "%FILE%" (
    echo [12/13] 건너뛰기 - eye_seg_v2.ckpt (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [12/13] 다운로드 중 - eye_seg_v2.ckpt (눈 segmentation - 정밀형)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eye_seg_v2.ckpt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ─── #13 eyebrow_seg.ckpt (bbox) ─────────────────────────
set "FILE=%MODELS_DIR%\bbox\eyebrow_seg.ckpt"
if exist "%FILE%" (
    echo [13/13] 건너뛰기 - eyebrow_seg.ckpt (이미 존재)
    set /a SKIPPED+=1
) else (
    echo [13/13] 다운로드 중 - eyebrow_seg.ckpt (눈썹 segmentation)
    curl -L -# -C - -o "%FILE%" "https://huggingface.co/byung-hyun/eye_segmentation_model/resolve/main/eyebrow_seg.ckpt"
    if !errorlevel! equ 0 (
        if exist "%FILE%" (
            set "FSize=0"
            for %%s in ("!FILE!") do set "FSize=%%~zs"
            if !FSize! LSS 1048576 (
                echo         실패 - 파일 손상 (다시 실행하면 재다운로드됩니다)
                del "!FILE!" 2>nul
                set /a FAILED+=1
            ) else (
                echo         완료!
                set /a SUCCESS+=1
            )
        ) else (
            echo         실패 - 파일이 생성되지 않았습니다.
            set /a FAILED+=1
        )
    ) else (
        echo         실패!
        set /a FAILED+=1
    )
)

:: ══════════════════════════════════════════════════════════
:: 결과 요약
:: ══════════════════════════════════════════════════════════
echo.
echo ══════════════════════════════════════════════════════
echo    다운로드 결과
echo ══════════════════════════════════════════════════════
echo.
echo    성공:  %SUCCESS%개
echo    건너뜀: %SKIPPED%개 (이미 존재)
echo    실패:  %FAILED%개
echo.

:: ══════════════════════════════════════════════════════════
:: 수동 다운로드 안내
:: ══════════════════════════════════════════════════════════
echo ══════════════════════════════════════════════════════
echo    수동 다운로드가 필요한 파일들
echo ══════════════════════════════════════════════════════
echo.
echo  아래 파일들은 저작권으로 인해 자동 다운로드가 불가합니다.
echo  각 링크를 브라우저에서 열어 수동으로 다운로드한 후,
echo  안내된 폴더에 넣어주세요.
echo.
echo  ─── 체크포인트 (models/checkpoints/) ─────────────
echo.
echo   1. rinAnim8drawIllustrious_v31
echo      - 애니메이션 스타일 이미지 생성용 기본 체크포인트
echo      - HuggingFace에서 검색 후 다운로드
echo.
echo   2. rinFlanimeIllustrious_v30
echo      - 플랫 애니메이션 스타일 이미지 생성용 체크포인트
echo      - HuggingFace에서 검색 후 다운로드
echo.
echo  ─── LoRA (models/loras/) ────────────────────────
echo.
echo   3. dmd2_sdxl_4step_lora.safetensors
echo      - 이미지 생성 속도 향상 (4단계 가속)
echo.
echo   ※ 나머지 LoRA 파일들은 추후 안내드립니다.
echo.
echo ══════════════════════════════════════════════════════
echo.
pause
