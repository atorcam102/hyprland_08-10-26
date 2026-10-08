--       _ _                 _   _   _   _
--  __ _| | |__  ___ _ _ _ _| |_| |_| |_| |_
-- / _` | | '_ \/ -_) '_| '_|  _|  _|  _|  _|
-- \__,_|_|_.__/\___|_| |_|  \__|\__|\__|\__|
--
-- El Hyprland de Albert (alberrtttt)
-- Identidad y colores: firma.lua  ·  Atajos propios: conf/keybindings/custom.lua
-- Cambiar de estilo: SUPER + F1

-- FUNCTIONS
require("functions")

-- MONITORS
require("monitors")
require("conf.monitor")

-- INPUT
require("input")

-- GESTURE
require("gestures")

-- AUTOSTART
require("conf.autostart")

-- COLORS
require("colors")
require("firma")

-- CONFIGURATION
require("conf.environment")
require("conf.window")
require("conf.decoration")
require("conf.layout")
require("conf.workspace")
require("conf.misc")
require("conf.keybinding")
require("conf.windowrule")
require("conf.animation")
require("conf.ml4w")

-- CUSTOM
local f = io.open(os.getenv("HOME") .. "/.config/hypr/custom.lua", "r")
if f then
    f:close()
    require("custom")
end

-- HYPRMOD
require("hyprland-gui")
