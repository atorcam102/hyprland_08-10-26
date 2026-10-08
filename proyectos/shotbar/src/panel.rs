//! Panel del historial: GTK4 + gtk4-layer-shell.
//!
//! Una superficie layer-shell (capa Overlay) transparente y a pantalla
//! completa, con la tarjeta colgando bajo el módulo de la barra igual que el
//! calendario. Un clic fuera de la tarjeta (también sobre el propio módulo)
//! cae en ella y la cierra; teclado exclusivo para Escape / Espacio. Durante
//! un arrastre suelta teclado y puntero para que el destino reciba el drop.
//! Al no ser ventanas toplevel no aparecen en Alt+Tab ni en la lista de apps.
//!
//! Sin daemon: el panel es un proceso corto que vive mientras está abierto.
//! Un archivo pid en el directorio del historial permite cerrarlo (toggle) y
//! que una captura lo aparte antes de hacerse.

use std::cell::RefCell;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::rc::Rc;
use std::time::Duration;

use gtk::prelude::*;
use gtk::{gdk, gio, glib};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

use crate::history::{self, Entry};
use crate::{bar, clipboard, drag, theme};

/// Medidas de la tarjeta (px lógicos).
const SHELL_PAD: i32 = 20; // hueco para la sombra (cardInset del calendario)
const INNER: i32 = 332; // ancho útil dentro de la tarjeta
const CARD_W: i32 = INNER + 2 * 14 + 2; // + padding + borde
const PANEL_W: i32 = CARD_W + 2 * SHELL_PAD;
const GAP: i32 = 10;

#[derive(Default, Clone)]
pub struct Opts {
    pub output: Option<String>,
    /// Centro horizontal deseado (coordenadas del monitor).
    pub x: Option<i32>,
    /// Borde superior de la tarjeta (coordenadas del monitor).
    pub y: Option<i32>,
}

// ---------------------------------------------------------------- pid / toggle

fn pid_file() -> PathBuf {
    history::dir().join(".panel.pid")
}

fn running_pid() -> Option<i32> {
    let pid: i32 = std::fs::read_to_string(pid_file()).ok()?.trim().parse().ok()?;
    if pid <= 0 || pid == std::process::id() as i32 {
        return None;
    }
    // Comprueba que el pid sigue siendo nuestro (y no uno reutilizado).
    let comm = std::fs::read_to_string(format!("/proc/{pid}/comm")).ok()?;
    (comm.trim() == "shotbar").then_some(pid)
}

/// Cierra el panel si está abierto y espera (máx. ~0,5 s) a que desaparezca.
/// Devuelve true si había uno abierto.
pub fn close_running() -> bool {
    let Some(pid) = running_pid() else { return false };
    unsafe { libc::kill(pid, libc::SIGTERM) };
    for _ in 0..50 {
        if !Path::new(&format!("/proc/{pid}")).exists() {
            break;
        }
        std::thread::sleep(Duration::from_millis(10));
    }
    true
}

pub fn toggle(opts: Opts) -> ExitCode {
    if close_running() {
        return ExitCode::SUCCESS;
    }
    run(opts)
}

// ---------------------------------------------------------------------- panel

struct Ui {
    main_loop: glib::MainLoop,
    panel: gtk::Window,
    body: gtk::Box,
    subtitle: gtk::Label,
    clear_btn: gtk::Button,
    drag_hooks: Rc<drag::Hooks>,
    monitor: Option<gdk::Monitor>,
    /// Captura bajo el puntero (para la vista previa con Espacio).
    hovered: RefCell<Option<PathBuf>>,
    preview: RefCell<Option<gtk::Window>>,
}

pub fn run(opts: Opts) -> ExitCode {
    if gtk::init().is_err() {
        eprintln!("shotbar: no se pudo iniciar GTK (¿hay sesión Wayland?)");
        return ExitCode::FAILURE;
    }
    if !gtk4_layer_shell::is_supported() {
        eprintln!("shotbar: el compositor no soporta wlr-layer-shell");
        return ExitCode::FAILURE;
    }
    let _ = history::ensure_dirs();
    let _ = std::fs::write(pid_file(), std::process::id().to_string());

    let display = gdk::Display::default().expect("display");
    install_css();

    let monitor = find_monitor(&display, opts.output.as_deref());
    let main_loop = glib::MainLoop::new(None, false);

    // Una sola superficie a pantalla completa y transparente; la tarjeta va
    // dentro, colocada bajo el módulo de la barra. Un clic en cualquier punto
    // que no sea la tarjeta cae en esta misma superficie y la cierra.
    // (Con dos superficies no funciona: Hyprland encierra el puntero en la
    // capa que tiene el teclado en exclusiva.)
    let panel = gtk::Window::new();
    panel.add_css_class("shotbar");
    panel.init_layer_shell();
    panel.set_namespace(Some("shotbar"));
    panel.set_layer(Layer::Overlay);
    panel.set_keyboard_mode(KeyboardMode::Exclusive);
    panel.set_exclusive_zone(-1);
    for e in [Edge::Top, Edge::Bottom, Edge::Left, Edge::Right] {
        panel.set_anchor(e, true);
    }
    if let Some(m) = &monitor {
        panel.set_monitor(Some(m));
    }
    let mon_w = monitor.as_ref().map(|m| m.geometry().width()).unwrap_or(1920);

    let root = gtk::Box::new(gtk::Orientation::Vertical, 0);
    root.add_css_class("shotbar-root");
    let shell = gtk::Box::new(gtk::Orientation::Vertical, 0);
    shell.add_css_class("shotbar-shell");
    shell.set_valign(gtk::Align::Start);
    match opts.x {
        Some(x) => {
            shell.set_halign(gtk::Align::Start);
            shell.set_margin_start((x - PANEL_W / 2).clamp(0, (mon_w - PANEL_W).max(0)));
        }
        None => {
            // Desde un atajo: esquina superior derecha, bajo la barra.
            shell.set_halign(gtk::Align::End);
            shell.set_margin_end(8);
        }
    }
    let top = opts.y.unwrap_or_else(bar_bottom);
    shell.set_margin_top((top - SHELL_PAD).max(0));
    let card = gtk::Box::new(gtk::Orientation::Vertical, 12);
    card.add_css_class("shotbar-card");
    card.set_size_request(CARD_W, -1);
    shell.append(&card);
    root.append(&shell);
    panel.set_child(Some(&root));

    // Clic fuera de la tarjeta (incluido el margen de la sombra) = cerrar.
    let click_out = gtk::GestureClick::new();
    click_out.set_button(0);
    click_out.connect_pressed(glib::clone!(
        #[strong] main_loop,
        #[weak] root,
        #[weak] shell,
        move |g, _, x, y| {
            let hit = root.pick(x, y, gtk::PickFlags::DEFAULT);
            if hit.as_ref() == Some(root.upcast_ref()) || hit.as_ref() == Some(shell.upcast_ref()) || hit.is_none() {
                g.set_state(gtk::EventSequenceState::Claimed);
                main_loop.quit();
            }
        }
    ));
    root.add_controller(click_out);

    // Cabecera: título + estado + «Limpiar».
    let header = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let titles = gtk::Box::new(gtk::Orientation::Vertical, 2);
    titles.set_hexpand(true);
    let title = gtk::Label::new(Some("Capturas"));
    title.add_css_class("shotbar-title");
    title.set_xalign(0.0);
    let subtitle = gtk::Label::new(None);
    subtitle.add_css_class("shotbar-subtitle");
    subtitle.set_xalign(0.0);
    titles.append(&title);
    titles.append(&subtitle);
    let clear_btn = gtk::Button::with_label("Limpiar");
    clear_btn.add_css_class("shotbar-text-button");
    clear_btn.set_valign(gtk::Align::Center);
    clear_btn.set_focusable(false);
    clear_btn.set_focus_on_click(false);
    clear_btn.set_tooltip_text(Some("Borra todas las capturas temporales"));
    header.append(&titles);
    header.append(&clear_btn);
    card.append(&header);

    let body = gtk::Box::new(gtk::Orientation::Vertical, GAP);
    card.append(&body);

    // Arrastre: mientras dura, la superficie suelta el teclado y deja de
    // recibir el puntero (región de entrada vacía) para que el destino —Chrome,
    // Discord, Telegram, Nautilus…— reciba el movimiento y el drop. Si se
    // suelta en algún sitio, el panel se cierra (con margen para que el destino
    // termine de leer los datos).
    let drag_hooks = Rc::new(drag::Hooks {
        on_begin: Box::new(glib::clone!(
            #[weak] panel,
            move || {
                panel.set_keyboard_mode(KeyboardMode::None);
                set_input_passthrough(&panel, true);
            }
        )),
        on_end: Box::new(glib::clone!(
            #[weak] panel,
            #[strong] main_loop,
            move |dropped| {
                if dropped {
                    panel.set_visible(false);
                    let ml = main_loop.clone();
                    glib::timeout_add_local_once(Duration::from_millis(1500), move || ml.quit());
                } else {
                    set_input_passthrough(&panel, false);
                    panel.set_keyboard_mode(KeyboardMode::Exclusive);
                }
            }
        )),
    });

    let ui = Rc::new(Ui {
        main_loop: main_loop.clone(),
        panel: panel.clone(),
        body,
        subtitle,
        clear_btn: clear_btn.clone(),
        drag_hooks,
        monitor: monitor.clone(),
        hovered: RefCell::new(None),
        preview: RefCell::new(None),
    });

    clear_btn.connect_clicked(glib::clone!(
        #[strong] ui,
        move |_| {
            {
                let _l = history::lock(".history.lock", true).ok().flatten();
                history::clear();
            }
            bar::notify("refresh");
            rebuild(&ui);
        }
    ));

    // Escape cierra.
    let keys = gtk::EventControllerKey::new();
    // En fase de captura: si no, Espacio «pulsaría» el botón con foco.
    keys.set_propagation_phase(gtk::PropagationPhase::Capture);
    keys.connect_key_pressed(glib::clone!(
        #[strong] ui,
        move |_, key, _, _| match key {
            gdk::Key::Escape => {
                ui.main_loop.quit();
                glib::Propagation::Stop
            }
            gdk::Key::space => {
                let hovered = ui.hovered.borrow().clone();
                if let Some(p) = hovered {
                    crate::preview::open(&ui_preview_host(&ui), &p);
                }
                glib::Propagation::Stop
            }
            _ => glib::Propagation::Proceed,
        }
    ));
    panel.add_controller(keys);

    // Se refresca solo si el historial cambia por fuera (shotbar clear,
    // archivos borrados a mano…), agrupando ráfagas de eventos.
    let monitor_dir = gio::File::for_path(history::dir())
        .monitor_directory(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE)
        .ok();
    let pending: Rc<RefCell<Option<glib::SourceId>>> = Rc::default();
    if let Some(m) = &monitor_dir {
        m.connect_changed(glib::clone!(
            #[strong] ui,
            #[strong] pending,
            move |_, f, _, _| {
                let name = f.basename().unwrap_or_default();
                if name.to_string_lossy().starts_with('.') {
                    return; // pid, locks, temporales
                }
                if let Some(id) = pending.borrow_mut().take() {
                    id.remove();
                }
                let ui = ui.clone();
                let p2 = pending.clone();
                *pending.borrow_mut() = Some(glib::timeout_add_local_once(
                    Duration::from_millis(120),
                    move || {
                        p2.borrow_mut().take();
                        rebuild(&ui);
                    },
                ));
            }
        ));
    }

    // SIGTERM (toggle desde la barra, o una captura que lo aparta) cierra limpio.
    QUIT_LOOP.with(|q| *q.borrow_mut() = Some(main_loop.clone()));
    for sig in [libc::SIGTERM, libc::SIGINT, libc::SIGHUP] {
        unsafe { g_unix_signal_add(sig, Some(on_signal), std::ptr::null_mut()) };
    }

    rebuild(&ui);
    panel.present();
    main_loop.run();

    drop(monitor_dir);
    ui.panel.set_visible(false);
    // Solo borra el pid si sigue siendo el nuestro.
    if std::fs::read_to_string(pid_file()).ok().as_deref().map(str::trim)
        == Some(&std::process::id().to_string())
    {
        let _ = std::fs::remove_file(pid_file());
    }
    ExitCode::SUCCESS
}

thread_local! {
    static QUIT_LOOP: RefCell<Option<glib::MainLoop>> = const { RefCell::new(None) };
}

// glib-unix (dentro de libglib-2.0): la señal llega como un evento más del
// bucle principal, sin código async-signal-unsafe en el manejador.
extern "C" {
    fn g_unix_signal_add(
        signum: libc::c_int,
        handler: glib::ffi::GSourceFunc,
        user_data: glib::ffi::gpointer,
    ) -> libc::c_uint;
}

unsafe extern "C" fn on_signal(_: glib::ffi::gpointer) -> glib::ffi::gboolean {
    QUIT_LOOP.with(|q| {
        if let Some(l) = q.borrow().as_ref() {
            l.quit();
        }
    });
    glib::ffi::GFALSE
}

pub fn find_monitor(display: &gdk::Display, output: Option<&str>) -> Option<gdk::Monitor> {
    let monitors = display.monitors();
    let all: Vec<gdk::Monitor> = (0..monitors.n_items())
        .filter_map(|i| monitors.item(i).and_downcast::<gdk::Monitor>())
        .collect();
    if let Some(name) = output {
        if let Some(m) = all.iter().find(|m| m.connector().as_deref() == Some(name)) {
            return Some(m.clone());
        }
    }
    // Sin nombre: el monitor con el foco según Hyprland.
    let focused = std::process::Command::new("hyprctl")
        .args(["-j", "monitors"])
        .output()
        .ok()
        .and_then(|o| serde_json::from_slice::<serde_json::Value>(&o.stdout).ok())
        .and_then(|v| {
            v.as_array()?
                .iter()
                .find(|m| m["focused"].as_bool() == Some(true))
                .and_then(|m| m["name"].as_str().map(str::to_string))
        });
    focused
        .and_then(|n| all.iter().find(|m| m.connector().as_deref() == Some(n.as_str())).cloned())
        .or_else(|| all.first().cloned())
}

pub fn install_css() {
    let Some(display) = gdk::Display::default() else { return };
    let provider = gtk::CssProvider::new();
    provider.load_from_string(&theme::css(&theme::palette()));
    gtk::style_context_add_provider_for_display(
        &display,
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_USER + 1,
    );
}

/// Región de entrada vacía (el puntero atraviesa la superficie) o completa.
fn set_input_passthrough(win: &gtk::Window, through: bool) {
    let Some(surface) = win.surface() else { return };
    if through {
        surface.set_input_region(Some(&gtk::cairo::Region::create()));
    } else {
        surface.set_input_region(None); // toda la superficie, como por defecto
    }
}

/// Borde inferior de la barra (zona reservada en la config de la statusbar),
/// para cuando el panel se abre desde un atajo y no desde el módulo.
fn bar_bottom() -> i32 {
    let path = theme::home().join(".config/ml4w-statusbar/config.json");
    std::fs::read_to_string(path)
        .ok()
        .and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok())
        .and_then(|v| v["bar"]["reservedHeight"].as_i64())
        .map(|h| h as i32 - 8)
        .unwrap_or(60)
}

// ---------------------------------------------------------------- contenido

fn rebuild(ui: &Rc<Ui>) {
    while let Some(c) = ui.body.first_child() {
        ui.body.remove(&c);
    }
    let entries = history::list();
    ui.clear_btn.set_visible(!entries.is_empty());
    ui.subtitle.set_label(&match entries.len() {
        0 => "Temporales · se borran al apagar".to_string(),
        n => format!("{n} de {} · arrastra o haz clic para copiar", history::MAX_ENTRIES),
    });

    if entries.is_empty() {
        let empty = gtk::Box::new(gtk::Orientation::Vertical, 6);
        empty.add_css_class("shotbar-empty");
        let icon = gtk::Label::new(Some("󰹑"));
        icon.add_css_class("shotbar-empty-icon");
        let t = gtk::Label::new(Some("Sin capturas en esta sesión"));
        t.add_css_class("shotbar-subtitle");
        let hint = gtk::Label::new(Some("Super + Shift + S  ·  Impr"));
        hint.add_css_class("shotbar-time");
        empty.append(&icon);
        empty.append(&t);
        empty.append(&hint);
        ui.body.append(&empty);
        return;
    }

    let mut it = entries.into_iter();
    // La más reciente, grande; el resto en dos columnas.
    if let Some(first) = it.next() {
        ui.body.append(&tile(ui, first, INNER, 150));
    }
    let rest: Vec<Entry> = it.collect();
    for pair in rest.chunks(2) {
        let row = gtk::Box::new(gtk::Orientation::Horizontal, GAP);
        row.set_homogeneous(true);
        for e in pair {
            row.append(&tile(ui, e.clone(), (INNER - GAP) / 2, 80));
        }
        if pair.len() == 1 {
            // Mantiene la misma anchura de columna.
            row.append(&gtk::Box::new(gtk::Orientation::Vertical, 0));
        }
        ui.body.append(&row);
    }
}

fn tile(ui: &Rc<Ui>, e: Entry, width: i32, pic_h: i32) -> gtk::Widget {
    let b = gtk::Box::new(gtk::Orientation::Vertical, 5);
    b.add_css_class("shotbar-shot");
    b.set_size_request(width, -1);
    b.set_cursor_from_name(Some("grab"));
    b.set_tooltip_text(Some("Arrastra a cualquier app · Clic: copiar · Espacio: ver en grande · Clic derecho: más"));

    let pic = gtk::Picture::new();
    pic.add_css_class("shotbar-thumb");
    pic.set_content_fit(gtk::ContentFit::Contain); // conserva la proporción
    pic.set_can_shrink(true);
    pic.set_overflow(gtk::Overflow::Hidden);

    // GtkPicture pide como tamaño natural el de la imagen (640 px), lo que
    // inflaría el panel. Este marco fija el hueco exacto de la miniatura y la
    // imagen se encaja dentro conservando la proporción.
    let frame = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::External)
        .vscrollbar_policy(gtk::PolicyType::External)
        .min_content_width(width - 12 - 2)
        .max_content_width(width - 12 - 2)
        .min_content_height(pic_h)
        .max_content_height(pic_h)
        .propagate_natural_width(false)
        .propagate_natural_height(false)
        .child(&pic)
        .build();
    frame.set_can_target(false); // los clics y el arrastre los gestiona la tarjeta

    let overlay = gtk::Overlay::new();
    overlay.set_child(Some(&frame));
    let badge = gtk::Label::new(None);
    badge.add_css_class("shotbar-badge");
    badge.set_halign(gtk::Align::Center);
    badge.set_valign(gtk::Align::Center);
    badge.set_visible(false);
    overlay.add_overlay(&badge);
    b.append(&overlay);

    let time = gtk::Label::new(Some(&history::format_time(e.modified, "%H:%M:%S")));
    time.add_css_class("shotbar-time");
    time.set_xalign(0.0);
    time.set_margin_start(4);
    b.append(&time);

    // Miniatura en segundo plano: un PNG 4K nunca bloquea la interfaz.
    let entry = e.clone();
    glib::spawn_future_local(glib::clone!(
        #[weak] pic,
        #[weak] time,
        async move {
            let thumb = gio::spawn_blocking(move || history::ensure_thumb(&entry)).await.ok().flatten();
            match thumb.and_then(|t| gdk::Texture::from_filename(t).ok()) {
                Some(tex) => pic.set_paintable(Some(&tex)),
                None => time.set_label("Imagen dañada o eliminada"),
            }
        }
    ));

    let path = e.path.clone();
    drag::attach(&b, path.clone(), &pic, ui.drag_hooks.clone());

    let motion = gtk::EventControllerMotion::new();
    motion.connect_enter(glib::clone!(
        #[strong] ui,
        #[strong] path,
        move |_, _, _| *ui.hovered.borrow_mut() = Some(path.clone())
    ));
    motion.connect_leave(glib::clone!(
        #[strong] ui,
        #[strong] path,
        move |_| {
            let mut h = ui.hovered.borrow_mut();
            if h.as_ref() == Some(&path) {
                *h = None;
            }
        }
    ));
    b.add_controller(motion);

    // Clic izquierdo: copiar otra vez al portapapeles.
    let click = gtk::GestureClick::new();
    click.set_button(gdk::BUTTON_PRIMARY);
    click.connect_released(glib::clone!(
        #[weak] badge,
        #[strong] path,
        move |g, n, _, _| {
            if n != 1 {
                return;
            }
            g.set_state(gtk::EventSequenceState::Claimed);
            match clipboard::copy_png(&path) {
                Ok(()) => flash(&badge, "Copiada"),
                Err(_) => flash(&badge, "No se pudo copiar"),
            }
        }
    ));
    b.add_controller(click);

    // Clic derecho: menú corto.
    let menu_click = gtk::GestureClick::new();
    menu_click.set_button(gdk::BUTTON_SECONDARY);
    menu_click.connect_pressed(glib::clone!(
        #[strong] ui,
        #[weak] b,
        #[weak] badge,
        #[strong] path,
        move |g, _, x, y| {
            g.set_state(gtk::EventSequenceState::Claimed);
            context_menu(&ui, &b, &badge, &path, x, y);
        }
    ));
    b.add_controller(menu_click);

    b.upcast()
}

fn flash(badge: &gtk::Label, text: &str) {
    badge.set_label(text);
    badge.set_visible(true);
    glib::timeout_add_local_once(
        Duration::from_millis(900),
        glib::clone!(
            #[weak] badge,
            move || badge.set_visible(false)
        ),
    );
}

fn context_menu(ui: &Rc<Ui>, parent: &gtk::Box, badge: &gtk::Label, path: &Path, x: f64, y: f64) {
    let pop = gtk::Popover::new();
    pop.add_css_class("shotbar-menu");
    pop.set_has_arrow(false);
    pop.set_parent(parent);
    pop.set_pointing_to(Some(&gdk::Rectangle::new(x as i32, y as i32, 1, 1)));
    pop.set_position(gtk::PositionType::Bottom);
    pop.connect_closed(|p| {
        let p = p.clone();
        // Se desengancha tras la animación de cierre.
        glib::idle_add_local_once(move || p.unparent());
    });

    let list = gtk::Box::new(gtk::Orientation::Vertical, 2);
    let item = |label: &str, destructive: bool| {
        let btn = gtk::Button::new();
        let l = gtk::Label::new(Some(label));
        l.set_xalign(0.0);
        btn.set_child(Some(&l));
        btn.add_css_class("shotbar-menu-item");
        if destructive {
            btn.add_css_class("destructive");
        }
        list.append(&btn);
        btn
    };

    let copy = item("󰆏  Copiar", false);
    let open = item("󰈈  Abrir", false);
    let save = item("󰆓  Guardar en Imágenes", false);
    let delete = item("󰆴  Eliminar", true);

    let p = path.to_path_buf();
    copy.connect_clicked(glib::clone!(
        #[weak] pop,
        #[weak] badge,
        #[strong] p,
        move |_| {
            pop.popdown();
            let ok = clipboard::copy_png(&p).is_ok();
            flash(&badge, if ok { "Copiada" } else { "No se pudo copiar" });
        }
    ));
    open.connect_clicked(glib::clone!(
        #[weak] pop,
        #[strong] ui,
        #[strong] p,
        move |_| {
            pop.popdown();
            let uri = gio::File::for_path(&p).uri();
            let _ = gio::AppInfo::launch_default_for_uri(&uri, gio::AppLaunchContext::NONE);
            ui.main_loop.quit();
        }
    ));
    save.connect_clicked(glib::clone!(
        #[weak] pop,
        #[weak] badge,
        #[strong] p,
        move |_| {
            pop.popdown();
            match save_permanently(&p) {
                Ok(dest) => {
                    flash(&badge, "Guardada");
                    bar::toast("Captura guardada", &dest.display().to_string());
                }
                Err(e) => {
                    flash(&badge, "Error al guardar");
                    bar::toast("No se pudo guardar", &e.to_string());
                }
            }
        }
    ));
    delete.connect_clicked(glib::clone!(
        #[weak] pop,
        #[strong] ui,
        #[strong] p,
        move |_| {
            pop.popdown();
            history::remove(&p);
            bar::notify("refresh");
            rebuild(&ui);
        }
    ));

    pop.set_child(Some(&list));
    pop.popup();
}

/// Copia la captura a `<Imágenes>/Screenshots/` (XDG; `SHOTBAR_SAVE_DIR`
/// lo cambia) sin sobrescribir nada.
fn save_permanently(src: &Path) -> std::io::Result<PathBuf> {
    let dir = std::env::var_os("SHOTBAR_SAVE_DIR")
        .map(PathBuf::from)
        .or_else(|| glib::user_special_dir(glib::UserDirectory::Pictures).map(|p| p.join("Screenshots")))
        .unwrap_or_else(|| theme::home().join("Pictures/Screenshots"));
    std::fs::create_dir_all(&dir)?;
    let stem = src.file_stem().unwrap_or_default().to_string_lossy().into_owned();
    let mut dest = dir.join(format!("{stem}.png"));
    let mut n = 2;
    while dest.exists() {
        dest = dir.join(format!("{stem}-{n}.png"));
        n += 1;
    }
    std::fs::copy(src, &dest)?;
    Ok(dest)
}

fn ui_preview_host(ui: &Rc<Ui>) -> crate::preview::Host {
    crate::preview::Host {
        monitor: ui.monitor.clone(),
        slot: Rc::new(glib::clone!(
            #[strong] ui,
            move |w: Option<gtk::Window>| {
                if let Some(old) = ui.preview.replace(w) {
                    old.destroy();
                }
                // Al cerrar la vista previa el teclado vuelve al panel.
                if ui.preview.borrow().is_none() {
                    ui.panel.present();
                }
            }
        )),
    }
}
