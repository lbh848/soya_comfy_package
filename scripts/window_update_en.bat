@echo off
if "%~1"=="_RUN_" goto main
start "ComfyPack Update" cmd /k "%~f0" _RUN_
goto :EOF

:main
chcp 65001 >nul 2>&1
title ComfyPack - Self Update
setlocal enabledelayedexpansion

:: --- Find project directory ---
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."
cd /d "%PROJECT_DIR%"
set "PROJECT_DIR=%cd%"

echo.
echo ====================================================
echo    ComfyPack Self-Update
echo    This will commit your changes and pull the latest
echo    version from GitHub.
echo ====================================================
echo.
echo  Project: %PROJECT_DIR%
echo.

:: --- Check git ---
if not exist ".git" (
    echo [X] This folder is not a git repository.
    echo     Cannot update. You may have downloaded as ZIP.
    echo     Download from GitHub for auto-update support.
    echo.
    pause
    exit /b
)

:: --- Check for changes ---
git status --porcelain >nul 2>&1
set "HAS_CHANGES=0"
for /f %%a in ('git status --porcelain 2^>nul ^| find /c /v ""') do set "HAS_CHANGES=%%a"

echo [1/2] Committing local changes...
if %HAS_CHANGES% gtr 0 (
    git add -A
    git commit -m "auto-save before update" --allow-empty-message --no-gpg-sign
    if !errorlevel! equ 0 (
        echo   [OK] Local changes saved.
    ) else (
        echo   [--] Nothing to commit, or commit skipped.
    )
) else (
    echo   [--] No local changes to save.
)

echo.
echo [2/2] Pulling latest version from GitHub...
git pull --rebase --autostash
if !errorlevel! equ 0 (
    echo.
    echo ====================================================
    echo    [OK] Update complete!
    echo ====================================================
) else (
    echo.
    echo ====================================================
    echo    [X] Update failed.
    echo    Check the error messages above.
    echo    You may need to resolve conflicts manually.
    echo ====================================================
)

echo.
pause
