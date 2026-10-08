//! shotbar — capturas con historial temporal y arrastrar-y-soltar para
//! Hyprland, integradas en la statusbar Quickshell de ML4W.

mod bar;
mod capture;
mod clipboard;
mod drag;
mod history;
mod panel;
mod preview;
mod theme;

use std::process::ExitCode;

const USAGE: &str = "\
uso: shotbar <orden>

  region            selecciona una zona con el ratón y la captura
  screen            captura el monitor con el foco
  window            elige una ventana con el ratón y la captura
  panel [opciones]  abre o cierra el panel del historial
      --output NOMBRE   monitor (p. ej. DP-1)
      --x N             centro horizontal del panel, en px del monitor
      --y N             borde superior de la tarjeta, en px del monitor
  preview [RUTA]    vista grande con zoom (por defecto, la última)
  clear             borra el historial y sus archivos
  count             imprime cuántas capturas hay
  list              imprime las rutas, de la más reciente a la más antigua
  dir               imprime el directorio temporal del historial
";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    // El panel es pequeño y estático: el renderizador cairo arranca en ~60 ms
    // y no inicializa Vulkan/GL, que en algunas GPU (p. ej. virgl en una VM)
    // bloquea el compositor un instante y congela el cursor.
    // Se respeta GSK_RENDERER si el usuario lo ha fijado.
    if std::env::var_os("GSK_RENDERER").is_none() {
        std::env::set_var("GSK_RENDERER", "cairo");
    }
    match args.first().map(String::as_str) {
        Some("region") => capture::run(capture::Mode::Region),
        Some("screen") => capture::run(capture::Mode::Screen),
        Some("window") => capture::run(capture::Mode::Window),
        Some("panel") => match parse_panel(&args[1..]) {
            Ok(o) => panel::toggle(o),
            Err(e) => usage_error(&e),
        },
        Some("preview") => match args.get(1).cloned().or_else(|| {
            history::list().first().map(|e| e.path.display().to_string())
        }) {
            Some(p) => preview::standalone(std::path::Path::new(&p)),
            None => usage_error("no hay capturas"),
        },
        Some("clear") => {
            panel::close_running();
            {
                let _l = history::lock(".history.lock", true).ok().flatten();
                history::clear();
            }
            bar::notify("refresh");
            ExitCode::SUCCESS
        }
        Some("count") => {
            println!("{}", history::count());
            ExitCode::SUCCESS
        }
        Some("list") => {
            for e in history::list() {
                println!("{}", e.path.display());
            }
            ExitCode::SUCCESS
        }
        Some("dir") => {
            println!("{}", history::dir().display());
            ExitCode::SUCCESS
        }
        Some("-h" | "--help" | "help") => {
            print!("{USAGE}");
            ExitCode::SUCCESS
        }
        Some(other) => usage_error(&format!("orden desconocida: {other}")),
        None => usage_error("falta la orden"),
    }
}

fn usage_error(msg: &str) -> ExitCode {
    eprintln!("shotbar: {msg}\n\n{USAGE}");
    ExitCode::from(2)
}

fn parse_panel(args: &[String]) -> Result<panel::Opts, String> {
    let mut o = panel::Opts::default();
    let mut it = args.iter();
    while let Some(a) = it.next() {
        let mut val = || it.next().cloned().ok_or(format!("falta el valor de {a}"));
        let num = |v: String| v.parse::<f64>().map(|f| f.round() as i32).map_err(|_| format!("número inválido: {v}"));
        match a.as_str() {
            "--output" => o.output = Some(val()?).filter(|s| !s.is_empty()),
            "--x" => o.x = Some(num(val()?)?),
            "--y" => o.y = Some(num(val()?)?),
            _ => return Err(format!("opción desconocida: {a}")),
        }
    }
    Ok(o)
}
