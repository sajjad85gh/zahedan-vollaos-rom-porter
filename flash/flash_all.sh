#!/usr/bin/env bash
# VollaOS (Quintus) for Daria Bond I - flash script (Linux / macOS)
# Run from inside the extracted folder:  bash flash_all.sh
set -uo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# If anything fails, keep the terminal open so the error can be read.
on_exit() {
  local code=$?
  if [ "$code" -ne 0 ] && [ -t 0 ]; then
    echo
    echo "================================================================"
    echo " FLASHING STOPPED (exit code $code). Read the error above."
    echo "================================================================"
    read -r -p "Press Enter to close..." _
  fi
}
trap on_exit EXIT

REQUIRED_FILES=(
  super.img preloader.img lk.img
  md1img.img spmfw.img pi_img.img dpm.img scp.img sspm.img mcupm.img
  cam_vpu1.img cam_vpu2.img cam_vpu3.img gz.img tee.img
  boot.img dtbo.img init_boot.img vendor_boot.img
  vbmeta-disabled.img
)

# Prefer bundled platform-tools if present, otherwise use the system fastboot.
if [ -x "./platform-tools/fastboot" ]; then
  FASTBOOT="./platform-tools/fastboot"
elif command -v fastboot >/dev/null 2>&1; then
  FASTBOOT="$(command -v fastboot)"
else
  echo "[ERROR] fastboot not found. Install platform-tools:"
  echo "        https://developer.android.com/tools/releases/platform-tools"
  exit 1
fi

echo "Using: $FASTBOOT"
"$FASTBOOT" --version | head -n 1
echo

missing=0
for f in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "[ERROR] Missing file: $f"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo
  echo "Some files are missing. Make sure you extracted the whole archive."
  exit 1
fi

echo "WARNING: This will overwrite your device partitions."
echo "Make sure the bootloader is unlocked and your important partitions are backed up."
read -r -p "Type YES to continue: " answer
[ "$answer" = "YES" ] || { echo "Aborted."; exit 1; }

echo
echo "Waiting for a device in fastboot mode..."
until "$FASTBOOT" devices 2>/dev/null | grep -q "fastboot"; do
  sleep 1
done
echo "Device found."

run() {
  echo
  echo ">> fastboot $*"
  if ! "$FASTBOOT" "$@"; then
    echo
    echo "[ERROR] 'fastboot $*' failed. Flashing stopped."
    echo "        Do NOT reboot into the system until this is resolved."
    exit 1
  fi
}

run flash super super.img

run flash --slot=all preloader preloader.img
run flash --slot=all lk lk.img

run flash --slot=all md1img md1img.img
run flash --slot=all spmfw spmfw.img
run flash --slot=all pi_img pi_img.img
run flash --slot=all dpm dpm.img
run flash --slot=all scp scp.img
run flash --slot=all sspm sspm.img
run flash --slot=all mcupm mcupm.img
run flash --slot=all cam_vpu1 cam_vpu1.img
run flash --slot=all cam_vpu2 cam_vpu2.img
run flash --slot=all cam_vpu3 cam_vpu3.img
run flash --slot=all gz gz.img
run flash --slot=all tee tee.img

run flash --slot=all boot boot.img
run flash --slot=all dtbo dtbo.img
run flash --slot=all init_boot init_boot.img
run flash --slot=all vendor_boot vendor_boot.img

run flash --slot=all vbmeta vbmeta-disabled.img
run flash --slot=all vbmeta_system vbmeta-disabled.img
run flash --slot=all vbmeta_vendor vbmeta-disabled.img

run erase frp

run --set-active=a
run reboot recovery

echo
echo "Done. The device is rebooting to recovery."
