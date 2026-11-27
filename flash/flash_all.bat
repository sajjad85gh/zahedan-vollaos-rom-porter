@echo off
rem VollaOS (Quintus) for Daria Bond I - flash script (Windows)
rem Double-click this file from inside the extracted folder.
setlocal EnableExtensions

rem Re-launch inside a persistent window (cmd /k) so the output and any error
rem message never disappear, even if something crashes unexpectedly.
if not defined _KEEP_OPEN (
    set "_KEEP_OPEN=1"
    start "VollaOS flasher - Daria Bond I" cmd /k call "%~f0" %*
    exit /b 0
)

cd /d "%~dp0"
title VollaOS flasher - Daria Bond I

set "OS_DIR=OS"
set "FASTBOOT=%~dp0platform-tools\fastboot.exe"
if not exist "%FASTBOOT%" (
    where fastboot >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] platform-tools\fastboot.exe not found and fastboot is not in PATH.
        echo         Make sure you extracted the whole archive and kept the platform-tools folder.
        goto :fail
    )
    set "FASTBOOT=fastboot"
)

echo Using: %FASTBOOT%
"%FASTBOOT%" --version
echo.

set "MISSING=0"
for %%F in (
    super.img preloader.img lk.img
    md1img.img spmfw.img pi_img.img dpm.img scp.img sspm.img mcupm.img
    cam_vpu1.img cam_vpu2.img cam_vpu3.img gz.img tee.img
    boot.img dtbo.img init_boot.img vendor_boot.img
    vbmeta-disabled.img
) do (
    if not exist "%OS_DIR%\%%F" (
        echo [ERROR] Missing file: %OS_DIR%\%%F
        set "MISSING=1"
    )
)
if "%MISSING%"=="1" (
    echo.
    echo Some files are missing inside "%OS_DIR%\". Make sure you extracted the whole archive.
    goto :fail
)

echo WARNING: This will overwrite your device partitions.
echo Make sure the bootloader is unlocked and your important partitions are backed up.
echo Note: "Failed to fetch first 1048576 bytes of super partition" on newer fastboot is harmless.
set "ANSWER="
set /p "ANSWER=Type YES to continue: "
if /i not "%ANSWER%"=="YES" (
    echo Aborted.
    goto :fail
)

echo.
echo Waiting for a device in fastboot mode...
:waitdev
"%FASTBOOT%" devices 2>nul | findstr /i "fastboot" >nul
if errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto :waitdev
)
echo Device found.

call :run flash super "%OS_DIR%\super.img" || goto :fail

call :run flash --slot=all preloader "%OS_DIR%\preloader.img" || goto :fail
call :run flash --slot=all lk "%OS_DIR%\lk.img" || goto :fail

call :run flash --slot=all md1img "%OS_DIR%\md1img.img" || goto :fail
call :run flash --slot=all spmfw "%OS_DIR%\spmfw.img" || goto :fail
call :run flash --slot=all pi_img "%OS_DIR%\pi_img.img" || goto :fail
call :run flash --slot=all dpm "%OS_DIR%\dpm.img" || goto :fail
call :run flash --slot=all scp "%OS_DIR%\scp.img" || goto :fail
call :run flash --slot=all sspm "%OS_DIR%\sspm.img" || goto :fail
call :run flash --slot=all mcupm "%OS_DIR%\mcupm.img" || goto :fail
call :run flash --slot=all cam_vpu1 "%OS_DIR%\cam_vpu1.img" || goto :fail
call :run flash --slot=all cam_vpu2 "%OS_DIR%\cam_vpu2.img" || goto :fail
call :run flash --slot=all cam_vpu3 "%OS_DIR%\cam_vpu3.img" || goto :fail
call :run flash --slot=all gz "%OS_DIR%\gz.img" || goto :fail
call :run flash --slot=all tee "%OS_DIR%\tee.img" || goto :fail

call :run flash --slot=all boot "%OS_DIR%\boot.img" || goto :fail
call :run flash --slot=all dtbo "%OS_DIR%\dtbo.img" || goto :fail
call :run flash --slot=all init_boot "%OS_DIR%\init_boot.img" || goto :fail
call :run flash --slot=all vendor_boot "%OS_DIR%\vendor_boot.img" || goto :fail

call :run flash --slot=all vbmeta "%OS_DIR%\vbmeta-disabled.img" || goto :fail
call :run flash --slot=all vbmeta_system "%OS_DIR%\vbmeta-disabled.img" || goto :fail
call :run flash --slot=all vbmeta_vendor "%OS_DIR%\vbmeta-disabled.img" || goto :fail

call :run erase frp || goto :fail

call :run --set-active=a || goto :fail
call :run reboot recovery || goto :fail

echo.
echo ================================================================
echo  DONE. The device is rebooting to recovery.
echo  You can close this window now.
echo ================================================================
exit /b 0

:run
echo.
echo ^>^> fastboot %*
"%FASTBOOT%" %*
if errorlevel 1 (
    echo.
    echo [ERROR] "fastboot %*" failed with exit code %errorlevel%.
    exit /b 1
)
exit /b 0

:fail
echo.
echo ================================================================
echo  FLASHING STOPPED. Read the error message above.
echo  Do NOT reboot into the system until this is resolved.
echo  This window stays open so you can read or copy the text.
echo ================================================================
exit /b 1
