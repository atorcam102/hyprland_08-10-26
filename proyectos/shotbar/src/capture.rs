//! Captura: slurp elige la zona, grim la guarda, wl-copy la copia.
//!
//! Orden pensado para que se sienta instantáneo: lo primero tras soltar el
//! ratón es grim → portapapeles → aviso a la barra. La miniatura del panel se
//! genera después, cuando el usuario ya puede pegar.

use std::io::{Read, Write};
use std::path::Path;
use std::process::{Command, ExitCode, Stdio};

use serde_json::Value;

use crate::{bar, clipboard, history, panel, theme};

#[derive(Clone, Copy, PartialEq)]
pub enum Mode {
    Region,
    Screen,
    Window,
}

/// Qué hay que pasarle a grim.
enum Target {
    Geometry(String),
    Output(String),
    All,
}

pub fn run(mode: Mode) -> ExitCode {
    // Un atajo pulsado dos veces no debe abrir dos selecciones a la vez.
    let _guard = match history::lock(".capture.lock", false) {
        Ok(Some(l)) => l,
        Ok(None) => return ExitCode::SUCCESS,
        Err(e) => return fail("No se pudo preparar el historial", &e.to_string()),
    };

    // Que el panel no salga en la captura ni tape la selección.
    panel::close_running();

    let target = match mode {
        Mode::Region => match slurp(&[], None) {
            Some(g) => Target::Geometry(g),
            None => return ExitCode::SUCCESS, // selección cancelada (Escape)
        },
        Mode::Window => match window_boxes() {
            Some(boxes) => match slurp(&["-r"], Some(&boxes)) {
                Some(g) => Target::Geometry(g),
                None => return ExitCode::SUCCESS,
            },
            // Sin ventanas visibles: selección libre.
            None => match slurp(&[], None) {
                Some(g) => Target::Geometry(g),
                None => return ExitCode::SUCCESS,
            },
        },
        Mode::Screen => focused_output().map(Target::Output).unwrap_or(Target::All),
    };

    let path = match history::new_path() {
        Ok(p) => p,
        Err(e) => return fail("No se pudo preparar el historial", &e.to_string()),
    };
    // grim escribe en un nombre que el historial ignora y se renombra al final:
    // ni el panel ni la barra ven nunca un PNG a medio escribir.
    let partial = path.with_file_name(format!(
        ".partial-{}",
        path.file_name().unwrap_or_default().to_string_lossy()
    ));

    if let Err(msg) = grim(&target, &partial) {
        let _ = std::fs::remove_file(&partial);
        return fail("La captura ha fallado", &msg);
    }
    if !is_png(&partial) {
        let _ = std::fs::remove_file(&partial);
        return fail("La captura ha fallado", "grim no ha producido un PNG válido");
    }
    if let Err(e) = std::fs::rename(&partial, &path) {
        let _ = std::fs::remove_file(&partial);
        return fail("La captura ha fallado", &e.to_string());
    }

    let copied = clipboard::copy_png(&path);

    {
        // Serializa el recorte con otras capturas/limpiezas concurrentes.
        let _l = history::lock(".history.lock", true).ok().flatten();
        history::prune();
    }

    bar::notify("captured");
    if let Err(e) = copied {
        bar::toast("Captura guardada, pero no copiada", &format!("Portapapeles: {e}"));
    }

    // Fuera del camino crítico: miniatura lista para cuando se abra el panel.
    if let Some(e) = history::list().into_iter().find(|e| e.path == path) {
        let _ = history::ensure_thumb(&e);
    }
    ExitCode::SUCCESS
}

fn fail(summary: &str, body: &str) -> ExitCode {
    eprintln!("shotbar: {summary}: {body}");
    bar::toast(summary, body);
    ExitCode::FAILURE
}

/// Lanza slurp con los colores del tema. None si se cancela.
fn slurp(extra: &[&str], stdin_boxes: Option<&str>) -> Option<String> {
    let p = theme::palette();
    let primary = p["primary"].clone();
    let mut cmd = Command::new("slurp");
    cmd.args(["-w", "2"])
        .args(["-c", &theme::with_alpha(&primary, 0xff)])
        .args(["-s", &theme::with_alpha(&primary, 0x1f)])
        .args(["-b", &theme::with_alpha(&p["shadow"], 0x55)])
        .args(["-B", &theme::with_alpha(&primary, 0x14)])
        .args(extra)
        .stdin(if stdin_boxes.is_some() { Stdio::piped() } else { Stdio::null() })
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    let mut child = cmd.spawn().ok()?;
    if let Some(boxes) = stdin_boxes {
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(boxes.as_bytes());
        } // stdin se cierra aquí: slurp deja de leer cajas
    }
    let out = child.wait_with_output().ok()?;
    let g = String::from_utf8_lossy(&out.stdout).trim().to_string();
    (out.status.success() && !g.is_empty()).then_some(g)
}

fn grim(target: &Target, out: &Path) -> Result<(), String> {
    let mut cmd = Command::new("grim");
    // Compresión baja: el PNG sale mucho antes y el tamaño importa poco en tmpfs.
    cmd.args(["-t", "png", "-l", "1"]);
    match target {
        Target::Geometry(g) => {
            cmd.args(["-g", g]);
        }
        Target::Output(o) => {
            cmd.args(["-o", o]);
        }
        Target::All => {}
    }
    let out_s = cmd
        .arg(out)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .map_err(|e| format!("no se pudo ejecutar grim: {e}"))?;
    if out_s.status.success() {
        Ok(())
    } else {
        Err(String::from_utf8_lossy(&out_s.stderr).trim().to_string())
    }
}

fn is_png(p: &Path) -> bool {
    let mut sig = [0u8; 8];
    std::fs::File::open(p)
        .and_then(|mut f| f.read_exact(&mut sig))
        .map(|_| sig == *b"\x89PNG\r\n\x1a\n")
        .unwrap_or(false)
}

fn hyprctl_json(what: &str) -> Option<Value> {
    let out = Command::new("hyprctl")
        .args(["-j", what])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()?;
    serde_json::from_slice(&out.stdout).ok()
}

fn focused_output() -> Option<String> {
    let mons = hyprctl_json("monitors")?;
    mons.as_array()?
        .iter()
        .find(|m| m["focused"].as_bool() == Some(true))
        .and_then(|m| m["name"].as_str())
        .map(str::to_string)
}

/// Rectángulos de las ventanas visibles, en el formato que slurp -r lee.
fn window_boxes() -> Option<String> {
    let mons = hyprctl_json("monitors")?;
    let mut visible: Vec<i64> = Vec::new();
    for m in mons.as_array()? {
        for key in ["activeWorkspace", "specialWorkspace"] {
            if let Some(id) = m[key]["id"].as_i64().filter(|id| *id != 0) {
                visible.push(id);
            }
        }
    }
    let clients = hyprctl_json("clients")?;
    let mut boxes = String::new();
    for c in clients.as_array()? {
        let ws = c["workspace"]["id"].as_i64().unwrap_or(0);
        if c["mapped"].as_bool() != Some(true)
            || c["hidden"].as_bool() == Some(true)
            || !visible.contains(&ws)
        {
            continue;
        }
        let (Some(x), Some(y), Some(w), Some(h)) = (
            c["at"][0].as_i64(),
            c["at"][1].as_i64(),
            c["size"][0].as_i64(),
            c["size"][1].as_i64(),
        ) else {
            continue;
        };
        if w > 0 && h > 0 {
            let title = c["title"].as_str().unwrap_or("").replace('\n', " ");
            boxes.push_str(&format!("{x},{y} {w}x{h} {title}\n"));
        }
    }
    (!boxes.is_empty()).then_some(boxes)
}
