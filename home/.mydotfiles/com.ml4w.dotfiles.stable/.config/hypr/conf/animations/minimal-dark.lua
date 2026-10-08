-- name "Minimal Dark": smooth and short
hl.config({ animations = { enabled = true } })
hl.curve("smooth", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 3.5, bezier = "smooth", style = "popin 88%" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "smooth" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "smooth" })
hl.animation({ leaf = "layers", enabled = true, speed = 3, bezier = "smooth", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "smooth", style = "slidefadevert 12%" })
