#!/usr/bin/env bash
# VollaOS (Quintus) for Daria Bond I - flash script (Linux / macOS)
# Run from inside the extracted folder:  bash flash_all.sh
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OS_DIR="OS"

# Always keep the terminal open on exit (both success and error) so logs can be read.
on_exit() {
  local code=$?
  echo
  if [ "$code" -ne 0 ]; then
    echo "================================================================"
    echo " FLASHING STOPPED (exit code $code). Read the error above."
    echo "================================================================"
  else
    echo "================================================================"
    echo " DONE. The device is rebooting to recovery."
    echo "================================================================"
  fi
  if [ -z "${NO_PAUSE:-}" ] && { [ -t 0 ] || [ -t 1 ]; } && [ -e /dev/tty ]; then
    read -r -p "Press Enter to close..." _ </dev/tty 2>/dev/null || true
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
  if [ ! -f "$OS_DIR/$f" ]; then
    echo "[ERROR] Missing file: $OS_DIR/$f"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo
  echo "Some files are missing inside '$OS_DIR/'. Make sure you extracted the whole archive."
  exit 1
fi

echo "WARNING: This will overwrite your device partitions."
echo "Make sure the bootloader is unlocked and your important partitions are backed up."
echo "Note: 'Failed to fetch first 1048576 bytes of super partition' on newer fastboot is harmless."
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

run flash super "$OS_DIR/super.img"

run flash --slot=all preloader "$OS_DIR/preloader.img"
run flash --slot=all lk "$OS_DIR/lk.img"

run flash --slot=all md1img "$OS_DIR/md1img.img"
run flash --slot=all spmfw "$OS_DIR/spmfw.img"
run flash --slot=all pi_img "$OS_DIR/pi_img.img"
run flash --slot=all dpm "$OS_DIR/dpm.img"
run flash --slot=all scp "$OS_DIR/scp.img"
run flash --slot=all sspm "$OS_DIR/sspm.img"
run flash --slot=all mcupm "$OS_DIR/mcupm.img"
run flash --slot=all cam_vpu1 "$OS_DIR/cam_vpu1.img"
run flash --slot=all cam_vpu2 "$OS_DIR/cam_vpu2.img"
run flash --slot=all cam_vpu3 "$OS_DIR/cam_vpu3.img"
run flash --slot=all gz "$OS_DIR/gz.img"
run flash --slot=all tee "$OS_DIR/tee.img"

run flash --slot=all boot "$OS_DIR/boot.img"
run flash --slot=all dtbo "$OS_DIR/dtbo.img"
run flash --slot=all init_boot "$OS_DIR/init_boot.img"
run flash --slot=all vendor_boot "$OS_DIR/vendor_boot.img"

run flash --slot=all vbmeta "$OS_DIR/vbmeta-disabled.img"
run flash --slot=all vbmeta_system "$OS_DIR/vbmeta-disabled.img"
run flash --slot=all vbmeta_vendor "$OS_DIR/vbmeta-disabled.img"

run erase frp

run --set-active=a
run reboot recovery
