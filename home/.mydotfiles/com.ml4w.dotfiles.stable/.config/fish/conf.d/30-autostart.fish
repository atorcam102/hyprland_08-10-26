# -----------------------------------------------------
# AUTOSTART
# -----------------------------------------------------

# -----------------------------------------------------
# Fastfetch (sin logo si la terminal es pequeña)
# -----------------------------------------------------
if status is-interactive
    if test $COLUMNS -lt 75 -o $LINES -lt 22
        fastfetch --logo none
    else
        fastfetch
    end
end
