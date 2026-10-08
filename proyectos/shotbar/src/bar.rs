//! Aviso a la barra (statusbar Quickshell de ML4W).
//!
//! El módulo `screenshots` de la barra expone un IpcHandler con target
//! `shotbar`. Se le avisa con `qs ipc call` en vez de reiniciar nada. Si la
//! barra no está corriendo, se recurre a una notificación breve para que la
//! captura nunca pase desapercibida.

use std::process::{Command, Stdio};

/// `captured`: refresca el contador y hace destellar el icono.
/// `refresh`: solo refresca el contador.
pub fn notify(method: &str) {
    let fallback = if method == "captured" {
        // Solo si la barra no responde.
        " || notify-send -a Shotbar -i camera-photo-symbolic -t 1500 -h string:x-canonical-private-synchronous:shotbar 'Captura copiada' 'Lista para pegar o arrastrar'"
    } else {
        ""
    };
    let script = format!("qs ipc call shotbar {method} >/dev/null 2>&1{fallback}");
    spawn_reaped(Command::new("sh")
        .args(["-c", &script])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null()));
}

/// Mensaje breve y no intrusivo (se reemplaza a sí mismo si se repite).
pub fn toast(summary: &str, body: &str) {
    spawn_reaped(Command::new("notify-send")
        .args([
            "-a", "Shotbar", "-i", "camera-photo-symbolic", "-t", "2500",
            "-h", "string:x-canonical-private-synchronous:shotbar",
            summary, body,
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        );
}

/// Lanza sin bloquear y recoge al hijo desde un hilo: ni espera ni zombis,
/// también en el proceso del panel, que vive más.
pub fn spawn_reaped(cmd: &mut Command) {
    if let Ok(mut child) = cmd.spawn() {
        std::thread::spawn(move || {
            let _ = child.wait();
        });
    }
}
