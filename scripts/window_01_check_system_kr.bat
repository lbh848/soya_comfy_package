@echo off
chcp 65001 >nul 2>&1
title ComfyPack - 시스템 사양 확인
setlocal enabledelayedexpansion

echo.
echo ══════════════════════════════════════════════════════
echo    ComfyPack 시스템 요구사항 확인
echo ══════════════════════════════════════════════════════
echo.
echo 시스템 사양을 확인하고 있습니다. 잠시 기다려주세요...
echo.

set "PASS=0"
set "WARN=0"
set "FAIL=0"

REM ─── 1. WSL2 (Docker Desktop 필수) ────────────────────
echo [1/6] WSL2 - Windows 가상화 확인 중...
where wsl >nul 2>&1
if %errorlevel%==0 (
    echo   [OK] WSL 설치됨 - Docker Desktop 사용 가능
    set /a "PASS+=1"
) else (
    echo   [XX] WSL이 설치되지 않았습니다
    echo       해결 방법: 관리자 권한 PowerShell에서:
    echo       wsl --install
    echo       설치 후 컴퓨터를 재시작하세요.
    set /a "FAIL+=1"
)

REM ─── 2. NVIDIA GPU ──────────────────────────────────────
echo.
echo [2/6] NVIDIA GPU 확인 중...
where nvidia-smi >nul 2>&1
if %errorlevel%==0 (
    REM GPU 목록 - 모든 GPU 표시
    set "GPU_COUNT=0"
    for /f "delims=" %%a in ('nvidia-smi -L 2^>nul') do (
        echo   [OK] %%a
        set /a "GPU_COUNT+=1"
    )
    if !GPU_COUNT! GTR 0 set /a "PASS+=1"

    REM VRAM - 각 GPU별 표시
    set "GPU_IDX=0"
    for /f "skip=1" %%a in ('nvidia-smi --query-gpu=memory.total --format=csv 2^>nul') do (
        set "VRAM=%%a"
        if defined VRAM (
            if !VRAM! GEQ 8000 (
                echo   [OK] GPU !GPU_IDX!: !VRAM! MB
            ) else if !VRAM! GEQ 4096 (
                echo   [--] GPU !GPU_IDX!: !VRAM! MB - 8GB 이상 권장
                set /a "WARN+=1"
            ) else (
                echo   [XX] GPU !GPU_IDX!: !VRAM! MB - 너무 낮음, 8GB 이상 필요
                set /a "FAIL+=1"
            )
        )
        set /a "GPU_IDX+=1"
    )

    REM 드라이버 버전
    for /f "delims=" %%a in ('nvidia-smi -q -d DRIVER 2^>nul ^| findstr "Driver Version"') do echo       %%a
) else (
    echo   [XX] NVIDIA GPU를 찾을 수 없습니다
    echo       NVIDIA 그래픽 드라이버가 설치되어 있는지 확인하세요.
    set /a "FAIL+=1"
)

REM ─── 3. RAM ─────────────────────────────────────────────
echo.
echo [3/6] 메모리 - RAM 확인 중...
set "RAM_GB="
for /f "delims=" %%a in ('powershell -NoProfile -Command "[math]::Ceiling((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)"') do set "RAM_GB=%%a"
if defined RAM_GB (
    if !RAM_GB! GEQ 32 (
        echo   [OK] RAM: !RAM_GB! GB
        set /a "PASS+=1"
    ) else if !RAM_GB! GEQ 16 (
        echo   [--] RAM: !RAM_GB! GB - 32GB 이상 권장
        set /a "WARN+=1"
    ) else (
        echo   [XX] RAM: !RAM_GB! GB - 32GB 이상 필요
        set /a "FAIL+=1"
    )
) else (
    echo   [--] RAM 크기를 확인할 수 없습니다
    set /a "WARN+=1"
)

REM ─── 4. Docker Desktop ──────────────────────────────────
echo.
echo [4/6] Docker Desktop 확인 중...
where docker >nul 2>&1
if %errorlevel%==0 (
    docker info >nul 2>&1
    if !errorlevel!==0 (
        echo   [OK] Docker 설치됨 및 실행 중
        set /a "PASS+=1"
        for /f "delims=" %%a in ('docker --version 2^>nul') do echo       %%a
    ) else (
        echo   [XX] Docker가 설치되어 있지만 실행되지 않았습니다
        echo       Docker Desktop을 실행해주세요.
        set /a "FAIL+=1"
    )
) else (
    echo   [XX] Docker가 설치되어 있지 않습니다
    echo       다운로드: https://www.docker.com/products/docker-desktop/
    set /a "FAIL+=1"
)

REM ─── 5. NVIDIA Container Toolkit ────────────────────────
echo.
echo [5/6] NVIDIA Container Toolkit 확인 중...
set "DOCKER_RUNNING=0"
docker info >nul 2>&1
if !errorlevel!==0 set "DOCKER_RUNNING=1"

if "!DOCKER_RUNNING!"=="1" (
    set "HAS_NVIDIA=0"
    for /f "delims=" %%a in ('docker info 2^>nul ^| findstr /i "NVIDIA"') do set "HAS_NVIDIA=1"
    if "!HAS_NVIDIA!"=="1" (
        echo   [OK] NVIDIA Container Toolkit 설치됨
        set /a "PASS+=1"
    ) else (
        echo   [--] NVIDIA Container Toolkit 확인 불가
        echo       Docker Desktop 설정 - General - Use the WSL 2 based engine 활성화
        echo       최신 Docker Desktop에서는 기본 포함되어 있습니다.
        set /a "WARN+=1"
    )
) else (
    echo   [--] Docker가 실행 중이 아니라 확인할 수 없습니다
    set /a "WARN+=1"
)

REM ─── 6. 디스크 공간 ─────────────────────────────────────
echo.
echo [6/6] 디스크 공간 확인 중...
set "DISK_GB="
for /f "delims=" %%a in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter 'DeviceID=''%~d0''').FreeSpace / 1GB)"') do set "DISK_GB=%%a"
if defined DISK_GB (
    if !DISK_GB! GEQ 50 (
        echo   [OK] 사용 가능한 디스크 공간: !DISK_GB! GB
        set /a "PASS+=1"
    ) else if !DISK_GB! GEQ 25 (
        echo   [--] 사용 가능한 디스크 공간: !DISK_GB! GB - 50GB 이상 권장
        set /a "WARN+=1"
    ) else (
        echo   [XX] 사용 가능한 디스크 공간: !DISK_GB! GB - 50GB 이상 필요
        set /a "FAIL+=1"
    )
) else (
    echo   [--] 디스크 공간을 확인할 수 없습니다
    set /a "WARN+=1"
)

REM ─── 결과 요약 ──────────────────────────────────────────
echo.
echo ══════════════════════════════════════════════════════
echo    확인 완료
echo    통과: !PASS!  경고: !WARN!  실패: !FAIL!
echo ══════════════════════════════════════════════════════
echo.

if !FAIL! GTR 0 (
    echo [X] 실패 항목이 있습니다. 위 안내에 따라 해결 후 다시 확인해주세요.
) else if !WARN! GTR 0 (
    echo [*] 경고 항목이 있지만 설치는 진행할 수 있습니다.
) else (
    echo [V] 모든 항목이 통과했습니다. 02_install_kr.bat을 실행하세요.
)

echo.
pause
exit /b 0
