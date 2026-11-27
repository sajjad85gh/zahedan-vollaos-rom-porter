#!/usr/bin/env bash
# prepare_gpt.sh - dual-boot partition preparation & removal for Daria Bond I (zahedan).
#
# Usage:
#   bash prepare_gpt.sh [--dry-run] [--linux-gib N] [--backup | --no-backup]
#   bash prepare_gpt.sh --remove [--dry-run]
#   bash prepare_gpt.sh --restore <backup_dir>
#
# Requirements: adb, fastboot and python3 on the PC, USB debugging enabled, root on the phone.
set -euo pipefail
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

# `pwd -W` gives a C:/... path in Git Bash (native adb.exe/python need it); plain `pwd` elsewhere.
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && { pwd -W 2>/dev/null || pwd; })
UNIX_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GPT_PY=$HERE/gpt_edit.py

if [ -d "$UNIX_HERE/platform-tools" ]; then
  PATH="$UNIX_HERE/platform-tools:$PATH"
fi

LINUX_GIB=""
DEFAULT_LINUX_GIB=40
LINUX_SYSTEM_BYTES=10368709120     # must match the image size limit in ota-checker.yml
MIN_DATA_GIB=30
MIN_USERDATA_GIB=20
BYNAME=/dev/block/by-name
REMOTE_TMP=/data/local/tmp
DUMP_BLOCKS=256                    # 256 * 4096 = 1 MiB dumped from each end of the disk

DRY_RUN=0
REMOVE_MODE=0
BACKUP_CHOICE=""
RESTORE_DIR=""
DISK=""
LINK_PNUM=""
BK=""
WORK=""
TMP_BK=""

cleanup_and_pause() {
  local code=$?
  [ -n "${WORK:-}" ] && rm -rf "$WORK" 2>/dev/null || true
  [ -n "${TMP_BK:-}" ] && rm -rf "$TMP_BK" 2>/dev/null || true
  if [ -z "${NO_PAUSE:-}" ] && { [ -t 0 ] || [ -t 1 ]; }; then
    echo
    if [ "$code" -ne 0 ]; then
      echo "================================================================"
      echo " STOPPED WITH ERROR (exit code $code). Read the messages above."
      echo "================================================================"
    else
      echo "================================================================"
      echo " FINISHED. You can close this window now."
      echo "================================================================"
    fi
    if [ -e /dev/tty ]; then
      read -r -p "Press Enter to close..." _ </dev/tty 2>/dev/null || true
    fi
  fi
}
trap cleanup_and_pause EXIT

die()  { echo "[ERROR] $*" >&2; exit 1; }
info() { echo ">> $*"; }

# Run a command as root on the phone. The command must not contain single quotes.
rsh() { adb shell "su -c '$*'" </dev/null | tr -d '\r'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --remove|--revert) REMOVE_MODE=1 ;;
    --backup)     BACKUP_CHOICE=yes ;;
    --no-backup)  BACKUP_CHOICE=no ;;
    --linux-gib|--shrink-gib) LINUX_GIB=${2:?$1 needs a value}; shift ;;
    --restore)    RESTORE_DIR=${2:?--restore needs a backup directory}; shift ;;
    -h|--help)    sed -n '2,10p' "$0"; exit 0 ;;
    *)            die "Unknown argument: $1" ;;
  esac
  shift
done
[ -z "$LINUX_GIB" ] || [[ $LINUX_GIB =~ ^[0-9]+$ ]] || die "--linux-gib must be an integer."

find_python() {
  local c
  for c in python3 python py; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
      PY=$c
      return
    fi
  done
  die "Python 3 not found in PATH. On Windows install it from https://www.python.org/downloads/ (tick 'Add python.exe to PATH') or run: winget install Python.Python.3.12 , then start this script again."
}

wait_for_adb() {
  local st="" i
  info "Starting the adb server (if Windows asks to allow adb through the firewall, click 'Allow')..."
  adb start-server </dev/null 2>&1 | tr -d '\r' || true
  for i in $(seq 90); do
    st=$(adb devices </dev/null 2>/dev/null | tr -d '\r' | awk -F'\t' 'NF>=2 && $1 !~ /^\*/ { print $2; exit }')
    case "$st" in
      device) info "adb device found."; return 0 ;;
      unauthorized)
        if [ $(( (i - 1) % 15 )) -eq 0 ]; then info "Unlock the phone and tap Allow on the 'Allow USB debugging?' prompt (tick 'Always allow')..."; fi ;;
      offline)
        if [ $(( (i - 1) % 15 )) -eq 0 ]; then info "The phone is 'offline': unplug and re-plug the cable, or toggle USB debugging off and on..."; fi
        [ "$i" -eq 30 ] && adb kill-server >/dev/null 2>&1 && adb start-server >/dev/null 2>&1 || true ;;
      *)
        if [ $(( (i - 1) % 15 )) -eq 0 ]; then info "Waiting for the phone: boot Android, enable USB debugging and connect the cable (try another port; on Windows also check the firewall prompt)..."; fi
        if [ "$i" -eq 45 ]; then adb kill-server >/dev/null 2>&1 || true; adb start-server >/dev/null 2>&1 || true; fi ;;
    esac
    sleep 1
  done
  die "No authorized adb device (state: ${st:-none}). Boot Android, enable USB debugging, accept the prompt on the phone, and check that 'adb devices' lists the phone as 'device'."
}

require_tools() {
  command -v adb >/dev/null      || die "adb not found in PATH."
  command -v fastboot >/dev/null || die "fastboot not found in PATH."
  find_python
  [ -f "$GPT_PY" ]               || die "gpt_edit.py must be next to this script."
  wait_for_adb
  [ "$(rsh id -u || true)" = "0" ] \
    || die "Root is required. Grant su access to the adb shell (Magisk/KernelSU)."
}

find_disk() {
  if [ -n "${GPT_DISK:-}" ]; then
    DISK=$GPT_DISK
    return
  fi
  local node
  node=$(rsh "readlink -f $BYNAME/userdata" || true)
  if [[ $node =~ ^(/dev/block/(mmcblk[0-9]+|nvme[0-9]+n[0-9]+))p([0-9]+)$ ]]; then
    DISK=${BASH_REMATCH[1]}; LINK_PNUM=${BASH_REMATCH[3]}
  elif [[ $node =~ ^(/dev/block/[a-z]+)([0-9]+)$ ]]; then
    DISK=${BASH_REMATCH[1]}; LINK_PNUM=${BASH_REMATCH[2]}
  else
    die "Cannot map $BYNAME/userdata (got '${node:-nothing}') to a disk. Set GPT_DISK=/dev/block/<disk>."
  fi
}

show_storage() {
  info "Storage devices on the phone (userdata is on ${DISK##*/}):"
  rsh 'for d in /sys/block/sd* /sys/block/mmcblk*; do [ -d $d ] && echo "   $(basename $d): $(( $(cat $d/size) / 2048 )) MiB"; done; true' || true
}

read_geometry() {
  local name=${DISK##*/} sect512
  SSZ=$(rsh "cat /sys/block/$name/queue/logical_block_size" || true)
  sect512=$(rsh "cat /sys/block/$name/size" || true)
  [[ $SSZ =~ ^[0-9]+$ && $sect512 =~ ^[0-9]+$ ]] || die "Cannot read the size of $DISK from sysfs."
  TOTAL_BYTES=$(( sect512 * 512 ))
  [ $(( TOTAL_BYTES % 4096 )) -eq 0 ] && [ $(( 4096 % SSZ )) -eq 0 ] || die "Unsupported disk geometry."
  TOTAL_SECTORS=$(( TOTAL_BYTES / SSZ ))
  TAIL_SKIP=$(( TOTAL_BYTES / 4096 - DUMP_BLOCKS ))
}

dump_disk() {
  mkdir -p "$1"
  adb exec-out "su -c 'dd if=$DISK bs=4096 count=$DUMP_BLOCKS 2>/dev/null'" </dev/null > "$1/head.bin"
  adb exec-out "su -c 'dd if=$DISK bs=4096 skip=$TAIL_SKIP count=$DUMP_BLOCKS 2>/dev/null'" </dev/null > "$1/tail.bin"
  local f
  for f in head.bin tail.bin; do
    [ "$(wc -c < "$1/$f" | tr -d ' ')" = "1048576" ] || die "Reading $DISK failed ($f has the wrong size)."
  done
}

gpt_cmd() {
  local sub=$1 dir=$2
  shift 2
  "$PY" "$GPT_PY" "$sub" --head "$dir/head.bin" --tail "$dir/tail.bin" \
    --sector-size "$SSZ" --total-sectors "$TOTAL_SECTORS" "$@"
}

apply_patches() {
  local lba file
  while read -r lba file; do
    adb push "$1/$file" "$REMOTE_TMP/gpt_patch.bin" >/dev/null || return 1
    rsh "dd if=$REMOTE_TMP/gpt_patch.bin of=$DISK bs=$SSZ seek=$lba conv=notrunc 2>/dev/null" >/dev/null || return 1
  done < "$1/manifest.txt"
  rsh sync >/dev/null
}

fb_ready() {
  local o
  o=$(fastboot devices 2>/dev/null || true)
  [[ $o == *fastboot* ]]
}

fb_size() {
  local out v
  out=$(fastboot getvar "partition-size:$1" 2>&1 || true)
  v=$(sed -nE "s/.*partition-size:$1: *(0[xX])?([0-9a-fA-F]+).*/\\2/p" <<<"$out" | head -n1 || true)
  if [ -n "$v" ]; then echo $(( 16#$v )); fi
}

reboot_and_wipe() {
  local set_slot_a=${1:-0}
  info "Rebooting to the bootloader..."
  adb reboot bootloader
  info "Waiting for fastboot (up to 120 s)..."
  local i
  for i in $(seq 120); do
    if fb_ready; then break; fi
    sleep 1
  done
  fb_ready || die "Device did not appear in fastboot. Do NOT boot Android; enter the bootloader manually and run: fastboot erase userdata"
  fastboot erase userdata || die "Erasing userdata failed. Do NOT boot Android; fix fastboot and run: fastboot erase userdata"
  if [ -n "$(fb_size metadata)" ]; then
    fastboot erase metadata || die "Erasing metadata failed. Do NOT boot Android; run: fastboot erase metadata"
  fi
  if [ "$set_slot_a" -eq 1 ]; then
    info "Setting active boot slot to Slot A (Android)..."
    fastboot --set-active=a || true
  fi
}

confirm() {
  local answer
  read -r -p "$1 Type YES to continue: " answer
  [ "$answer" = "YES" ] || die "Aborted."
}

run_remove_flow() {
  local rm_args=()
  [ -n "$LINK_PNUM" ] && rm_args+=(--expect-userdata-number "$LINK_PNUM")

  echo
  local rc=0
  gpt_cmd remove "$WORK/before" "${rm_args[@]}" || rc=$?
  [ "$rc" -eq 11 ] && { info "No Linux partitions found. Nothing to remove."; exit 0; }
  [ "$rc" -eq 0 ] || exit 1

  if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry run: nothing was changed."
    exit 0
  fi

  confirm "This REMOVES linux_system & linux_data, returns all space to userdata, and ERASES ALL ANDROID & LINUX DATA."

  BK=$(mktemp -d "$HERE/.gpt_remove_undo.XXXXXX")
  gpt_cmd remove "$WORK/before" "${rm_args[@]}" --out "$BK/plan" >/dev/null || die "Could not create the removal patch files."

  rollback_remove() {
    echo "[ERROR] $1" >&2
    echo "Restoring previous partition table..." >&2
    if apply_patches "$BK/plan/undo"; then
      rm -rf "$BK" 2>/dev/null || true
      echo "Previous partition table restored; no data was touched." >&2
    else
      echo "ROLLBACK FAILED. Previous sectors are saved in $BK/plan/undo." >&2
    fi
    exit 1
  }

  info "Writing restored partition table (merging Linux space back into userdata)..."
  apply_patches "$BK/plan/new" || rollback_remove "Writing the updated partition table failed."

  info "Verifying..."
  dump_disk "$WORK/after"
  gpt_cmd verify "$WORK/after" --plan "$BK/plan/plan.json" --state new || rollback_remove "Written GPT did not match the removal plan."
  info "Partition table updated and verified."

  reboot_and_wipe 1

  TMP_BK="$BK"
  UD_BL=$(fb_size userdata)
  echo
  if [ -n "$UD_BL" ]; then
    info "Done. Bootloader now reports userdata = $UD_BL bytes (~$(( UD_BL / 1073741824 )) GiB)."
  else
    info "Done. Linux partitions removed and userdata wiped."
  fi
  info "Reboot to Android now (fastboot reboot); Android will format userdata to full capacity on first boot."
  exit 0
}

# ---------------------------------------------------------------- restore mode (from backup folder)
if [ -n "$RESTORE_DIR" ]; then
  [ -s "$RESTORE_DIR/plan/undo/manifest.txt" ] && [ -s "$RESTORE_DIR/disk.env" ] \
    || die "$RESTORE_DIR does not look like a backup made by this script."
  require_tools
  GPT_DISK=$(sed -n 's/^DISK=//p' "$RESTORE_DIR/disk.env")
  find_disk
  read_geometry
  confirm "This restores the original partition table on $DISK and wipes Android/Linux data."
  apply_patches "$RESTORE_DIR/plan/undo" || die "Writing the original partition table failed."
  WORK=$(mktemp -d "$HERE/.gpt_work.XXXXXX")
  dump_disk "$WORK"
  gpt_cmd verify "$WORK" --plan "$RESTORE_DIR/plan/plan.json" --state orig || die "Restored GPT did not verify."
  reboot_and_wipe 1
  info "Original partition table restored. Run 'fastboot reboot' to boot Android; it will format userdata on first start."
  exit 0
fi

# ---------------------------------------------------------------- analysis
require_tools
find_disk
show_storage
read_geometry

bat=$(adb shell dumpsys battery </dev/null | tr -d '\r' | awk '/level:/ { print $2; exit }')
[[ ${bat:-} =~ ^[0-9]+$ ]] && [ "$bat" -ge 40 ] || die "Battery level is unknown or below 40%. Charge the phone first."

WORK=$(mktemp -d "$HERE/.gpt_work.XXXXXX")
dump_disk "$WORK/before"

# Direct --remove mode (no backup needed)
if [ "$REMOVE_MODE" -eq 1 ]; then
  run_remove_flow
fi

LIMIT_ARGS=(--system-bytes "$LINUX_SYSTEM_BYTES" --min-data-gib "$MIN_DATA_GIB" --min-userdata-gib "$MIN_USERDATA_GIB")
echo
rc=0
LIMITS=$(gpt_cmd limits "$WORK/before" "${LIMIT_ARGS[@]}") || rc=$?
if [ "$rc" -eq 10 ]; then
  info "linux_system / linux_data already exist on this device."
  if [ "$DRY_RUN" -eq 0 ] && [ -t 0 ]; then
    echo
    echo "If you want to delete the Linux partitions and return all storage back to Android:"
    read -r -p "Type REMOVE to reclaim space for Android, or press Enter to exit: " rm_ans
    if [ "$rm_ans" = "REMOVE" ]; then
      run_remove_flow
    fi
  fi
  info "Nothing changed."
  exit 0
fi
[ "$rc" -eq 0 ] || exit 1
read -r MIN_GIB MAX_GIB <<<"$LIMITS"

if [ -z "$LINUX_GIB" ]; then
  default=$(( DEFAULT_LINUX_GIB < MIN_GIB ? MIN_GIB : (DEFAULT_LINUX_GIB > MAX_GIB ? MAX_GIB : DEFAULT_LINUX_GIB) ))
  if [ -t 0 ]; then
    echo "Linux needs at least $MIN_GIB GiB (linux_system + linux_data); at most $MAX_GIB GiB can be given"
    echo "(Android keeps at least $MIN_USERDATA_GIB GiB). Everything you give to Linux is taken from Android storage."
    read -r -p "How many GiB for Linux? [$default]: " LINUX_GIB
    LINUX_GIB=${LINUX_GIB:-$default}
  else
    LINUX_GIB=$default
  fi
fi
[[ $LINUX_GIB =~ ^[0-9]+$ ]] || die "The size must be an integer number of GiB."
{ [ "$LINUX_GIB" -ge "$MIN_GIB" ] && [ "$LINUX_GIB" -le "$MAX_GIB" ]; } \
  || die "Choose a size between $MIN_GIB and $MAX_GIB GiB."

PLAN_ARGS=("${LIMIT_ARGS[@]}" --linux-gib "$LINUX_GIB")
[ -n "$LINK_PNUM" ] && PLAN_ARGS+=(--expect-userdata-number "$LINK_PNUM")

echo
gpt_cmd plan "$WORK/before" "${PLAN_ARGS[@]}" || exit 1

if [ "$DRY_RUN" -eq 1 ]; then
  info "Dry run: nothing was changed."
  exit 0
fi

confirm "This ERASES ALL ANDROID DATA (userdata is shrunk and wiped). Back up your files first."

# ---------------------------------------------------------------- backup + apply
KEEP_BACKUP=1
[ "$BACKUP_CHOICE" != "no" ] || KEEP_BACKUP=0
if [ -z "$BACKUP_CHOICE" ] && [ -t 0 ] && [ -z "${BACKUP_DIR:-}" ]; then
  echo
  echo "A backup of the original partition table (head/tail of the disk + undo patches) can be saved"
  echo "in ./gpt_backup_<date>-<time>/ . (You can also revert later with --remove even without a backup.)"
  read -r -p "Save the backup? Type YES to save, NO to skip [YES]: " ans
  case "${ans:-YES}" in
    n|N|no|NO|No) KEEP_BACKUP=0 ;;
  esac
fi
if [ "$KEEP_BACKUP" -eq 1 ]; then
  BK=${BACKUP_DIR:-./gpt_backup_$(date +%Y%m%d-%H%M%S)}
else
  BK=$(mktemp -d "$HERE/.gpt_undo.XXXXXX")
  info "Backup skipped (you can still revert later using: bash prepare_gpt.sh --remove)."
fi
mkdir -p "$BK"
printf 'DISK=%s\nSSZ=%s\nTOTAL_SECTORS=%s\n' "$DISK" "$SSZ" "$TOTAL_SECTORS" > "$BK/disk.env"
cp -r "$WORK/before" "$BK/before"
gpt_cmd plan "$BK/before" "${PLAN_ARGS[@]}" --out "$BK/plan" >/dev/null || die "Could not create the patch files."
if [ "$KEEP_BACKUP" -eq 1 ]; then
  info "Backup and patch files are in $BK (keep them until the dual-boot setup works)."
  info "To undo later: bash prepare_gpt.sh --restore ${BK#./}  (or --remove)"
fi

rollback() {
  echo "[ERROR] $1" >&2
  echo "Restoring the original partition table..." >&2
  if apply_patches "$BK/plan/undo"; then
    [ "$KEEP_BACKUP" -eq 1 ] || rm -rf "$BK" 2>/dev/null || true
    echo "Original partition table restored; no data was touched." >&2
  else
    echo "ROLLBACK FAILED. The original sectors are in $BK/plan/undo (see manifest.txt: LBA and file per line)." >&2
  fi
  exit 1
}

info "Writing the new partition table..."
apply_patches "$BK/plan/new" || rollback "Writing the new partition table failed."

info "Verifying..."
dump_disk "$WORK/after"
gpt_cmd verify "$WORK/after" --plan "$BK/plan/plan.json" --state new || rollback "The written GPT does not match the plan."
info "Partition table written and verified."

# ---------------------------------------------------------------- wipe + bootloader check
reboot_and_wipe 0

SYS_BL=$(fb_size linux_system)
DATA_BL=$(fb_size linux_data)
if [ -z "$SYS_BL" ] || [ -z "$DATA_BL" ] || [ "$SYS_BL" -lt "$LINUX_SYSTEM_BYTES" ]; then
  die "The bootloader does not report linux_system/linux_data as expected. Do not flash anything; check 'fastboot getvar all'."
fi

[ "$KEEP_BACKUP" -eq 1 ] || TMP_BK="$BK"

echo
info "Done. The bootloader sees linux_system ($SYS_BL bytes) and linux_data ($DATA_BL bytes)."
info "Next: run flash_ut_slot_b.sh (answer YES to format linux_data on a first install)."
