# omarchy-tablet

Touch controls for [Omarchy](https://omarchy.org) on a tablet or a 2-in-1 with the keyboard off: a rail of buttons on each edge of the screen, touchscreen gestures, an on-screen keyboard that works on the lock screen, and one-finger scrolling and text selection in terminals.

Omarchy is built around the keyboard. Take the keyboard away and there is no way to close a window, switch workspace, open the launcher or type a Wi-Fi password. This fills that gap without a compositor plugin: it is a shell plugin, a small daemon that reads the touchscreen directly, and a few scripts.

## What you get

### The rails

A rail on each edge of the screen, shown while the machine is in tablet mode. Windows stop at them, so they never cover anything. A big tablet is held in both hands with a thumb on each edge, so the buttons are split by hand, and the most used sit lowest.

**Right rail**, top to bottom:

| Button | Does |
|---|---|
| Close | Closes the focused window. Asks first: one tap arms it ("Close?"), a second tap within 3 s closes. |
| Maximise | Fills the screen with the focused window, or restores it. The bar and rails stay. |
| Scroll strip | Drag along it to scroll the focused window. Let go while moving and it keeps going. |
| Switch | Focuses the next window on the workspace. If the current one fills the screen, the next takes its place. |
| Keyboard | Shows or hides the on-screen keyboard. |
| Enter | Sends Enter to the focused app. |
| Mic | Push-to-talk for a dictation tool. Only shown if you have one set up (see [Dictation](#dictation)). |

**Left rail**, top to bottom:

| Button | Does |
|---|---|
| Stay awake | While lit: no screensaver, no auto-lock, no screen-off. Same state as the bar's mug indicator. |
| Volume up / down | Hold to keep going. Omarchy's own volume command, so its on-screen display shows. |
| Play / pause | Hold for the next track. |
| Launcher | Opens the app menu. |
| ‹ n › | Previous / next workspace, with the current number. Hold an arrow to take the focused window along. |

`tablet-mode rails right` puts everything except the media and volume buttons on a single right-hand rail; `tablet-mode rails both` brings the second one back. An upright screen always gets the single rail, along the bottom edge.

The rails follow your theme: the shell's colours, corner radius, border and gaps.

### Gestures

| Gesture | Does |
|---|---|
| Three fingers left / right | Next / previous workspace |
| Three fingers up | App launcher |
| Three fingers down | Next window on this workspace |
| Four fingers up / down | Maximise / restore the focused window |
| Hold one finger still | Copy / Paste / Select all menu beside the finger (not in browsers, which have their own) |

### Terminals

Ghostty does little useful with a finger. With its scrollbar on, a touch drag scrolls one line per pixel; with it off, a drag does nothing; it never selects text by touch. So the installer turns the scrollbar off and the gesture daemon supplies both, as ordinary mouse input:

| Gesture over a terminal | Does |
|---|---|
| Drag up / down | Scrolls at about finger speed. Lift while moving and it flings; touch to stop. |
| Hold, then drag, then lift | Selects from where you held to where you lifted. The Copy / Paste menu appears beside it. |
| Drag that starts sideways | Selects, without the hold. |
| Two fingers up / down | Scrolls. |

The selection is highlighted when you lift, not while you drag. GTK gives a widget's click gesture to one input at a time, so the terminal ignores mouse input for as long as a finger rests on it; the drag is played to it once the finger is up.

Terminals recognised: Ghostty, foot, Alacritty, kitty, WezTerm (`TABLET_GESTURES_SCROLL_CLASSES` to change). The scrollbar setting and the measurements are Ghostty's; the others are untested.

### Also

- **On-screen keyboard** ([wvkbd](https://github.com/jjsullivan5196/wvkbd)) that appears over the lock screen when there is no keyboard to unlock with, and sits above Omarchy's panels, so typing a Wi-Fi password does not close the Wi-Fi panel.
- **Power button**: a tap locks, a hold opens the System menu (in tablet mode; with a keyboard attached it opens the menu as usual).
- **Screen timeout**: the display switches off after ten minutes without input. Omarchy's idle service locks but never blanks, which burns an OLED. Films and Stay awake are respected.

## Install

Needs Omarchy 4 (Hyprland with the Lua config, omarchy-shell) and a touchscreen.

```sh
git clone https://github.com/cryptob1/omarchy-tablet
cd omarchy-tablet
./install.sh
```

The installer installs `wvkbd` (AUR), `ydotool` and `jq` if they are missing (`--no-deps` to skip), copies the commands to `~/.local/bin`, enables the two shell plugins and the gesture service, adds one `require` line to `~/.config/hypr/hyprland.lua`, appends `scrollbar = never` to your Ghostty config, and restarts the shell. `ydotoold` must be running; the installer warns if it is not.

`./uninstall.sh` removes all of it again.

## Tablet mode

The rails show while the machine is in tablet mode. There is one switch:

```sh
tablet-mode set tablet     # show the rails
tablet-mode set laptop     # hide them
tablet-mode toggle
```

**Detachable keyboard.** List the keyboard's USB id (`lsusb`) and the mode follows it: tablet while it is off, laptop while it is on.

```sh
mkdir -p ~/.config/tablet-mode
echo "1234:abcd   # my keyboard dock" >> ~/.config/tablet-mode/keyboards
systemctl --user enable --now tablet-mode-watch.service
```

**Anything else** (a fold sensor, a hotkey): call `tablet-mode set …` yourself. Every executable in `~/.config/tablet-mode/hooks.d/` runs with the new mode as its argument.

## Dictation

The mic is a push-to-talk key for whatever dictation tool you use. Give it two executables:

```
~/.config/tablet-mode/mic-press      # run when the finger lands on the mic
~/.config/tablet-mode/mic-release    # run when it lifts
```

then `tablet-mode dictation on`. If the tool writes `recording` / `transcribing` / `idle` to `$XDG_RUNTIME_DIR/tablet-mode/mic-state`, the button turns red while it listens and pulses while it transcribes.

The button never takes keyboard focus, and focus is held on the window you were writing in until dictation finishes, so the text lands where you meant it.

`tablet-mode mic always` keeps a small floating mic, Enter and keyboard stack on screen with the keyboard attached too.

## How it works

- `shell/plugins/tablet.rail` — the rail, the floating stack and the long-press menu, as an omarchy-shell service plugin (Quickshell QML).
- `shell/plugins/tablet.screenoff` — the screen timeout.
- `bin/tablet-gestures` — a user service that reads the touchscreen's raw multitouch events and calls `hyprctl` / `ydotool`. Hyprland's own gestures are touchpad-only, and the usual answer (hyprgrass) is a compiled plugin that must be rebuilt for every Hyprland release.
- `bin/tablet-touch` — what the buttons and the menu do; the mic focus lock.
- `bin/tablet-osk`, `bin/tablet-mode`, `bin/tablet-power` — keyboard, mode switch, power button.
- `hypr/omarchy-tablet.lua` — layer rules (keyboard above the lock screen and panels) and the power-button bind.

The scripts' headers record what was tried and did not work, with the measurements. `tests/run.sh` runs the unit tests for the gesture logic.

## Status

Built and used on one machine: an ASUS ProArt PZ13 (Snapdragon, detachable keyboard) on Omarchy 4 with Hyprland 0.57 and Ghostty 1.4. Expect rough edges elsewhere, and please open an issue with what you find.

Known limits:

- A truly fullscreen window (a film) covers the rails. Leave fullscreen to get them back.
- After a fast fling a terminal can be left with a stray highlight; a tap clears it.
- The rail's bottom-edge layout for an upright screen has not been tried on a rotated screen.
- Multi-monitor: the rails are drawn on the first screen only.

## License

MIT
