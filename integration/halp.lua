-- Optional personal Hyprland rules. Load after Omarchy's defaults.
-- Preserve the document's own alpha instead of dimming the whole window.
o.window({ class = "^org.quickshell$", title = "^HALP$" }, {
  tag = "-default-opacity",
  opacity = "1 1",
  tile = true,
})

-- Pick an unused shortcut in ~/.config/hypr/bindings.lua, for example:
-- o.bind("SUPER + H", "Show HALP", "omarchy-shell shell summon yzjm.halp '{}'")
