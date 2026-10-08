-- name: "alberrtttt" — borde degradado giratorio, el sello de la casa (colores en firma.lua)
hl.config({
    general = {
        gaps_in  = 7,
        gaps_out = 14,
        border_size = 3,
        col = {
            active_border   = { colors = firma.borde(), angle = 45 },
            inactive_border = "rgba(ffffff12)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    }
})
