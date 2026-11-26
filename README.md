# VollaOS (Quintus) for Daria Bond I

An unofficial, fully automated port of **Volla OS** to the **Daria Bond I** (`zahedan`), with built-in **Linux Mobile Dual-Boot** support on Slot B.

A GitHub Action checks the Volla OTA server every day. When a new stable build appears, it repacks it into a ready-to-flash fastboot package (plus a separate Ubuntu Touch Slot B add-on zip) and publishes it on the [Releases](https://github.com/sajjad85gh/zahedan-vollaos-rom-porter/releases) page.

> [!WARNING]
> This ROM is built automatically and is **unofficial**. It can brick your device. Flash at your own risk and back up your important partitions first:
> ```bash
> su -c 'for partition in nvcfg nvdata nvram persist proinfo protect1 protect2; do
>     dd if=/dev/block/by-name/$partition of=/sdcard/${partition}.img
> done'
> ```

## Requirements

- Daria Bond I with an **unlocked bootloader**
- **7-Zip** on your PC
- A good USB cable (plug directly into the PC, avoid hubs)

## Download & extract

1. Download **all** `volla-algiz-stable.7z.*` parts from the latest release into **one folder**.
2. Extract **only the first part** (`.001`), the rest are picked up automatically:
   - **Windows:** right-click `volla-algiz-stable.7z.001` → *7-Zip* → *Extract Here*
   - **Linux/Mac:** `7z x volla-algiz-stable.7z.001`

## Flashing guide (VollaOS)

Reboot the phone to the bootloader first: `adb reboot bootloader`, or power off and hold *Volume Down + Power*.

### Windows

Nothing to install: the latest `platform-tools` is bundled in the `platform-tools` folder.

1. Open the extracted folder (keep the `platform-tools` folder next to the scripts and images).
2. Double-click **`flash_all.bat`**.
3. Type `YES` and press Enter.
4. Wait until it says **DONE**. The phone reboots to recovery by itself.

If something goes wrong, the window **stays open** and shows the error. Don't close it before reading it, and don't reboot into the system.
If the script waits forever on *"Waiting for a device in fastboot mode..."*, install the Google USB Driver or MediaTek USB driver from Device Manager.

### Linux / Mac

1. Install `fastboot`:
   - Debian/Ubuntu: `sudo apt install fastboot`
   - Arch: `sudo pacman -S android-tools`
   - Or place Google's [platform-tools](https://developer.android.com/tools/releases/platform-tools) folder next to the script as `platform-tools/`.
2. Open a terminal in the extracted folder and run:
   ```bash
   bash flash_all.sh
   ```
3. Type `YES` and press Enter.
4. Wait until it says **Done**. The phone reboots to recovery by itself.

If the phone is not detected on Linux, install `android-udev-rules` (or run with `sudo`).

### Manual flashing

The exact same commands, in the same (intentional) order, are in `commands.txt`.

---

## Dual-Boot (Linux Mobile on Slot B)

Every release is **dual-boot ready** without touching DariaOS stock `preloader` or `lk` (stock Volla Updater and unsafe Multi-Boot Manager are removed to prevent hard-bricks):

- **Slot A:** VollaOS (includes built-in **Switch to Linux** app + Quick Settings tile)
- **Slot B:** Linux Mobile — currently **Ubuntu Touch** (and ready for future Sailfish OS / Droidian builds)
- **`super.img`:** Mirrors `vendor`, `vendor_dlkm`, `odm_dlkm`, and `system_dlkm` to Slot B so Linux Mobile boots natively.

### 1. One-time GPT partitioning (no custom recovery needed)

> [!CAUTION]
> Shrinking `userdata` wipes Android data. Back up your files first.

`prepare_gpt.sh` (with its helper `gpt_edit.py`; both are included in the Ubuntu Touch zip and in `flash/`) does the whole job from your PC while Android is running:

- **Requirements:** root (Magisk/KernelSU) granted to the adb shell, USB debugging on, and `adb`, `fastboot` and `python3` on the PC.
**asks how many GiB you want to give Linux** (default 40, minimum about 40, and Android always keeps at least 20 GiB), shrinks `userdata` by that amount and creates `linux_system` (about 9.7 GiB) and `linux_data` (the rest) right after it. Partitions that follow `userdata` (like `flashinfo`) stay where they are. Only the partition entries and CRCs are edited; everything else in the vendor's GPT is left untouched.
- The result is verified (automatic rollback on any mismatch), then the phone reboots to the bootloader and `userdata`/`metadata` are wiped. The backup and patch files are kept in `gpt_backup_<date>/` on the PC.

```bash
bash prepare_gpt.sh --dry-run             # show the plan only, change nothing
bash prepare_gpt.sh                       # interactive: asks how many GiB to give Linux, then asks for YES
bash prepare_gpt.sh --linux-gib 64        # non-interactive: 64 GiB in total for Linux
bash prepare_gpt.sh --restore gpt_backup_<date>   # undo: restore the original table
```

### 2. Flash Ubuntu Touch (Slot B)

1. Download and extract **`volla-algiz-ubuntu-touch-dualboot.zip`** from the same release.
2. Run the installer script:
   - **Windows:** double-click **`flash_ut_slot_b.bat`**
   - **Linux/Mac:** run `bash flash_ut_slot_b.sh`
3. When asked to format `linux_data`:
   - Type **`YES`** for a **first install** (Halium auto-formats it as `ext4` on first boot).
   - Type **`NO`** when **updating** to keep your Ubuntu Touch data.

### 3. Switching between VollaOS and Ubuntu Touch

- **VollaOS → Ubuntu Touch:** Tap **Switch to Linux** in the app drawer or Quick Settings tile *(requires root — KernelSU/Magisk)*.
- **Ubuntu Touch → VollaOS:** Tap **Switch to VollaOS** in the Lomiri app drawer *(works out of the box, no setup needed)*.
- **Without root / Emergency fallback:**
  - **Recovery:** *Reboot → Slot A* (VollaOS) or *Slot B* (Ubuntu Touch)
  - **Fastboot:**
    ```bash
    fastboot set_active a && fastboot reboot   # VollaOS
    fastboot set_active b && fastboot reboot   # Ubuntu Touch
    ```

### Updating VollaOS with Dual-Boot

Flashing a new VollaOS release (`flash_all`) updates Slot A & B firmware and `super.img`. Afterwards, re-run `flash_ut_slot_b` with **`WIPE_DATA=NO`** to restore Ubuntu Touch on Slot B without losing data.
