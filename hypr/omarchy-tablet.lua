-- omarchy-tablet: Hyprland rules and binds for tablet use (installed by install.sh).
local bin = os.getenv("HOME") .. "/.local/bin/"

-- Touch and pen input turned the same way as the screen. `tablet-mode rotate`
-- writes this file; it has to be loaded here because the screen's rotation
-- outlives a reload and a setting made with `hyprctl eval` does not.
local rotation = os.getenv("HOME") .. "/.config/hypr/omarchy-tablet-rotation.lua"
local probe = io.open(rotation, "r")
if probe then
  probe:close()
  dofile(rotation)
end

-- The on-screen keyboard must reach the lock screen, or a tablet with its
-- keyboard detached cannot be unlocked. 2 = drawn above the lock screen AND
-- allowed to take touches there. Only wvkbd: it types, it shows nothing.
hl.layer_rule({ name = "tablet-osk-above-lock", match = { namespace = "wvkbd" }, above_lock = 2 })
hl.layer_rule({ name = "tablet-keys-above-lock", match = { namespace = "^omarchy-tablet-keys$" }, above_lock = 2 })

-- ...and above every other Overlay surface, so a key press reaches the
-- keyboard and not a shell panel's "touch outside to close" area (see
-- bin/tablet-osk). Within a layer Hyprland otherwise stacks by map order,
-- which put the keyboard under any panel opened after it. NEGATIVE is on top:
-- a higher `order` sorts a layer earlier, which is further down the stack
-- (tried 100 first; the keyboard went to the bottom).
hl.layer_rule({ name = "tablet-osk-on-top", match = { namespace = "wvkbd" }, order = -100 })
-- The same for the split thumb keyboard (shell plugin tablet.rail).
hl.layer_rule({ name = "tablet-keys-on-top", match = { namespace = "^omarchy-tablet-keys$" }, order = -100 })

-- The button rail (shell plugin tablet.rail) is a see-through card like
-- Omarchy's own surfaces. Blur what is behind it whenever blur is on at all
-- (Appearance > Glassy), with the same rule Omarchy gives its bar and menus.
hl.layer_rule({ name = "tablet-rail-blur", match = { namespace = "^omarchy-tablet-rail$" }, blur = true, ignore_alpha = 0.3 })

-- Power button. Omarchy opens the System menu on press. Without a keyboard a
-- short press should do what it does on every tablet — lock and blank the
-- screen — and a long press should still reach the menu (to shut down).
-- bin/tablet-power decides which; with a keyboard attached it is the menu,
-- as before.
hl.unbind("XF86PowerOff")
o.bind_hold("XF86PowerOff", "Power button: tap locks (tablet), hold opens the System menu",
  bin .. "tablet-power press", nil, bin .. "tablet-power release", { locked = true })
