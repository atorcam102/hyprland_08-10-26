-- name: "Minimal Dark"
hl.config({
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 0.92,
        fullscreen_opacity = 1.0,
        rounding_power = 3,

        shadow = {
            enabled = true,
            range = 20,
            render_power = 3,
            color = "rgba(00000060)",
        },

        blur = {
            enabled   = true,
            size      = 5,
            passes    = 3,
            new_optimizations = on,
            ignore_opacity = true,
            xray = true,
            vibrancy  = 0.17,
        },
    },
})
