@echo off
:: Prevent window from closing on error
if "%~1"=="_RUN_" goto main
start "ComfyPack" cmd /k "%~f0" _RUN_
goto :EOF

:main
chcp 65001 >nul 2>&1
title ComfyPack - System Requirements Check
setlocal enabledelayedexpansion

echo.
echo ====================================================
echo    ComfyPack System Requirements Check
echo ====================================================
echo.
echo Checking your system. Please wait...
echo.

set "PASS=0"
set "WARN=0"
set "FAIL=0"

REM --- 1. WSL2 (required for Docker Desktop) ----------
echo [1/6] Checking WSL2 - Windows virtualization...
where wsl >nul 2>&1
if %errorlevel%==0 (
    echo   [OK] WSL is installed - Docker Desktop ready
    set /a "PASS+=1"
) else (
    echo   [XX] WSL is not installed
    echo       Fix: Open PowerShell as Administrator and run:
    echo       wsl --install
    echo       Then restart your computer.
    set /a "FAIL+=1"
)

REM --- 2. NVIDIA GPU --------------------------------------
echo.
echo [2/6] Checking NVIDIA GPU...
where nvidia-smi >nul 2>&1
if %errorlevel%==0 (
    REM GPU list - show all GPUs
    set "GPU_COUNT=0"
    for /f "delims=" %%a in ('nvidia-smi -L 2^>nul') do (
        echo   [OK] %%a
        set /a "GPU_COUNT+=1"
    )
    if !GPU_COUNT! GTR 0 set /a "PASS+=1"

    REM VRAM - show per GPU
    set "GPU_IDX=0"
    for /f "skip=1" %%a in ('nvidia-smi --query-gpu=memory.total --format=csv 2^>nul') do (
        set "VRAM=%%a"
        if defined VRAM (
            if !VRAM! GEQ 8000 (
                echo   [OK] GPU !GPU_IDX!: !VRAM! MB
            ) else if !VRAM! GEQ 4096 (
                echo   [--] GPU !GPU_IDX!: !VRAM! MB - 8GB+ recommended
                set /a "WARN+=1"
            ) else (
                echo   [XX] GPU !GPU_IDX!: !VRAM! MB - too low, 8GB+ required
                set /a "FAIL+=1"
            )
        )
        set /a "GPU_IDX+=1"
    )

    REM Driver version
    for /f "delims=" %%a in ('nvidia-smi -q -d DRIVER 2^>nul ^| findstr "Driver Version"') do echo       %%a
) else (
    echo   [XX] NVIDIA GPU not found
    echo       Make sure NVIDIA graphics drivers are installed.
    set /a "FAIL+=1"
)

REM --- 3. RAM ---------------------------------------------
echo.
echo [3/6] Checking memory - RAM...
set "RAM_GB="
for /f "delims=" %%a in ('powershell -NoProfile -Command "[math]::Ceiling((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)"') do set "RAM_GB=%%a"
if defined RAM_GB (
    if !RAM_GB! GEQ 32 (
        echo   [OK] RAM: !RAM_GB! GB
        set /a "PASS+=1"
    ) else if !RAM_GB! GEQ 16 (
        echo   [--] RAM: !RAM_GB! GB - 32GB+ recommended
        set /a "WARN+=1"
    ) else (
        echo   [XX] RAM: !RAM_GB! GB - 32GB+ required
        set /a "FAIL+=1"
    )
) else (
    echo   [--] Could not determine RAM size
    set /a "WARN+=1"
)

REM --- 4. Docker Desktop ----------------------------------
echo.
echo [4/6] Checking Docker Desktop...
where docker >nul 2>&1
if %errorlevel%==0 (
    docker info >nul 2>&1
    if !errorlevel!==0 (
        echo   [OK] Docker is installed and running
        set /a "PASS+=1"
        for /f "delims=" %%a in ('docker --version 2^>nul') do echo       %%a
    ) else (
        echo   [XX] Docker is installed but not running
        echo       Please start Docker Desktop.
        set /a "FAIL+=1"
    )
) else (
    echo   [XX] Docker is not installed
    echo       Download: https://www.docker.com/products/docker-desktop/
    set /a "FAIL+=1"
)

REM --- 5. NVIDIA Container Toolkit ------------------------
echo.
echo [5/6] Checking NVIDIA Container Toolkit...
set "DOCKER_RUNNING=0"
docker info >nul 2>&1
if !errorlevel!==0 set "DOCKER_RUNNING=1"

if "!DOCKER_RUNNING!"=="1" (
    set "HAS_NVIDIA=0"
    for /f "delims=" %%a in ('docker info 2^>nul ^| findstr /i "NVIDIA"') do set "HAS_NVIDIA=1"
    if "!HAS_NVIDIA!"=="1" (
        echo   [OK] NVIDIA Container Toolkit is installed
        set /a "PASS+=1"
    ) else (
        echo   [--] Could not verify NVIDIA Container Toolkit
        echo       Enable Docker Desktop Settings - General - Use the WSL 2 based engine
        echo       Latest Docker Desktop includes it by default.
        set /a "WARN+=1"
    )
) else (
    echo   [--] Docker is not running, cannot verify
    set /a "WARN+=1"
)

REM --- 6. Disk Space --------------------------------------
echo.
echo [6/6] Checking disk space...
set "DISK_GB="
for /f "delims=" %%a in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=''%~d0''').FreeSpace / 1GB)"') do set "DISK_GB=%%a"
if defined DISK_GB (
    if !DISK_GB! GEQ 50 (
        echo   [OK] Available disk space: !DISK_GB! GB
        set /a "PASS+=1"
    ) else if !DISK_GB! GEQ 25 (
        echo   [--] Available disk space: !DISK_GB! GB - 50GB+ recommended
        set /a "WARN+=1"
    ) else (
        echo   [XX] Available disk space: !DISK_GB! GB - 50GB+ required
        set /a "FAIL+=1"
    )
) else (
    echo   [--] Could not determine disk space
    set /a "WARN+=1"
)

REM --- Summary --------------------------------------------
echo.
echo ====================================================
echo    Check Complete
echo    Passed: !PASS!  Warnings: !WARN!  Failed: !FAIL!
echo ====================================================
echo.

if !FAIL! GTR 0 (
    echo [X] Some checks failed. Please fix the issues above and try again.
) else if !WARN! GTR 0 (
    echo [*] Some warnings found, but installation can proceed.
) else (
    echo [V] All checks passed! Run 02_install_en.bat to start installation.
)

echo.
pause
exit /b
