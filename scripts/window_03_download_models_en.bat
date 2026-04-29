@echo off
REM ComfyPack - Model Manager (via Docker, no host Python needed)
if "%~1"=="_RUN_" goto main
start "ComfyPack Model Manager" cmd /k "%~f0" _RUN_
goto :EOF

:main
chcp 65001 >nul 2>&1
title ComfyPack - Model Manager
setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0.."
cd /d "%PROJECT_DIR%"

echo.
echo ==========================================================
echo    ComfyPack - Model Manager
echo ==========================================================
echo.

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Docker not found! Start Docker Desktop first.
    echo.
    pause
    exit /b
)

:menu
echo.
echo   1. Download models (CivitAI + HuggingFace)
echo   2. Show model status
echo   3. Delete downloaded models
echo   0. Exit
echo.
set "CHOICE="
set /p "CHOICE=Select [0-3]: "
if "%CHOICE%"=="1" goto run_download
if "%CHOICE%"=="2" goto run_status
if "%CHOICE%"=="3" goto run_delete
if "%CHOICE%"=="0" exit /b
goto menu

:: ==========================================================
:: Run Python script inside Docker container
:: ==========================================================
:run_download
call :docker_run download
goto menu

:run_status
call :docker_run status
goto menu

:run_delete
call :docker_run delete
goto menu

:: ==========================================================
:: Docker helper
:: ==========================================================
:docker_run
echo.
echo Launching...
echo.
docker compose run --rm --entrypoint python -e CIVITAI_API_KEY -v "%cd%\scripts:/scripts" comfyui /scripts/download_models.py %1
if %errorlevel% neq 0 (
    echo.
    echo [!] Docker command failed. Is the ComfyUI image built?
    echo     Run install script first: scripts\window_02_install_en.bat
)
echo.
pause
goto :EOF
