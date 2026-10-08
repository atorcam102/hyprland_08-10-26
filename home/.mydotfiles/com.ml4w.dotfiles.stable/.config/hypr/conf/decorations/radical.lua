-- name: "Radical" — brutalist: sharp corners, hard offset shadow
hl.config({
    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 0.80,
        fullscreen_opacity = 1.0,
        dim_inactive = false,
        dim_strength = 0.15,

        shadow = { enabled = false },

        blur = {
            enabled   = true,
            size      = 8,
            passes    = 3,
            new_optimizations = on,
            ignore_opacity = true,
            xray = true,
            vibrancy  = 0.3,
        },
    },
})
