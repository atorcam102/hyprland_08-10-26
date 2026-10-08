//! Colores de matugen (los mismos que lee la barra en CustomTheme/Theme.qml)
//! y tokens de forma del rediseño "Horizonte".

use std::collections::HashMap;

pub type Palette = HashMap<String, String>;

/// Paleta por defecto, idéntica a la de Theme.qml (se usa si colors.json falta).
const DEFAULTS: &[(&str, &str)] = &[
    ("primary", "#81d5cd"),
    ("on_primary", "#003734"),
    ("surface", "#0e1514"),
    ("surface_container", "#1a2120"),
    ("surface_container_lowest", "#090f0f"),
    ("surface_container_high", "#252b2a"),
    ("surface_container_highest", "#303635"),
    ("on_surface", "#dde4e2"),
    ("on_surface_variant", "#bec9c6"),
    ("outline_variant", "#3f4947"),
    ("error", "#ffb4ab"),
    ("shadow", "#000000"),
];

pub fn palette() -> Palette {
    let mut p: Palette = DEFAULTS.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect();
    let path = home().join(".config/ml4w/colors/colors.json");
    if let Ok(text) = std::fs::read_to_string(path) {
        if let Ok(serde_json::Value::Object(map)) = serde_json::from_str(&text) {
            for (k, v) in map {
                if let Some(s) = v.as_str().filter(|s| valid_hex(s)) {
                    p.insert(k, s.to_string());
                }
            }
        }
    }
    p
}

pub fn home() -> std::path::PathBuf {
    std::env::var_os("HOME").map(Into::into).unwrap_or_else(|| "/".into())
}

fn valid_hex(s: &str) -> bool {
    s.len() == 7 && s.starts_with('#') && s[1..].chars().all(|c| c.is_ascii_hexdigit())
}

/// `#rrggbb` + alfa (0–255) → `#rrggbbaa`, el formato que entiende slurp.
pub fn with_alpha(hex: &str, alpha: u8) -> String {
    format!("{hex}{alpha:02x}")
}

/// Hoja de estilo del panel. Reproduce los tokens de Theme.qml:
/// radiusPanel 20, radiusCard 14, radiusControl 10, hairline outline_variant,
/// panelFill surface_container @ 0.9, hoverFill primary @ 0.16.
pub fn css(p: &Palette) -> String {
    let mut defs = String::new();
    for (k, v) in p {
        defs.push_str(&format!("@define-color sb_{k} {v};\n"));
    }
    defs + CSS
}

const CSS: &str = r#"
window.shotbar, window.shotbar > .shotbar-root, .shotbar-shell {
  background: transparent;
  box-shadow: none;
}

.shotbar-shell { padding: 20px; }

.shotbar-card {
  font-family: "JetBrainsMono Nerd Font", monospace;
  background-color: alpha(@sb_surface_container, 0.9);
  border: 1px solid alpha(@sb_outline_variant, 0.95);
  border-radius: 20px;
  box-shadow: 0 10px 28px alpha(@sb_shadow, 0.45),
              inset 0 1px alpha(@sb_on_surface, 0.06);
  padding: 14px;
  color: @sb_on_surface;
}

.shotbar-title { font-weight: bold; font-size: 14px; color: @sb_on_surface; }
.shotbar-subtitle { font-size: 12px; color: @sb_on_surface_variant; }

.shotbar-text-button {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  font-weight: bold;
  color: @sb_primary;
  background: transparent;
  border: none;
  box-shadow: none;
  border-radius: 10px;
  padding: 4px 10px;
  min-height: 0;
  transition: background-color 220ms cubic-bezier(0.33, 1, 0.68, 1);
}
.shotbar-text-button:hover { background-color: alpha(@sb_primary, 0.16); }
.shotbar-text-button:active { background-color: alpha(@sb_primary, 0.26); }

.shotbar-shot {
  background-color: alpha(@sb_surface_container_highest, 0.7);
  border: 1px solid transparent;
  border-radius: 14px;
  padding: 6px;
  transition: background-color 220ms cubic-bezier(0.33, 1, 0.68, 1),
              border-color 220ms cubic-bezier(0.33, 1, 0.68, 1);
}
.shotbar-shot:hover {
  background-color: alpha(@sb_primary, 0.16);
  border-color: alpha(@sb_primary, 0.45);
}
.shotbar-shot.dragging { opacity: 0.45; }

.shotbar-thumb { border-radius: 10px; }

.shotbar-time { font-size: 11px; color: @sb_on_surface_variant; }

.shotbar-badge {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  font-weight: bold;
  color: @sb_on_primary;
  background-color: @sb_primary;
  border-radius: 10px;
  padding: 4px 10px;
}

.shotbar-empty-icon { font-size: 34px; color: alpha(@sb_primary, 0.8); }
.shotbar-empty { padding: 26px 0 18px 0; }

window.shotbar-preview { background: transparent; }
.shotbar-scrim { background-color: alpha(@sb_shadow, 0.45); }
.shotbar-preview-card {
  font-family: "JetBrainsMono Nerd Font", monospace;
  background-color: alpha(@sb_surface_container, 0.94);
  border: 1px solid alpha(@sb_outline_variant, 0.95);
  border-radius: 20px;
  box-shadow: 0 16px 48px alpha(@sb_shadow, 0.55);
  padding: 10px;
}
.shotbar-preview-view { border-radius: 14px; background-color: alpha(@sb_surface_container_lowest, 0.6); }

popover.shotbar-menu > contents {
  font-family: "JetBrainsMono Nerd Font", monospace;
  background-color: alpha(@sb_surface_container_high, 0.97);
  border: 1px solid alpha(@sb_outline_variant, 0.95);
  border-radius: 14px;
  box-shadow: 0 6px 18px alpha(@sb_shadow, 0.45);
  padding: 6px;
}
popover.shotbar-menu > arrow { background: none; border: none; }
.shotbar-menu-item {
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 12px;
  color: @sb_on_surface;
  background: transparent;
  border: none;
  box-shadow: none;
  border-radius: 10px;
  padding: 6px 10px;
  min-height: 0;
}
.shotbar-menu-item:hover { background-color: alpha(@sb_primary, 0.16); }
.shotbar-menu-item.destructive { color: @sb_error; }
.shotbar-menu-item.destructive:hover { background-color: alpha(@sb_error, 0.16); }
"#;
