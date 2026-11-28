# VollaOS (Quintus) for Daria Bond I

**English** | [فارسی](README.fa.md)

An unofficial, fully automated port of **Volla OS** to the **Daria Bond I** (`zahedan`), with built-in **Linux Mobile Dual-Boot** support on Slot B.

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
- A good USB cable

## Download & extract

1. Download **all** `volla-algiz-stable.7z.*` parts from the latest release into **one folder**.
2. Extract **only the first part** (`.001`), the rest are picked up automatically:
   - **Windows:** right-click `volla-algiz-stable.7z.001` → *7-Zip* → *Extract Here*
   - **Linux/Mac:** `7z x volla-algiz-stable.7z.001`

After extraction, all partition images live inside the **`OS/`** folder, while the flash scripts sit right next to **`OS/`** and **`platform-tools/`**.

## Flashing guide (VollaOS)

Reboot the phone to the bootloader first: `adb reboot bootloader`, or power off and hold *Volume Down + Power*.

### Windows

Nothing to install: the latest `platform-tools` is bundled in the `platform-tools` folder.

1. Open the extracted folder (keep the `OS` and `platform-tools` folders next to the scripts).
2. Double-click **`flash_all.bat`**.
3. Type `YES` and press Enter.
4. Wait until it says **DONE**. The script wipes `frp`, sets Slot A active, and reboots the phone to recovery by itself.

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
4. Wait until it says **DONE**.

If the phone is not detected on Linux, install `android-udev-rules` (or run with `sudo`).

### Manual flashing

The exact same commands (pointing to `OS/*.img`), in the same intentional order, are in `commands.txt`.

---

## Dual-Boot (Linux Mobile on Slot B)

- **Slot A:** VollaOS (includes built-in **Switch to Linux** app)
- **Slot B:** Linux Mobile — currently **Ubuntu Touch**

### 1. One-time GPT partitioning

> [!CAUTION]
> Shrinking `userdata` (or removing Linux partitions later) wipes Android data. Back up your files first.

- **Requirements:** root (Magisk/KernelSU) for `adb root`, USB debugging on, and `python3` on the PC. On Windows install **Git for Windows** and **Python 3**, then run **`prepare_gpt.bat`**.
- The script automatically finds the disk that holds `userdata`, **asks how many GiB you want to give Linux** (default 40, minimum about 40), shrinks `userdata` by that amount, and creates `linux_system` (about 9.7 GiB) and `linux_data` (the rest) right after it.
- The backup and patch files are kept in `gpt_backup_<date>/` on the PC.

```bash
bash prepare_gpt.sh
```

Available options:

```bash
bash prepare_gpt.sh                               # interactive: asks how many GiB to give Linux and asks for confirmation
bash prepare_gpt.sh --dry-run                     # show the plan only, change nothing
bash prepare_gpt.sh --linux-gib 64                # non-interactive: 64 GiB in total for Linux
bash prepare_gpt.sh --remove --dry-run            # preview removing Linux partitions without changing anything
bash prepare_gpt.sh --remove                      # return all space to Android
bash prepare_gpt.sh --restore gpt_backup_<date>   # undo: restore the exact original table from a backup folder
```

On Windows, run **`prepare_gpt.bat`** to use the interactive menu (Create / Remove / Restore), or pass the same flags via Command Prompt, e.g. `prepare_gpt.bat --dry-run` or `prepare_gpt.bat --remove --dry-run`.

**Backup:** before changing anything, the script asks *"Save the backup? Type YES to save, NO to skip"*. Answer `YES` (the default) to keep the original partition table in a folder named `gpt_backup_<YYYYMMDD>-<HHMMSS>` next to the script.

**Returning Linux storage back to Android (removing Dual-Boot):**

- **Without a backup (`--remove`):** you can delete `linux_system` and `linux_data` and expand `userdata` back to full size even if you did not save a backup folder. Always preview first with `--dry-run`:
  ```bash
  bash prepare_gpt.sh --remove --dry-run
  bash prepare_gpt.sh --remove
  ```
  On Windows:
  ```bat
  prepare_gpt.bat --remove --dry-run
  prepare_gpt.bat --remove
  ```
  *(Or run `prepare_gpt.bat` and select option `2`.)*

- **From a saved backup (`--restore`):** use the exact folder name that was created (for example, `gpt_backup_20261127-031542`):
  ```bash
  bash prepare_gpt.sh --restore gpt_backup_20261127-031542
  ```
  On Windows:
  ```bat
  prepare_gpt.bat --restore gpt_backup_20261127-031542
  ```

Type `YES` when asked. In both modes, the updated partition table is written and verified, `userdata`/`metadata` are wiped, and the active slot is switched back to **Slot A**. Boot Android afterwards (`fastboot reboot`); it will format `userdata` to full capacity on first start.

### 2. Flash Ubuntu Touch (Slot B)

1. Download and extract **`volla-algiz-ubuntu-touch-dualboot.zip`** (or `.7z.*`) from the Ubuntu Touch release. (Partition images are inside the **`OS/`** folder next to the scripts and `platform-tools/`.)
2. Run the installer script:
   - **Windows:** run **`flash_ut_slot_b.bat`**
   - **Linux/Mac:** run **`flash_ut_slot_b.sh`**
3. When asked to format `linux_data`:
   - Type **`YES`** for a **first install** (Halium auto-formats it as `ext4` on first boot).
   - Type **`NO`** when **updating** to keep your Ubuntu Touch data.

### 3. Switching between VollaOS and Ubuntu Touch

- **VollaOS → Ubuntu Touch:** Tap **Switch to Linux** in the app drawer *(requires root — KernelSU/Magisk)*.
- **Ubuntu Touch → VollaOS:** Tap **Reboot to Android** in the app drawer and confirm.
- **Without root / Emergency fallback:**
  - **Recovery:** *Reboot → Slot A* (VollaOS) or *Slot B* (Ubuntu Touch)
  - **Fastboot:**
    ```bash
    fastboot set_active a && fastboot reboot   # VollaOS
    fastboot set_active b && fastboot reboot   # Ubuntu Touch
    ```

### Updating VollaOS with Dual-Boot

Flashing a new VollaOS release (`flash_all`) updates Slot A & B firmware and `super.img`. Afterwards, re-run `flash_ut_slot_b` and answer **`NO`** to *Format 'linux_data'?* to restore Ubuntu Touch on Slot B without losing data.