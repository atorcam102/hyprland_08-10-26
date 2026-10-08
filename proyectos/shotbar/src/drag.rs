//! Arrastrar-y-soltar real de Wayland (wl_data_device) con GtkDragSource.
//!
//! El contenido se ofrece igual que lo haría Nautilus:
//!   1. un GdkFileList → GTK lo serializa como `text/uri-list`
//!      (file:///run/user/1000/shotbar/…png), `application/vnd.portal.files`
//!      / `application/vnd.portal.filetransfer` (apps Flatpak, vía el portal
//!      Documents) y `text/plain` con la ruta;
//!   2. los bytes PNG como `image/png`, para destinos que solo aceptan imagen.
//! El orden del union es el orden de preferencia: Discord, Telegram, los
//! navegadores y los gestores de archivos ven un fichero adjunto normal.

use std::cell::Cell;
use std::path::PathBuf;
use std::rc::Rc;

use gtk::prelude::*;
use gtk::{gdk, gio, glib};

pub struct Hooks {
    /// Al empezar el arrastre (el panel aparta su fondo para no tapar destinos).
    pub on_begin: Box<dyn Fn()>,
    /// Al terminar; `true` si el destino aceptó la captura.
    pub on_end: Box<dyn Fn(bool)>,
}

pub fn attach(widget: &impl IsA<gtk::Widget>, path: PathBuf, icon: &gtk::Picture, hooks: Rc<Hooks>) {
    let widget = widget.as_ref().clone();
    let source = gtk::DragSource::new();
    source.set_actions(gdk::DragAction::COPY);

    // Se construye en `prepare`, justo al empezar: si el archivo ya no existe
    // (borrado por fuera) el arrastre simplemente no arranca.
    let p = path.clone();
    source.connect_prepare(move |_, _, _| {
        if !p.is_file() {
            return None;
        }
        let file = gio::File::for_path(&p);
        let files = gdk::FileList::from_array(&[file]);
        let mut providers = vec![gdk::ContentProvider::for_value(&files.to_value())];
        if let Ok(bytes) = std::fs::read(&p) {
            providers.push(gdk::ContentProvider::for_bytes("image/png", &glib::Bytes::from_owned(bytes)));
        }
        Some(gdk::ContentProvider::new_union(&providers))
    });

    // Icono del arrastre: la propia miniatura, a tamaño de tarjeta, agarrada
    // por el punto donde se pulsó.
    let start = Rc::new(Cell::new((0.0f64, 0.0f64)));
    {
        let start = start.clone();
        source.connect_drag_begin(glib::clone!(
            #[weak] icon,
            #[weak] widget,
            #[strong] hooks,
            move |src, _drag| {
                if let Some(paintable) = icon.paintable() {
                    let (w, h) = icon_size(&paintable, 220.0);
                    let snap = gtk::Snapshot::new();
                    paintable.snapshot(&snap, w, h);
                    if let Some(node) = snap.to_node() {
                        let tex = widget
                            .native()
                            .and_then(|n| n.renderer())
                            .map(|r| r.render_texture(&node, None));
                        let (x, y) = start.get();
                        let hx = (x.clamp(0.0, w) as i32).min(w as i32 - 1).max(0);
                        let hy = (y.clamp(0.0, h) as i32).min(h as i32 - 1).max(0);
                        match tex {
                            Some(t) => src.set_icon(Some(&t), hx, hy),
                            None => src.set_icon(Some(&paintable), hx, hy),
                        }
                    }
                }
                widget.add_css_class("dragging");
                (hooks.on_begin)();
            }
        ));
    }

    let ok = Rc::new(Cell::new(false));
    {
        let ok = ok.clone();
        source.connect_drag_cancel(move |_, _, _| {
            ok.set(false);
            false
        });
    }
    {
        let ok = ok.clone();
        source.connect_drag_begin(move |_, _| ok.set(true));
    }
    source.connect_drag_end(glib::clone!(
        #[weak] widget,
        #[strong] hooks,
        move |_, _, _| {
            widget.remove_css_class("dragging");
            (hooks.on_end)(ok.get());
        }
    ));

    // Punto de agarre relativo a la miniatura.
    let press = gtk::GestureClick::new();
    press.set_propagation_phase(gtk::PropagationPhase::Capture);
    press.connect_pressed(glib::clone!(
        #[weak] icon,
        #[weak] widget,
        move |_, _, x, y| {
            let p = widget
                .compute_point(&icon, &gtk::graphene::Point::new(x as f32, y as f32))
                .map(|p| (p.x() as f64, p.y() as f64))
                .unwrap_or((x, y));
            // Escala del punto a la medida del icono del arrastre.
            if let Some(paintable) = icon.paintable() {
                let (w, h) = icon_size(&paintable, 220.0);
                let sx = w / icon.width().max(1) as f64;
                let sy = h / icon.height().max(1) as f64;
                start.set((p.0 * sx, p.1 * sy));
            }
        }
    ));
    widget.add_controller(press);
    widget.add_controller(source);
}

/// Tamaño del icono conservando la proporción, con el lado mayor = `max`.
fn icon_size(p: &gdk::Paintable, max: f64) -> (f64, f64) {
    let ratio = p.intrinsic_aspect_ratio();
    let ratio = if ratio > 0.0 { ratio } else { 16.0 / 9.0 };
    if ratio >= 1.0 {
        (max, (max / ratio).round().max(1.0))
    } else {
        ((max * ratio).round().max(1.0), max)
    }
}
