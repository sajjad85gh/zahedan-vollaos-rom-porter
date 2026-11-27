@echo off
setlocal EnableExtensions

rem Keep the window open on double-click so output and errors never disappear.
if not defined _KEEP_OPEN (
    set "_KEEP_OPEN=1"
    start "VollaOS Dual-Boot GPT Tool" cmd /k call "%~f0" %*
    exit /b 0
)

cd /d "%~dp0"
title VollaOS Dual-Boot GPT Tool
set "NO_PAUSE=1"

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"

if not defined BASH (
    echo [ERROR] Git Bash not found. Install "Git for Windows" from https://git-scm.com/download/win
    echo         and run this file again. ^(WSL is not recommended: it cannot see the phone over USB.^)
    set "RC=1"
    goto :finish
)

if exist "%~dp0platform-tools\adb.exe" set "PATH=%~dp0platform-tools;%PATH%"

echo Starting adb server. If Windows asks to allow adb through the firewall, click "Allow".
adb start-server
adb devices
echo.

rem If arguments were passed via command line (e.g. --remove, --restore, --dry-run), forward directly.
if not "%~1"=="" goto :run_args

echo ================================================================
echo  Dual-Boot GPT Partition Tool - Daria Bond I ^(zahedan^)
echo ================================================================
echo   [1] Create Linux partitions ^(Dual-Boot setup^)
echo   [2] Remove Linux partitions ^& return all storage to Android ^(no backup needed^)
echo   [3] Restore original GPT from a gpt_backup_... folder
echo ================================================================
set "ACTION="
set /p "ACTION=Choose an option [1/2/3]: "
if "%ACTION%"=="1" goto :opt_create
if "%ACTION%"=="2" goto :opt_remove
if "%ACTION%"=="3" goto :opt_restore
echo Aborted.
set "RC=1"
goto :finish

:opt_create
echo.
echo A backup of the original partition table can be saved in gpt_backup_^<date^>-^<time^>.
set "BKANS="
set /p "BKANS=Save the backup? Type YES to save, NO to skip [YES]: "
set "BKARG=--backup"
if /i "%BKANS%"=="NO" set "BKARG=--no-backup"
"%BASH%" "%~dp0prepare_gpt.sh" %BKARG%
set "RC=%ERRORLEVEL%"
goto :finish

:opt_remove
echo.
"%BASH%" "%~dp0prepare_gpt.sh" --remove
set "RC=%ERRORLEVEL%"
goto :finish

:opt_restore
echo.
echo Available backup folders in this directory:
dir /b /ad "gpt_backup_*" 2>nul
if errorlevel 1 echo   ^(none found here^)
echo.
set "RDIR="
set /p "RDIR=Enter backup folder name ^(e.g. gpt_backup_20261127-120000^): "
if not defined RDIR (
    echo Aborted.
    set "RC=1"
    goto :finish
)
"%BASH%" "%~dp0prepare_gpt.sh" --restore "%RDIR%"
set "RC=%ERRORLEVEL%"
goto :finish

:run_args
"%BASH%" "%~dp0prepare_gpt.sh" %*
set "RC=%ERRORLEVEL%"

:finish
echo.
if not "%RC%"=="0" (
    echo ================================================================
    echo  prepare_gpt finished with errors ^(code %RC%^).
    echo  Read the messages above. Do NOT boot Android if it says so.
    echo  This window stays open so you can read or copy the output.
    echo ================================================================
) else (
    echo ================================================================
    echo  DONE. This window stays open; you can close it manually.
    echo ================================================================
)
exit /b %RC%
