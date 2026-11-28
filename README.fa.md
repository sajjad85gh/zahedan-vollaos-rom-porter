<div dir="rtl">

# &rlm;VollaOS (Quintus) برای Daria Bond I

**فارسی** | [English](README.md)

پورت غیررسمی و کاملاً خودکار **Volla OS** برای گوشی **داریا باند ۱** (`zahedan`) همراه با پشتیبانی داخلی از **دوآل‌بوت لینوکس موبایل** روی اسلات B.

</div>

> [!WARNING]
> این رام به‌صورت خودکار ساخته می‌شود و **غیررسمی** است؛ احتمال بریک شدن دستگاه وجود دارد. فلش کردن کاملاً بر عهده‌ی خودتان است و حتماً پیش از شروع از پارتیشن‌های حیاتی گوشی بکاپ بگیرید:
>
> ```bash
> su -c 'for partition in nvcfg nvdata nvram persist proinfo protect1 protect2; do
>     dd if=/dev/block/by-name/$partition of=/sdcard/${partition}.img
> done'
> ```

<div dir="rtl">

## پیش‌نیازها

- گوشی Daria Bond I با **بوت‌لودر آنلاک‌شده**
- نرم‌افزار **7-Zip** روی کامپیوتر
- کابل USB سالم

## دانلود و استخراج (Extract)

1. **تمام پارت‌های** `volla-algiz-stable.7z.*` را از آخرین نسخه در **یک پوشه** دانلود کنید.
2. **فقط پارت اول** (`.001`) را استخراج کنید؛ بقیه‌ی پارت‌ها خودکار خوانده می‌شوند:
   - **ویندوز:** روی `volla-algiz-stable.7z.001` راست‌کلیک کنید ← *7-Zip* &rlm;← *Extract Here*
   - **لینوکس / مک:** `7z x volla-algiz-stable.7z.001`

پس از استخراج، تمام ایمیج‌های پارتیشن‌ها داخل پوشه‌ی **`OS/`** قرار دارند و اسکریپت‌های فلش درست کنار پوشه‌های **`OS/`** و **`platform-tools/`** هستند.

## راهنمای فلش (VollaOS)

ابتدا گوشی را وارد حالت بوت‌لودر (Fastboot) کنید: دستور `adb reboot bootloader` را بزنید، یا گوشی را خاموش کرده و کلیدهای *کاهش صدا (Volume Down) + پاور* را نگه دارید.

### ویندوز

نیازی به نصب ابزار اضافه نیست؛ آخرین نسخه‌ی `platform-tools` درون پوشه‌ی `platform-tools` قرار داده شده است.

1. پوشه‌ی استخراج‌شده را باز کنید (پوشه‌های `OS` و `platform-tools` را کنار اسکریپت‌ها نگه دارید).
2. روی **`flash_all.bat`** دابل‌کلیک کنید.
3. عبارت `YES` را تایپ کرده و Enter بزنید.
4. صبر کنید تا پیام **DONE** نمایش داده شود. اسکریپت به‌طور خودکار `frp` را پاک می‌کند، اسلات A را فعال می‌کند و گوشی را به ریکاوری ریستارت می‌کند.

### لینوکس / مک

1. ابزار `fastboot` را نصب کنید:
   - دبیان / اوبونتو: `sudo apt install fastboot`
   - آرچ لینوکس: `sudo pacman -S android-tools`
   - یا پوشه‌ی [platform-tools](https://developer.android.com/tools/releases/platform-tools) گوگل را با نام `platform-tools/` کنار اسکریپت قرار دهید.
2. داخل پوشه‌ی استخراج‌شده ترمینال باز کنید و دستور زیر را اجرا کنید:
   ```bash
   bash flash_all.sh
   ```
3. عبارت `YES` را تایپ کرده و Enter بزنید.
4. صبر کنید تا پیام **DONE** نمایش داده شود.

اگر گوشی در لینوکس شناسایی نشد، بسته‌ی `android-udev-rules` را نصب کنید (یا اسکریپت را با `sudo` اجرا کنید).

### فلش دستی

دقیقاً همین دستورات (با مسیر `OS/*.img`) و با همین ترتیب در فایل `commands.txt` قرار دارند.

---

## دوآل‌بوت (لینوکس موبایل روی اسلات B)

- **اسلات A:** سیستم‌عامل VollaOS (شامل اپلیکیشن داخلی **Switch to Linux**)
- **اسلات B:** لینوکس موبایل — در حال حاضر **Ubuntu Touch**

### ۱. پارتیشن‌بندی یک‌باره‌ی GPT

</div>

> [!CAUTION]
> کوچک کردن `userdata` (یا حذف پارتیشن‌های لینوکس در آینده) تمام اطلاعات اندروید را پاک می‌کند. پیش از اجرا حتماً از فایل‌های مهم خود بکاپ بگیرید.

<div dir="rtl">

- **پیش‌نیازها:** دسترسی روت (Magisk / KernelSU) برای `adb root`&rlm;، روشن بودن USB Debugging، و نصب بودن `python3` روی کامپیوتر. در ویندوز ابتدا **Git for Windows** و **Python 3** را نصب کرده و سپس **`prepare_gpt.bat`** را اجرا کنید.
- اسکریپت به‌طور خودکار دیسک حاوی `userdata` را پیدا می‌کند، **می‌پرسد چند گیگابایت (GiB) به لینوکس اختصاص دهید** (پیش‌فرض ۴۰، حداقل حدود ۴۰)، پارتیشن `userdata` را به همان اندازه کوچک می‌کند و پارتیشن‌های `linux_system` (حدود ۹.۷ GiB) و `linux_data` (باقیمانده‌ی فضا) را دقیقاً بعد از آن می‌سازد.
- فایل‌های بکاپ و پچ در پوشه‌ی `gpt_backup_<date>/` روی کامپیوتر ذخیره می‌شوند.

<div dir="ltr">

```bash
bash prepare_gpt.sh
```

</div>

گزینه‌های قابل استفاده:

<div dir="ltr">

```bash
bash prepare_gpt.sh                               # حالت تعاملی: پرسیدن حجم لینوکس به گیگ و گرفتن تایید
bash prepare_gpt.sh --dry-run                     # فقط نمایش نقشه بدون اعمال هیچ تغییری
bash prepare_gpt.sh --linux-gib 64                # غیرتعاملی: اختصاص مجموعاً ۶۴ گیگ به لینوکس
bash prepare_gpt.sh --remove --dry-run            # پیش‌نمایش حذف پارتیشن‌های لینوکس بدون اعمال هیچ تغییری
bash prepare_gpt.sh --remove                      # بازگرداندن کل فضا به اندروید
bash prepare_gpt.sh --restore gpt_backup_<date>   # بازگردانی: برگرداندن جدول پارتیشن دقیق اولیه از پوشه‌ی بکاپ
```

</div>

در ویندوز می‌توانید **`prepare_gpt.bat`** را اجرا کنید تا از منوی تعاملی (ساخت / حذف / بازگردانی) استفاده کنید، یا همین آرگومان‌ها را از طریق CMD بفرستید؛ مثلاً `prepare_gpt.bat --dry-run` یا `prepare_gpt.bat --remove --dry-run`.

**بکاپ:** پیش از اعمال هر تغییری، اسکریپت می‌پرسد *"Save the backup? Type YES to save, NO to skip"*. با وارد کردن `YES` (پیش‌فرض)، جدول پارتیشن اصلی در پوشه‌ای با نام `gpt_backup_<YYYYMMDD>-<HHMMSS>` کنار اسکریپت ذخیره می‌شود.

**بازگرداندن فضای لینوکس به اندروید (حذف دوآل‌بوت):**

- **بدون نیاز به بکاپ (<code dir="ltr">--remove</code>):** حتی اگر پوشه‌ی بکاپ را نگه نداشته باشید، می‌توانید پارتیشن‌های `linux_system` و `linux_data` را حذف کرده و کل فضای آن‌ها را به `userdata` برگردانید. بهتر است ابتدا با <code dir="ltr">--dry-run</code> پیش‌نمایش را بررسی کنید:
  - **لینوکس / مک:**
    ```bash
    bash prepare_gpt.sh --remove --dry-run
    bash prepare_gpt.sh --remove
    ```
  - **ویندوز:** *(یا `prepare_gpt.bat` را اجرا کرده و گزینه‌ی `2` را انتخاب کنید.)*
    ```bat
    prepare_gpt.bat --remove --dry-run
    prepare_gpt.bat --remove
    ```
- **از طریق پوشه‌ی بکاپ ذخیره‌شده (<code dir="ltr">--restore</code>):** دقیقاً نام پوشه‌ی ساخته‌شده را وارد کنید (مثلاً `gpt_backup_20261127-031542`):
  - **لینوکس / مک:**
    ```bash
    bash prepare_gpt.sh --restore gpt_backup_20261127-031542
    ```
  - **ویندوز:**
    ```bat
    prepare_gpt.bat --restore gpt_backup_20261127-031542
    ```

وقتی درخواست تایید شد، `YES` را تایپ کنید. در هر دو روش، جدول پارتیشن جدید نوشته و تایید می‌شود، `userdata`/`metadata` پاک می‌شوند و اسلات فعال دوباره روی **اسلات A** قرار می‌گیرد. پس از آن گوشی را به اندروید ریستارت کنید (`fastboot reboot`)؛ اندروید در اولین بوت، `userdata` را با ظرفیت کامل فرمت می‌کند.

### ۲. فلش کردن Ubuntu Touch (اسلات B)

1. فایل **`volla-algiz-ubuntu-touch-dualboot.zip`** (یا `.7z.*`) را از صفحه‌ی انتشار Ubuntu Touch دانلود و استخراج کنید. (ایمیج‌های پارتیشن‌ها داخل پوشه‌ی **`OS/`** در کنار اسکریپت‌ها و `platform-tools/` قرار دارند.)
2. اسکریپت نصب را اجرا کنید:
   - **ویندوز:** **`flash_ut_slot_b.bat`** را اجرا کنید.
   - **لینوکس / مک:** **`flash_ut_slot_b.sh`** را اجرا کنید.
3. هنگامی که درباره‌ی فرمت کردن `linux_data` سؤال شد:
   - برای **نصب بار اول** عبارت **`YES`** را وارد کنید (Halium در اولین بوت آن را به‌صورت خودکار با فرمت `ext4` آماده می‌کند).
   - هنگام **آپدیت** عبارت **`NO`** را وارد کنید تا اطلاعات Ubuntu Touch شما حفظ شود.

### ۳. جابه‌جایی بین VollaOS و Ubuntu Touch

- **از VollaOS به Ubuntu Touch:** روی آیکون **Switch to Linux** در لیست برنامه‌ها بزنید، *(نیازمند روت — KernelSU/Magisk)*.
- **از Ubuntu Touch به VollaOS:** روی **Reboot to Android** در منوی برنامه‌ها بزنید و تایید کنید.
- **بدون روت / روش اضطراری:**
  - **ریکاوری:** *Reboot → Slot A* (برای VollaOS) یا *Slot B* (برای Ubuntu Touch)
  - **فست‌بوت:**
    ```bash
    fastboot set_active a && fastboot reboot   # VollaOS
    fastboot set_active b && fastboot reboot   # Ubuntu Touch
    ```

### آپدیت کردن VollaOS در حالت دوآل‌بوت

فلش کردن نسخه‌ی جدید VollaOS (`flash_all`) فریمور هر دو اسلات A و B و پارتیشن `super.img` را به‌روزرسانی می‌کند. پس از آن، مجدداً `flash_ut_slot_b` را اجرا کنید و به سؤال *Format 'linux_data'?&lrm;* پاسخ **`NO`** بدهید تا Ubuntu Touch روی اسلات B بدون از دست رفتن اطلاعات بازیابی شود.

</div>