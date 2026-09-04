# VollaOS of Quintus → Daria Bond 1

Automated GitHub Action that pulls **Volla (algiz) stable OTAs**, extracts partitions, builds a MediaTek-friendly `super.img` (explicit `_a`/`_b` slots), and publishes a fastboot flash package for **Daria Bond 1**.

**Requirement:** DariaOS 6 (Android 15) base, unlocked bootloader.  
**Risk:** Unofficial/automated build — can brick the device. Flash at your own risk; back up critical partitions first.

### Flash guide
1. Extract the release (`7z x volla-algiz-stable.7z.001`).
2. Boot to bootloader, flash per `commands.txt`
