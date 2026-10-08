-- name "Radical": abrupt and fast
hl.config({ animations = { enabled = true } })
hl.curve("snap", { type = "bezier", points = { {0.9, 0}, {0.1, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "snap", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "snap" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "snap" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "snap", style = "slide" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "snap", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "snap", style = "slidevert" })
