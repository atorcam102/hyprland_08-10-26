-- name: "Radical" — sharp corners, hairline border, tight gaps
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 12,
        border_size = 1,
        col = {
            active_border   = "rgba(ffffff30)",
            inactive_border = "rgba(00000000)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    }
})
