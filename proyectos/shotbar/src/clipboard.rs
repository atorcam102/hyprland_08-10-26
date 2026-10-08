//! Portapapeles vía wl-copy.
//!
//! wl-copy se queda en segundo plano sirviendo la imagen (hace fork), así que
//! el proceso que esperamos termina enseguida y no deja zombis. Así el
//! contenido sobrevive aunque shotbar o el panel ya hayan terminado.

use std::fs::File;
use std::io;
use std::path::Path;
use std::process::{Command, Stdio};

pub fn copy_png(path: &Path) -> io::Result<()> {
    let file = File::open(path)?;
    let status = Command::new("wl-copy")
        .args(["--type", "image/png"])
        .stdin(file)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    if status.success() {
        Ok(())
    } else {
        Err(io::Error::other(format!("wl-copy terminó con {status}")))
    }
}
