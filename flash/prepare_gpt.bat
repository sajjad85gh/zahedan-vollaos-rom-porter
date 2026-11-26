@echo off
setlocal
cd /d "%~dp0"

rem Wrapper for prepare_gpt.sh on Windows. Needs Git for Windows (Git Bash) and Python 3.
rem Uses the bundled platform-tools (adb/fastboot) when present. Arguments are passed through,
rem e.g.  prepare_gpt.bat --dry-run   or   prepare_gpt.bat --linux-gib 64

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"

if not defined BASH (
    echo ERROR: Git Bash not found. Install "Git for Windows" from https://git-scm.com/download/win
    echo        and run this file again. ^(WSL is not recommended: it cannot see the phone over USB.^)
    pause
    exit /b 1
)

if exist "%~dp0platform-tools\adb.exe" set "PATH=%~dp0platform-tools;%PATH%"

"%BASH%" "%~dp0prepare_gpt.sh" %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo prepare_gpt finished with errors ^(code %RC%^). Read the messages above. Do NOT boot Android if it says so.
pause
exit /b %RC%
