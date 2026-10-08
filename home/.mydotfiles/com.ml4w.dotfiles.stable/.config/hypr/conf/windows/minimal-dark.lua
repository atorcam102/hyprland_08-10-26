-- name: "Minimal Dark"
hl.config({
    general = {
        gaps_in  = 6,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border   = { colors = {primary, secondary}, angle = 45 },
            inactive_border = "rgba(ffffff12)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    }
})
