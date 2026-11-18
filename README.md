# VollaOS (Quintus) for Daria Bond I

An unofficial, fully automated port of **Volla OS** to the **Daria Bond I**.

A GitHub Action checks the Volla OTA server every day. When a new stable build appears, it converts it into a ready-to-flash fastboot package and publishes it on the [Releases](https://github.com/sajjad85gh/zahedan-vollaos-rom-porter/releases) page.

> [WARNING!]
> This ROM is built automatically and is **unofficial**. It can brick your device. Flash at your own risk and back up your important partitions first:
   ```bash
    su -c 'for partition in nvcfg nvdata nvram persist proinfo protect1 protect2; do
        dd if=/dev/block/by-name/$partition of=/sdcard/${partition}.img
    done'
   ```

## Requirements

- Daria Bond I with an **unlocked bootloader**
- **7-Zip** on your PC
- A good USB cable (plug it directly into the PC, avoid hubs)

## Download & extract

1. Download **all** `volla-algiz-stable.7z.*` parts from the latest release into **one folder**.
2. Extract **only the first part** (`.001`), the rest are picked up automatically:
   - **Windows:** right-click `volla-algiz-stable.7z.001` → *7-Zip* → *Extract Here*
   - **Linux/Mac:** `7z x volla-algiz-stable.7z.001`

## Flashing guide

Reboot the phone to the bootloader first: `adb reboot bootloader`, or power off and hold *Volume Down + Power*.

### Windows

Nothing to install: the latest `platform-tools` is bundled in the `platform-tools` folder.

1. Open the extracted folder (keep the `platform-tools` folder next to the scripts and images).
2. Double-click **`flash_all.bat`**.
3. Type `YES` and press Enter.
4. Wait until it says **DONE**. The phone reboots to recovery by itself.

If something goes wrong, the window **stays open** and shows the error. Don't close it before reading it, and don't reboot into the system.
If the script waits forever on *"Waiting for a device in fastboot mode..."*, the phone isn't detected: check the cable/port and install the Google USB Driver (or the MediaTek USB driver) from Device Manager.

### Linux / Mac

1. Install `fastboot`, for example:
   - Debian/Ubuntu: `sudo apt install fastboot`
   - Arch: `sudo pacman -S android-tools`
   - Fedora: `sudo dnf install android-tools`
   - or download [platform-tools](https://developer.android.com/tools/releases/platform-tools) from Google and put its folder next to the script as `platform-tools/`
2. Open a terminal in the extracted folder and run:
   ```bash
   bash flash_all.sh
   ```
3. Type `YES` and press Enter.
4. Wait until it says **Done**. The phone reboots to recovery by itself.

If the phone is not detected on Linux, install your distro's `android-udev-rules` package (or run the script with `sudo` as a quick test).

### Manual flashing

Prefer to type the commands yourself? The exact same commands, in the same (intentional) order, are in `commands.txt`.

## Repository layout

- `flash/` – `commands.txt`, `flash_all.sh`, `flash_all.bat` (copied into every release package)
- `prebuilt/` – `lk`, `preloader`, `vbmeta-disabled`
- `.github/workflows/ota-checker.yml` – daily OTA check, repack and release
