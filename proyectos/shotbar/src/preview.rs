//! Vista previa grande (estilo Quick Look): Espacio sobre una miniatura.
//!
//! Superficie layer-shell a pantalla completa con un velo translúcido y la
//! captura centrada. Rueda / trackpad / pellizco: zoom hacia el puntero.
//! Arrastrar: desplazar. Espacio, Esc o clic fuera: cerrar.

use std::cell::{Cell, RefCell};
use std::path::Path;
use std::rc::Rc;

use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gdk, glib, graphene, gsk};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

use crate::history;

pub struct Host {
    pub monitor: Option<gdk::Monitor>,
    /// Registra la ventana abierta (Some) o avisa de que se cerró (None).
    pub slot: Rc<dyn Fn(Option<gtk::Window>)>,
}

const MIN_ZOOM: f64 = 0.25; // relativo al tamaño real de la captura
const MAX_ZOOM: f64 = 8.0;

/// `shotbar preview`: la vista grande sin el panel.
pub fn standalone(path: &Path) -> std::process::ExitCode {
    if gtk::init().is_err() {
        return std::process::ExitCode::FAILURE;
    }
    crate::panel::install_css();
    let ml = glib::MainLoop::new(None, false);
    let current: Rc<RefCell<Option<gtk::Window>>> = Rc::default();
    let host = Host {
        monitor: crate::panel::find_monitor(&gdk::Display::default().unwrap(), None),
        slot: Rc::new(glib::clone!(
            #[strong] ml,
            #[strong] current,
            move |w: Option<gtk::Window>| match w {
                Some(w) => *current.borrow_mut() = Some(w),
                None => {
                    if let Some(w) = current.borrow_mut().take() {
                        w.destroy();
                    }
                    ml.quit();
                }
            }
        )),
    };
    open(&host, path);
    if current.borrow().is_none() {
        return std::process::ExitCode::FAILURE;
    }
    ml.run();
    std::process::ExitCode::SUCCESS
}

pub fn open(host: &Host, path: &Path) {
    let Ok(tex) = gdk::Texture::from_filename(path) else { return };

    let (mw, mh, scale) = host
        .monitor
        .as_ref()
        .map(|m| (m.geometry().width() as f64, m.geometry().height() as f64, m.scale().max(1.0)))
        .unwrap_or((1920.0, 1080.0, 1.0));
    // Tamaño "real" en px lógicos (en HiDPI, 100 % = píxel nativo).
    let (bw, bh) = (tex.width() as f64 / scale, tex.height() as f64 / scale);
    let fit = (0.86 * mw / bw).min(0.78 * mh / bh).min(1.0);
    let (vw, vh) = ((bw * fit).round().max(1.0), (bh * fit).round().max(1.0));

    let win = gtk::Window::new();
    win.add_css_class("shotbar-preview");
    win.init_layer_shell();
    win.set_namespace(Some("shotbar-preview"));
    win.set_layer(Layer::Overlay);
    for e in [Edge::Top, Edge::Bottom, Edge::Left, Edge::Right] {
        win.set_anchor(e, true);
    }
    win.set_exclusive_zone(-1);
    win.set_keyboard_mode(KeyboardMode::Exclusive);
    if let Some(m) = &host.monitor {
        win.set_monitor(Some(m));
    }

    let scrim = gtk::Box::new(gtk::Orientation::Vertical, 0);
    scrim.add_css_class("shotbar-scrim");
    let card = gtk::Box::new(gtk::Orientation::Vertical, 8);
    card.add_css_class("shotbar-preview-card");
    card.set_halign(gtk::Align::Center);
    card.set_valign(gtk::Align::Center);
    card.set_hexpand(true);
    card.set_vexpand(true);
    scrim.append(&card);
    win.set_child(Some(&scrim));

    let paintable = Scaled::new(&tex, bw * fit, bh * fit);
    let pic = gtk::Picture::for_paintable(&paintable);
    pic.set_content_fit(gtk::ContentFit::Fill);
    pic.set_can_shrink(false);
    pic.set_halign(gtk::Align::Center);
    pic.set_valign(gtk::Align::Center);

    let sw = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::External)
        .vscrollbar_policy(gtk::PolicyType::External)
        .min_content_width(vw as i32)
        .max_content_width(vw as i32)
        .min_content_height(vh as i32)
        .max_content_height(vh as i32)
        .propagate_natural_width(false)
        .propagate_natural_height(false)
        .child(&pic)
        .build();
    sw.add_css_class("shotbar-preview-view");
    sw.set_focusable(false);
    sw.set_overflow(gtk::Overflow::Hidden);
    card.append(&sw);

    let caption = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let when = std::fs::metadata(path)
        .and_then(|m| m.modified())
        .map(|t| history::format_time(t, "%H:%M:%S"))
        .unwrap_or_default();
    let info = gtk::Label::new(Some(&format!("{when}  ·  {}×{}", tex.width(), tex.height())));
    info.add_css_class("shotbar-time");
    info.set_hexpand(true);
    info.set_xalign(0.0);
    let zoom_label = gtk::Label::new(None);
    zoom_label.add_css_class("shotbar-time");
    let hint = gtk::Label::new(Some("Rueda: zoom · Arrastrar: mover · Espacio: cerrar"));
    hint.add_css_class("shotbar-time");
    caption.append(&info);
    caption.append(&zoom_label);
    caption.append(&hint);
    caption.set_margin_start(4);
    caption.set_margin_end(4);
    card.append(&caption);

    // ---------------------------------------------------------------- zoom
    let zoom = Rc::new(Cell::new(fit));
    let pointer = Rc::new(Cell::new((vw / 2.0, vh / 2.0)));
    // Punto (en coords. de contenido) que debe quedar bajo el puntero tras el
    // reajuste; se aplica cuando las adjustments conocen el nuevo tamaño.
    let pending: Rc<RefCell<Option<(f64, f64, f64, f64)>>> = Rc::default();

    let set_label = {
        let zoom_label = zoom_label.clone();
        move |z: f64| zoom_label.set_label(&format!("{:.0} %", z * 100.0))
    };
    set_label(fit);

    let apply = {
        let paintable = paintable.clone();
        let sw = sw.clone();
        let zoom = zoom.clone();
        let pointer = pointer.clone();
        let pending = pending.clone();
        let set_label = set_label.clone();
        Rc::new(move |new_z: f64| {
            let new_z = new_z.clamp(MIN_ZOOM.min(fit), MAX_ZOOM);
            let old_z = zoom.get();
            if (new_z - old_z).abs() < 1e-6 {
                return;
            }
            let (px, py) = pointer.get();
            let r = new_z / old_z;
            let cx = (sw.hadjustment().value() + px) * r;
            let cy = (sw.vadjustment().value() + py) * r;
            *pending.borrow_mut() = Some((cx - px, cy - py, cx, cy));
            zoom.set(new_z);
            paintable.set_size(bw * new_z, bh * new_z);
            set_label(new_z);
        })
    };
    for adj in [sw.hadjustment(), sw.vadjustment()] {
        let pending = pending.clone();
        let sw2 = sw.clone();
        adj.connect_changed(move |_| {
            if let Some((x, y, _, _)) = *pending.borrow() {
                sw2.hadjustment().set_value(x);
                sw2.vadjustment().set_value(y);
            }
        });
    }
    // El valor pendiente solo vale para el reajuste inmediato.
    sw.add_tick_callback({
        let pending = pending.clone();
        move |_, _| {
            pending.borrow_mut().take();
            glib::ControlFlow::Continue
        }
    });

    let motion = gtk::EventControllerMotion::new();
    motion.connect_motion(glib::clone!(
        #[strong] pointer,
        move |_, x, y| pointer.set((x, y))
    ));
    sw.add_controller(motion);

    let scroll = gtk::EventControllerScroll::new(gtk::EventControllerScrollFlags::VERTICAL);
    scroll.set_propagation_phase(gtk::PropagationPhase::Capture);
    scroll.connect_scroll(glib::clone!(
        #[strong] apply,
        #[strong] zoom,
        move |c, _, dy| {
            // Rueda: pasos de ±1; trackpad: deltas finos y continuos.
            let step = if c.unit() == gdk::ScrollUnit::Wheel { dy } else { dy / 10.0 };
            apply(zoom.get() * 1.15f64.powf(-step));
            glib::Propagation::Stop
        }
    ));
    sw.add_controller(scroll);

    let pinch = gtk::GestureZoom::new();
    let pinch_base = Rc::new(Cell::new(fit));
    pinch.connect_begin(glib::clone!(
        #[strong] zoom,
        #[strong] pinch_base,
        move |_, _| pinch_base.set(zoom.get())
    ));
    pinch.connect_scale_changed(glib::clone!(
        #[strong] apply,
        #[strong] pinch_base,
        move |_, s| apply(pinch_base.get() * s)
    ));
    sw.add_controller(pinch);

    // Arrastrar para desplazar cuando está ampliada.
    let pan = gtk::GestureDrag::new();
    let pan_start = Rc::new(Cell::new((0.0, 0.0)));
    pan.connect_drag_begin(glib::clone!(
        #[weak] sw,
        #[strong] pan_start,
        move |_, _, _| {
            pan_start.set((sw.hadjustment().value(), sw.vadjustment().value()));
            sw.set_cursor_from_name(Some("grabbing"));
        }
    ));
    pan.connect_drag_update(glib::clone!(
        #[weak] sw,
        #[strong] pan_start,
        move |_, dx, dy| {
            let (x, y) = pan_start.get();
            sw.hadjustment().set_value(x - dx);
            sw.vadjustment().set_value(y - dy);
        }
    ));
    pan.connect_drag_end(glib::clone!(
        #[weak] sw,
        move |_, _, _| sw.set_cursor_from_name(Some("grab"))
    ));
    sw.add_controller(pan);
    sw.set_cursor_from_name(Some("grab"));

    // ------------------------------------------------------------- cierre
    let slot = host.slot.clone();
    let close = Rc::new(move || slot(None));

    let keys = gtk::EventControllerKey::new();
    keys.set_propagation_phase(gtk::PropagationPhase::Capture);
    keys.connect_key_pressed(glib::clone!(
        #[strong] close,
        #[strong] apply,
        #[strong] zoom,
        move |_, key, _, _| match key {
            gdk::Key::Escape | gdk::Key::space => {
                close();
                glib::Propagation::Stop
            }
            gdk::Key::plus | gdk::Key::KP_Add | gdk::Key::equal => {
                apply(zoom.get() * 1.25);
                glib::Propagation::Stop
            }
            gdk::Key::minus | gdk::Key::KP_Subtract => {
                apply(zoom.get() / 1.25);
                glib::Propagation::Stop
            }
            gdk::Key::_0 | gdk::Key::KP_0 => {
                apply(fit);
                glib::Propagation::Stop
            }
            _ => glib::Propagation::Proceed,
        }
    ));
    win.add_controller(keys);

    let click = gtk::GestureClick::new();
    click.set_button(0);
    click.connect_pressed(glib::clone!(
        #[strong] close,
        #[weak] scrim,
        move |g, _, x, y| {
            if scrim.pick(x, y, gtk::PickFlags::DEFAULT).as_ref() == Some(scrim.upcast_ref()) {
                g.set_state(gtk::EventSequenceState::Claimed);
                close();
            }
        }
    ));
    scrim.add_controller(click);

    (host.slot)(Some(win.clone()));
    win.present();
}

// ------------------------------------------------- paintable de tamaño fijo

// GtkPicture usa el tamaño intrínseco del paintable como tamaño natural; este
// envoltorio lo fija al del zoom actual, así el visor puede centrarla cuando
// es más pequeña que la vista y desplazarla cuando es más grande.
mod imp {
    use super::*;

    #[derive(Default)]
    pub struct Scaled {
        pub tex: RefCell<Option<gdk::Texture>>,
        pub w: Cell<f64>,
        pub h: Cell<f64>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for Scaled {
        const NAME: &'static str = "ShotbarScaledPaintable";
        type Type = super::Scaled;
        type Interfaces = (gdk::Paintable,);
    }

    impl ObjectImpl for Scaled {}

    impl PaintableImpl for Scaled {
        fn intrinsic_width(&self) -> i32 {
            self.w.get().round() as i32
        }
        fn intrinsic_height(&self) -> i32 {
            self.h.get().round() as i32
        }
        fn snapshot(&self, snapshot: &gdk::Snapshot, width: f64, height: f64) {
            let Some(tex) = self.tex.borrow().clone() else { return };
            let Some(snap) = snapshot.downcast_ref::<gtk::Snapshot>() else { return };
            // Ampliada mucho: píxeles nítidos; si no, suavizado.
            let filter = if width > tex.width() as f64 * 2.0 {
                gsk::ScalingFilter::Nearest
            } else {
                gsk::ScalingFilter::Trilinear
            };
            snap.append_scaled_texture(
                &tex,
                filter,
                &graphene::Rect::new(0.0, 0.0, width as f32, height as f32),
            );
        }
    }
}

glib::wrapper! {
    pub struct Scaled(ObjectSubclass<imp::Scaled>) @implements gdk::Paintable;
}

impl Scaled {
    fn new(tex: &gdk::Texture, w: f64, h: f64) -> Self {
        let o: Self = glib::Object::new();
        o.imp().tex.replace(Some(tex.clone()));
        o.set_size(w, h);
        o
    }

    fn set_size(&self, w: f64, h: f64) {
        self.imp().w.set(w);
        self.imp().h.set(h);
        self.invalidate_size();
    }
}
