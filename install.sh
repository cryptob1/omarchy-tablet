#!/bin/bash
# omarchy-tablet installer. Run from a clone of the repo:  ./install.sh
#
# Installs for the current user only. Re-running it updates an existing install.
#   --no-deps   do not install missing packages (wvkbd, ydotool, jq)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
DEPS=1
[ "${1:-}" = "--no-deps" ] && DEPS=0
say()  { echo "[omarchy-tablet] $*"; }
warn() { echo "[omarchy-tablet] warning: $*" >&2; }

command -v omarchy-shell >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1 \
  || { echo "omarchy-tablet needs Omarchy 4 (omarchy-shell and Hyprland)." >&2; exit 1; }

# --- packages ---------------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1; }
if [ "$DEPS" = 1 ]; then
  need python3 || sudo pacman -S --needed --noconfirm python
  need jq      || sudo pacman -S --needed --noconfirm jq
  need ydotool || sudo pacman -S --needed --noconfirm ydotool
  # The on-screen keyboard. AUR, a small C build.
  need wvkbd-mobintl || { need yay && yay -S --needed --noconfirm wvkbd; }
fi
need wvkbd-mobintl || warn "wvkbd is not installed: the keyboard button will do nothing"
need ydotool       || warn "ydotool is not installed: scrolling, Enter and selection will do nothing"
pgrep -x ydotoold >/dev/null 2>&1 \
  || warn "ydotoold is not running (try: systemctl --user enable --now ydotool.service)"

# --- commands ---------------------------------------------------------------
for b in bin/*; do install -Dm755 "$b" "$HOME/.local/bin/$(basename "$b")"; done

# --- the tap sound (`tablet-mode sounds on`) ---------------------------------
install -Dm644 sounds/tap.wav "$HOME/.local/share/omarchy-tablet/tap.wav"

# --- shell plugins: the rail and the screen timeout -------------------------
for p in tablet.rail tablet.screenoff; do
  rm -rf "$HOME/.config/omarchy/plugins/$p"
  mkdir -p "$HOME/.config/omarchy/plugins/$p"
  install -m644 "shell/plugins/$p"/* "$HOME/.config/omarchy/plugins/$p/"
done
# Rescan first: enabling a plugin the registry has not discovered is refused.
omarchy-shell -q shell rescanPlugins >/dev/null 2>&1 || true
sleep 1
for p in tablet.rail tablet.screenoff; do omarchy plugin enable "$p" >/dev/null 2>&1 || true; done

# --- Hyprland: keyboard above the lock screen and panels, power button ------
install -Dm644 hypr/omarchy-tablet.lua "$HOME/.config/hypr/omarchy-tablet.lua"
conf="$HOME/.config/hypr/hyprland.lua"
if [ -f "$conf" ] && ! grep -qF 'require("hypr.omarchy-tablet")' "$conf"; then
  printf '\n-- omarchy-tablet (https://github.com/cryptob1/omarchy-tablet)\nrequire("hypr.omarchy-tablet")\n' >> "$conf"
  say "added the omarchy-tablet rules to $conf"
fi

# --- Ghostty: its scrollbar makes a finger drag scroll one line per pixel ----
# Without it a touch drag does nothing, and tablet-gestures supplies scrolling
# and selection. Appended, never copied in: the file is yours.
gconf="$HOME/.config/ghostty/config"
if [ -f "$gconf" ] && ! grep -qE '^[[:space:]]*scrollbar[[:space:]]*=' "$gconf"; then
  printf '\n# omarchy-tablet: touch scrolling is done by tablet-gestures;\n# the scrollbar makes a finger drag scroll one line per pixel.\nscrollbar = never\n' >> "$gconf"
  pkill -USR2 -x ghostty 2>/dev/null || true
fi

# --- services ---------------------------------------------------------------
for u in systemd/user/*.service; do install -Dm644 "$u" "$HOME/.config/systemd/user/$(basename "$u")"; done
systemctl --user daemon-reload
systemctl --user enable tablet-gestures.service >/dev/null 2>&1 || true
systemctl --user restart tablet-gestures.service >/dev/null 2>&1 || true
[ -f "$HOME/.config/tablet-mode/keyboards" ] \
  && systemctl --user enable --now tablet-mode-watch.service >/dev/null 2>&1 || true

# --- the mic, if there is something for it to talk to ------------------------
if [ -x "$HOME/.config/tablet-mode/mic-press" ] || [ -x "$HOME/.local/bin/cortex-ctl" ]; then
  "$HOME/.local/bin/tablet-mode" dictation on
fi

hyprctl reload >/dev/null 2>&1 || true
# Plugin files only load on a shell restart; a rescan keeps running the old QML.
omarchy restart shell >/dev/null 2>&1 || true

say "installed. Mode is now: $("$HOME/.local/bin/tablet-mode" status)"
say "show the rail:   tablet-mode set tablet     hide it:   tablet-mode set laptop"
say "detachable keyboard? list its USB id in ~/.config/tablet-mode/keyboards (see README)"
