-- name "alberrtttt": entrada con rebote corto, workspaces que se deslizan
hl.config({ animations = { enabled = true } })
hl.curve("albert",   { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.curve("rebote",   { type = "bezier", points = { {0.34, 1.4}, {0.64, 1} } })
hl.curve("lineal",   { type = "bezier", points = { {0, 0}, {1, 1} } })

hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4,   bezier = "rebote", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3,   bezier = "albert", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,  bezier = "albert" })
hl.animation({ leaf = "border",     enabled = true, speed = 8,   bezier = "albert" })
hl.animation({ leaf = "fade",       enabled = true, speed = 3,   bezier = "albert" })
hl.animation({ leaf = "layers",     enabled = true, speed = 3,   bezier = "albert", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5, bezier = "albert", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "albert", style = "slidefadevert 15%" })

-- El degradado del borde da vueltas sin parar
if firma.bordes_giratorios then
    hl.animation({ leaf = "borderangle", enabled = true, speed = 80, bezier = "lineal", style = "loop" })
end
