#!/bin/bash
# Removes what install.sh installed. Packages (wvkbd, ydotool, jq) are left.
set -uo pipefail
"$HOME/.local/bin/tablet-mode" bar-colors clear 2>/dev/null || true   # give the bar its own colours back
systemctl --user disable --now tablet-gestures.service tablet-mode-watch.service tablet-rotate.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/tablet-gestures.service" "$HOME/.config/systemd/user/tablet-mode-watch.service" "$HOME/.config/systemd/user/tablet-rotate.service"
systemctl --user daemon-reload
pkill -x wvkbd-mobintl 2>/dev/null || true
for p in tablet.rail tablet.screenoff; do
  omarchy plugin disable "$p" >/dev/null 2>&1 || true
  rm -rf "$HOME/.config/omarchy/plugins/$p"
done
for b in tablet-gestures tablet-touch tablet-osk tablet-mode tablet-power tablet-pin; do rm -f "$HOME/.local/bin/$b"; done
rm -f "$HOME/.config/hypr/omarchy-tablet.lua" "$HOME/.config/hypr/omarchy-tablet-rotation.lua"
rm -f "$HOME/.local/share/omarchy-tablet/tap.wav"; rmdir "$HOME/.local/share/omarchy-tablet" 2>/dev/null || true
conf="$HOME/.config/hypr/hyprland.lua"
[ -f "$conf" ] && sed -i '/omarchy-tablet (https:\/\/github.com\/cryptob1\/omarchy-tablet)/d; /require("hypr.omarchy-tablet")/d' "$conf"
gconf="$HOME/.config/ghostty/config"
[ -f "$gconf" ] && sed -i '/^# omarchy-tablet: touch scrolling is done by tablet-gestures;$/,/^scrollbar = never$/d' "$gconf"
hyprctl reload >/dev/null 2>&1 || true
omarchy restart shell >/dev/null 2>&1 || true
echo "[omarchy-tablet] removed. State and config are kept in ~/.local/state/tablet-mode and ~/.config/tablet-mode."

# The top bar may be tucked away (shell plugin tablet.rail): bring it back.
command -v omarchy-toggle-bar >/dev/null 2>&1 && omarchy-toggle-bar off >/dev/null 2>&1 || true
