# Omarchy on the ASUS ProArt PZ13 (HT5306QA)

Notes from running [Omarchy](https://omarchy.org) as a daily tablet on the ASUS ProArt PZ13: Snapdragon X Plus (X1P-42100), 13.3" OLED touchscreen, detachable keyboard. Omarchy's kernel already boots this machine; this page covers what still needed fixing, with the files used.

Tested on Omarchy 4 with `linux-omarchy 7.3-63` in November 2026. Everything here is from one machine. The files are in [`files/`](files/).

For the touch interface itself (rails, gestures, on-screen keyboard), see the [main README](../../README.md).

## Status

| Area | State | Notes |
|---|---|---|
| Boot, display, touch, Wi-Fi, Bluetooth | Works | Out of the box with Omarchy's kernel |
| Disk-password prompt without a keyboard | Fixed | On-screen keyboard at the LUKS prompt |
| Black screen after unlocking the disk | Fixed | Lid sensor ignored during startup |
| Sleep ends by itself within seconds | Fixed | Only the power button wakes the machine |
| Battery charge limit | Fixed | Firmware resets it on every boot; a unit sets it again |
| Keyboard top row, Fn lock, Copilot key | Fixed | hwdb mapping and a small helper |
| Speakers go silent until reboot | Fix under test | Two patched kernel modules; held through one 53-minute sleep so far |
| Sleep battery drain | Open | 0.7–1.1 W asleep; the chip never reaches its deep sleep state |
| Cameras, face unlock | Not started | |

## Disk password with the keyboard detached

The LUKS prompt only takes a hardware keyboard, and on this machine it was not even drawn. Two pieces:

- **On-screen keyboard at the prompt.** An initramfs hook runs `unl0kr` before the stock `encrypt` hook, which stays as the fallback. Files: `initcpio/hooks/touch-unlock`, `initcpio/install/touch-unlock`, `initcpio/zz-touch-unlock.conf`, `initcpio/unl0kr-touch-unlock.conf`. It is written for the busybox initramfs with the `encrypt` hook.
- **Keep the prompt visible.** The `kms` hook puts the Snapdragon display driver in the initramfs, where it cannot finish starting and blanks the panel. `initcpio/zz-pz13-early-display.conf` drops `kms`, so the firmware framebuffer stays lit until the disk is open.

Rebuild the boot image afterwards with `sudo limine-mkinitcpio`.

## Black screen after unlocking

logind only ignores the lid sensor for a grace period counted from kernel start. That period runs out while the machine waits at the disk prompt. If the sensor then reads "closed" (it can with the keyboard detached), logind suspends one second into startup and autologin fails, leaving a black screen.

`systemd/pz13-boot-lid-guard.service` tells logind to ignore the lid before it starts, and `systemd/pz13-boot-lid-release.service` hands the lid back 60 seconds after the display manager is up.

## Sleep that stays asleep

By default the touchscreen is a wake source, so a palm or a stray touch ends a sleep within seconds. `udev/62-pz13-power-button-wake-only.rules` turns off wake for the touchscreen, keyboard cover, volume keys, lid sensor, USB and Wi-Fi. The power button still wakes it, and the battery, charger and thermal sources are left armed. Closing the cover still suspends.

`sleep.conf.d/pz13-s2idle.conf` selects suspend-to-idle (a deep suspend reset the machine on wake once), and `system-sleep/50-pz13-quiet-sleep` turns the keyboard light and Bluetooth off for the duration of a sleep.

## Charge limit

The firmware resets the limit to 75/80 on every boot. `systemd/pz13-charge-limit.service` sets it to start 90 / stop 95 once the battery gauge answers, retrying because the sysfs file exists before the gauge does.

## Keyboard

`hwdb/90-asus-pz13-keyboard.hwdb` maps the top row to media keys. `udev/90-pz13-keyboard-hidraw.rules` gives read access to the raw HID device, which a helper uses to see the Copilot key being held.

## Speakers going silent

**Symptom.** Sound stops while everything looks healthy: the sink is unmuted, the stream is running, both WSA8845 amplifiers show as attached. The microphones keep working. Only a reboot brought sound back. It happened about once a day, and after both long sleeps we checked.

**What we found.**

- Sometimes the kernel logs `qcom_swrm_irq_handler: SWR bus clsh detected` when the amplifiers wake from idle.
- In the silent state both amplifiers hold a latched fault: `PA_FSM_STA1` reads `0x04` and `PA_FSM_ERR_COND0` reads `0x40`. Healthy amplifiers read `0x00` in both.
- Nothing resets the amplifiers after boot, so the fault stays.

**What we changed.** Two modules rebuilt from Omarchy's own kernel source and installed in `/lib/modules/$(uname -r)/updates/`, leaving the stock ones in place:

1. `patches/pz13-reenumerate.patch` for `drivers/soundwire/qcom.c`. Omarchy's kernel already resets and re-enumerates the bus on runtime resume for v3.1.0 controllers (its patch 2438, made for the Zenbook A16). This extends that to the PZ13's v2.0.0 controller, with a `reenumerate` module parameter.
2. `patches/pz13-pa-watch.patch` for `sound/soc/codecs/wsa884x.c`. Omarchy's kernel carries amplifier fault recovery but keeps it to the Surface Pro 11. This adds a `pa_watch` module parameter to turn it on elsewhere; `pz13-wsa884x.conf` in `/etc/modprobe.d/` sets `pa_watch=1`.

Both patches apply on top of the source Omarchy ships for 7.3-63 (v7.3 plus its patches 2438, and 2154, 2441, 2442).

**Results so far.**

- Bus patch alone: 15 of 15 idle-then-play cycles audible. Sound was still lost after a 45-minute sleep.
- Both patches: sound survived a 53-minute sleep, with no fault logged. That is one sleep; it needs more.
- On an older kernel (7.3-41), where the recovery ran on every board, this machine logged `PA recovery failed ... amplifier left disabled`. So the recovery alone is not known to be enough here.

**Cautions.**

- Do not rebind the `wsa884x-codec` driver on a running system. It crashed the kernel here.
- Do not dump the amplifiers' registers through regmap debugfs on a system you want to keep healthy. Right after one such dump an amplifier began attaching about 4.6 seconds late on every wake-up, until the next reboot.
- Modules in `updates/` are tied to one kernel version. A kernel update goes back to the stock drivers until they are rebuilt.

## Sleep drain (open)

Measured asleep, on battery, with only the power button as a wake source: 0.78 W over 53 minutes and 1.1 W over 4.5 hours. The SoC's deep sleep counters (`/sys/kernel/debug/qcom_stats/cxsd`, `aosd`, `ddr`) stay at zero.

At EL1 under the Gunyah hypervisor, suspend-to-idle disables the virtual timer and the hypervisor then refuses to collapse the CPU subsystem. An experimental out-of-tree module that keeps the timer armed (`cntv_arm`, from [n1c0la84/book4-edge-linux](https://github.com/n1c0la84/book4-edge-linux)) did reach deep sleep on three of five sleeps, at roughly 0.5 W, but each of those woke by itself after about five minutes, and one overnight sleep with it loaded ended in a hard reset. It is not part of this setup.
