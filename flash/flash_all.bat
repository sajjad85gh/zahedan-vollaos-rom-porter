@echo off
rem VollaOS (Quintus) for Daria Bond I - flash script (Windows)
rem Double-click this file from inside the extracted folder.
setlocal EnableExtensions

rem Re-launch inside a persistent window (cmd /k) so the output and any error
rem message never disappear, even if something crashes unexpectedly.
if /i not "%~1"=="--keep" (
    start "VollaOS flasher - Daria Bond I" cmd /k call "%~f0" --keep
    exit /b 0
)

cd /d "%~dp0"
title VollaOS flasher - Daria Bond I

set "FASTBOOT=%~dp0platform-tools\fastboot.exe"
if not exist "%FASTBOOT%" (
    echo [ERROR] platform-tools\fastboot.exe not found.
    echo         Make sure you extracted the whole archive and kept the platform-tools folder.
    goto :fail
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
    if not exist "%%F" (
        echo [ERROR] Missing file: %%F
        set "MISSING=1"
    )
)
if "%MISSING%"=="1" (
    echo.
    echo Some files are missing. Make sure you extracted the whole archive.
    goto :fail
)

echo WARNING: This will overwrite your device partitions.
echo Make sure the bootloader is unlocked and your important partitions are backed up.
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

call :run flash super super.img || goto :fail

call :run flash --slot=all preloader preloader.img || goto :fail
call :run flash --slot=all lk lk.img || goto :fail

call :run flash --slot=all md1img md1img.img || goto :fail
call :run flash --slot=all spmfw spmfw.img || goto :fail
call :run flash --slot=all pi_img pi_img.img || goto :fail
call :run flash --slot=all dpm dpm.img || goto :fail
call :run flash --slot=all scp scp.img || goto :fail
call :run flash --slot=all sspm sspm.img || goto :fail
call :run flash --slot=all mcupm mcupm.img || goto :fail
call :run flash --slot=all cam_vpu1 cam_vpu1.img || goto :fail
call :run flash --slot=all cam_vpu2 cam_vpu2.img || goto :fail
call :run flash --slot=all cam_vpu3 cam_vpu3.img || goto :fail
call :run flash --slot=all gz gz.img || goto :fail
call :run flash --slot=all tee tee.img || goto :fail

call :run flash --slot=all boot boot.img || goto :fail
call :run flash --slot=all dtbo dtbo.img || goto :fail
call :run flash --slot=all init_boot init_boot.img || goto :fail
call :run flash --slot=all vendor_boot vendor_boot.img || goto :fail

call :run flash --slot=all vbmeta vbmeta-disabled.img || goto :fail
call :run flash --slot=all vbmeta_system vbmeta-disabled.img || goto :fail
call :run flash --slot=all vbmeta_vendor vbmeta-disabled.img || goto :fail

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
