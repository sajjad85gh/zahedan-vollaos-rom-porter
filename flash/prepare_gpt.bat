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

echo Starting adb server. If Windows asks to allow adb through the firewall, click "Allow".
adb start-server
adb devices
echo.

set "BKARG="
if not "%~1"=="" goto :runsh
echo Before anything is changed, a backup of the original partition table can be saved in
echo a folder named gpt_backup_^<date^>-^<time^> next to this file. It is the only way to undo
echo the change later ^(prepare_gpt.bat --restore gpt_backup_...^).
set "BKANS="
set /p "BKANS=Save the backup? Type YES to save, NO to skip [YES]: "
set "BKARG=--backup"
if /i "%BKANS%"=="NO" set "BKARG=--no-backup"
:runsh
"%BASH%" "%~dp0prepare_gpt.sh" %BKARG% %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" echo prepare_gpt finished with errors ^(code %RC%^). Read the messages above. Do NOT boot Android if it says so.
pause
exit /b %RC%
