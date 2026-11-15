#!/bin/bash
# Removes what install.sh installed. Packages (wvkbd, ydotool, jq) are left.
set -uo pipefail
systemctl --user disable --now tablet-gestures.service tablet-mode-watch.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/tablet-gestures.service" "$HOME/.config/systemd/user/tablet-mode-watch.service"
systemctl --user daemon-reload
pkill -x wvkbd-mobintl 2>/dev/null || true
for p in tablet.rail tablet.screenoff; do
  omarchy plugin disable "$p" >/dev/null 2>&1 || true
  rm -rf "$HOME/.config/omarchy/plugins/$p"
done
for b in tablet-gestures tablet-touch tablet-osk tablet-mode tablet-power; do rm -f "$HOME/.local/bin/$b"; done
rm -f "$HOME/.config/hypr/omarchy-tablet.lua"
conf="$HOME/.config/hypr/hyprland.lua"
[ -f "$conf" ] && sed -i '/omarchy-tablet (https:\/\/github.com\/cryptob1\/omarchy-tablet)/d; /require("hypr.omarchy-tablet")/d' "$conf"
gconf="$HOME/.config/ghostty/config"
[ -f "$gconf" ] && sed -i '/^# omarchy-tablet: touch scrolling is done by tablet-gestures;$/,/^scrollbar = never$/d' "$gconf"
hyprctl reload >/dev/null 2>&1 || true
omarchy restart shell >/dev/null 2>&1 || true
echo "[omarchy-tablet] removed. State and config are kept in ~/.local/state/tablet-mode and ~/.config/tablet-mode."
