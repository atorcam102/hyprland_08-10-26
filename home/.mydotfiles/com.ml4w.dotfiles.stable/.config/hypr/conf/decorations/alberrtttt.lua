-- name: "alberrtttt" — esquinas suaves, sombra oscura discreta
hl.config({
    decoration = {
        rounding = 14,
        rounding_power = 3,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,
        dim_inactive = true,
        dim_strength = 0.08,

        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            offset = "0 4",
            color = "rgba(00000070)",
        },

        blur = {
            enabled   = true,
            size      = 6,
            passes    = 3,
            new_optimizations = true,
            ignore_opacity = true,
            xray = true,
            vibrancy  = 0.2,
        },
    },
})
