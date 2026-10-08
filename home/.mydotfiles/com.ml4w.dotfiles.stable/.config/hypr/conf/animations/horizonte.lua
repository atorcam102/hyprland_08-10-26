-- name "horizonte": curvas "emphasized" de Material 3, sin rebote; todo entra desde abajo y se asienta
hl.config({ animations = { enabled = true } })
hl.curve("enfasis",    { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("enfasisSal", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("estandar",   { type = "bezier", points = { {0.2, 0}, {0, 1} } })
hl.curve("lineal",     { type = "bezier", points = { {0, 0}, {1, 1} } })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 4.5, bezier = "enfasis",    style = "popin 92%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.5, bezier = "enfasisSal", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "enfasis" })
hl.animation({ leaf = "border",      enabled = true, speed = 6,   bezier = "estandar" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 3,   bezier = "enfasis" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 2.5, bezier = "enfasisSal" })
hl.animation({ leaf = "fadeSwitch",  enabled = true, speed = 4,   bezier = "estandar" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 4,   bezier = "estandar" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 3.5, bezier = "enfasis",    style = "slide" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 2.5, bezier = "enfasisSal", style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,   bezier = "enfasis",    style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "enfasis", style = "slidevert" })

-- El degradado del borde gira despacio (se controla desde firma.lua)
if firma.bordes_giratorios then
    hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "lineal", style = "loop" })
end
