//! Historial temporal de capturas.
//!
//! El historial *es* el directorio `$XDG_RUNTIME_DIR/shotbar/`: no hay índice
//! aparte que pueda desincronizarse. Ese directorio vive en un tmpfs ligado a
//! la sesión, así que se vacía solo al cerrar sesión o reiniciar.

use std::fs::{self, File};
use std::io;
use std::os::unix::fs::{DirBuilderExt, PermissionsExt};
use std::os::unix::io::AsRawFd;
use std::path::{Path, PathBuf};
use std::time::SystemTime;

/// Número máximo de capturas que se conservan.
pub const MAX_ENTRIES: usize = 5;
/// Lado mayor de las miniaturas (2x el tamaño mostrado, para HiDPI).
pub const THUMB_SIZE: i32 = 640;

const PREFIX: &str = "screenshot-";

#[derive(Clone, Debug)]
pub struct Entry {
    pub path: PathBuf,
    pub modified: SystemTime,
}

impl Entry {
    pub fn name(&self) -> String {
        self.path.file_name().unwrap_or_default().to_string_lossy().into_owned()
    }

    pub fn thumb_path(&self) -> PathBuf {
        thumbs_dir().join(self.name())
    }
}

/// `$XDG_RUNTIME_DIR/shotbar`, con `/tmp/shotbar-$UID` como último recurso.
pub fn dir() -> PathBuf {
    match std::env::var_os("XDG_RUNTIME_DIR") {
        Some(d) if !d.is_empty() => PathBuf::from(d).join("shotbar"),
        _ => PathBuf::from(format!("/tmp/shotbar-{}", unsafe { libc::getuid() })),
    }
}

pub fn thumbs_dir() -> PathBuf {
    dir().join(".thumbs")
}

/// Crea los directorios (modo 0700) si no existen.
pub fn ensure_dirs() -> io::Result<()> {
    let mut b = fs::DirBuilder::new();
    b.recursive(true).mode(0o700);
    b.create(thumbs_dir())?;
    // Por si el directorio ya existía con otros permisos.
    let _ = fs::set_permissions(dir(), fs::Permissions::from_mode(0o700));
    Ok(())
}

/// Bloqueo exclusivo (flock) sobre un fichero del directorio. Se libera al
/// soltar el valor devuelto.
pub struct Lock(#[allow(dead_code)] File);

pub fn lock(name: &str, blocking: bool) -> io::Result<Option<Lock>> {
    ensure_dirs()?;
    let f = File::options().create(true).write(true).truncate(false).open(dir().join(name))?;
    let op = if blocking { libc::LOCK_EX } else { libc::LOCK_EX | libc::LOCK_NB };
    if unsafe { libc::flock(f.as_raw_fd(), op) } == 0 {
        Ok(Some(Lock(f)))
    } else {
        let err = io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::EWOULDBLOCK) {
            Ok(None)
        } else {
            Err(err)
        }
    }
}

/// Capturas actuales, de la más reciente a la más antigua.
pub fn list() -> Vec<Entry> {
    let Ok(rd) = fs::read_dir(dir()) else { return Vec::new() };
    let mut v: Vec<Entry> = rd
        .flatten()
        .filter_map(|e| {
            let name = e.file_name();
            let name = name.to_str()?;
            if !name.starts_with(PREFIX) || !name.ends_with(".png") {
                return None;
            }
            let md = e.metadata().ok()?;
            if !md.is_file() || md.len() == 0 {
                return None;
            }
            Some(Entry { path: e.path(), modified: md.modified().ok()? })
        })
        .collect();
    v.sort_by(|a, b| b.modified.cmp(&a.modified).then_with(|| b.path.cmp(&a.path)));
    v
}

pub fn count() -> usize {
    list().len()
}

/// Ruta libre para una captura nueva: `screenshot-AAAA-MM-DD-HH-MM-SS.png`,
/// con sufijo `-2`, `-3`… si se hacen varias en el mismo segundo.
pub fn new_path() -> io::Result<PathBuf> {
    ensure_dirs()?;
    let base = format!("{PREFIX}{}", timestamp("%Y-%m-%d-%H-%M-%S"));
    let d = dir();
    let mut p = d.join(format!("{base}.png"));
    let mut n = 2;
    while p.exists() {
        p = d.join(format!("{base}-{n}.png"));
        n += 1;
    }
    Ok(p)
}

/// Borra las capturas que exceden MAX_ENTRIES (y sus miniaturas), junto con
/// miniaturas huérfanas y temporales a medio escribir.
pub fn prune() {
    for e in list().into_iter().skip(MAX_ENTRIES) {
        remove(&e.path);
    }
    let keep: Vec<String> = list().iter().map(Entry::name).collect();
    if let Ok(rd) = fs::read_dir(thumbs_dir()) {
        for e in rd.flatten() {
            let n = e.file_name().to_string_lossy().into_owned();
            if !keep.contains(&n) {
                let _ = fs::remove_file(e.path());
            }
        }
    }
}

/// Borra una captura y su miniatura.
pub fn remove(path: &Path) {
    let _ = fs::remove_file(path);
    if let Some(n) = path.file_name() {
        let _ = fs::remove_file(thumbs_dir().join(n));
    }
}

pub fn clear() {
    for e in list() {
        remove(&e.path);
    }
    prune();
}

/// Genera (o reutiliza) la miniatura de una captura. Devuelve su ruta.
/// Usa gdk-pixbuf, que no necesita inicializar GTK.
pub fn ensure_thumb(e: &Entry) -> Option<PathBuf> {
    use gtk::gdk_pixbuf::Pixbuf;
    let t = e.thumb_path();
    if t.exists() {
        return Some(t);
    }
    let pb = Pixbuf::from_file_at_scale(&e.path, THUMB_SIZE, THUMB_SIZE, true).ok()?;
    let _ = ensure_dirs();
    // Escritura atómica: el panel nunca ve una miniatura a medias.
    let tmp = t.with_extension("tmp");
    pb.savev(&tmp, "png", &[("compression", "1")]).ok()?;
    fs::rename(&tmp, &t).ok()?;
    Some(t)
}

/// Fecha local formateada con strftime.
pub fn timestamp(fmt: &str) -> String {
    format_time(SystemTime::now(), fmt)
}

pub fn format_time(t: SystemTime, fmt: &str) -> String {
    let secs = t
        .duration_since(SystemTime::UNIX_EPOCH)
        .map(|d| d.as_secs() as libc::time_t)
        .unwrap_or(0);
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    let mut buf = [0u8; 64];
    let cfmt = std::ffi::CString::new(fmt).unwrap_or_default();
    let n = unsafe {
        libc::localtime_r(&secs, &mut tm);
        libc::strftime(buf.as_mut_ptr().cast(), buf.len(), cfmt.as_ptr(), &tm)
    };
    String::from_utf8_lossy(&buf[..n]).into_owned()
}
