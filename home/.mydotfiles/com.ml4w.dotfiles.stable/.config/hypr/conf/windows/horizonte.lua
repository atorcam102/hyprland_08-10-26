-- name: "horizonte" — borde fino, huecos amplios alineados con la barra
-- Los colores del borde siguen viniendo de firma.lua (fondo de pantalla).
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 16,
        border_size = 2,
        col = {
            active_border   = { colors = firma.borde(), angle = 135 },
            inactive_border = outline_variant,
        },
        resize_on_border = true,
        extend_border_grab_area = 12,
        allow_tearing = false,
        layout = "dwindle",
        snap = {
            enabled = true,
            window_gap = 12,
            monitor_gap = 16,
            respect_gaps = true,
        },
    }
})
