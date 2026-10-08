-- name: "horizonte" — esquinas tipo squircle, sombra amplia y suave, cristal en paneles
-- Parte del rediseño "Horizonte": misma paleta de matugen, nueva forma.
hl.config({
    decoration = {
        rounding = 16,
        rounding_power = 4,          -- esquina continua (squircle) en vez de arco
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        fullscreen_opacity = 1.0,
        dim_inactive = true,
        dim_strength = 0.06,
        border_part_of_window = true,

        shadow = {
            enabled = true,
            range = 36,
            render_power = 4,
            offset = "0 10",
            scale = 0.98,
            color = "rgba(00000059)",
            color_inactive = "rgba(00000033)",
        },

        blur = {
            enabled   = true,
            size      = 8,
            passes    = 3,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
            noise = 0.015,
            contrast = 1.0,
            brightness = 0.9,
            vibrancy  = 0.25,
            vibrancy_darkness = 0.2,
            popups = true,
            popups_ignorealpha = 0.5,
        },
    },
})

-- Cristal detrás de los paneles del escritorio (barra, dock, menús, lanzador, notificaciones)
for _, ns in ipairs({ "quickshell", "rofi", "swaync-control-center", "swaync-notification-window" }) do
    hl.layer_rule({ match = { namespace = ns }, blur = true, ignore_alpha = 0.5 })
end
