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
- `fastboot` (platform-tools) and **7-Zip** on your PC

## Flashing guide

1. Download **all** `volla-algiz-stable.7z.*` parts from the latest release into one folder.
2. Extract only the first part:
   ```bash
   7z x volla-algiz-stable.7z.001
   ```
   On Windows: right-click `.001` → *Extract with 7-Zip*.
3. Reboot to the bootloader (`adb reboot bootloader`).
4. Flash the commands in `commands.txt` **in the order listed**. The order is intentional.
5. Reboot.
