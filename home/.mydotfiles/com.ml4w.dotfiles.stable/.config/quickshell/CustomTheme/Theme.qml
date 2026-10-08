pragma Singleton
import QtQuick
import Quickshell 
import Quickshell.Io 

QtObject { 
    id: root
    
    // Static properties
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // --- Rediseño "Horizonte": tokens de forma (los colores siguen siendo los de matugen) ---
    // Escala de radios: paneles > tarjetas > controles. La barra y los chips usan cápsula.
    readonly property int radiusPanel: 20
    readonly property int radiusCard: 14
    readonly property int radiusControl: 10
    // Línea fina que delimita cada superficie, en lugar del antiguo borde en degradado.
    readonly property int hairlineWidth: 1
    readonly property color hairline: Qt.rgba(outline_variant.r, outline_variant.g, outline_variant.b, 0.95)
    // Brillo interior de 1px en el borde superior: da volumen al cristal.
    readonly property color innerHighlight: Qt.rgba(on_surface.r, on_surface.g, on_surface.b, 0.06)
    // Relleno de los paneles: un escalón por encima del fondo, ligeramente translúcido
    // (Hyprland difumina lo que queda detrás; ver decorations/horizonte.lua).
    readonly property color panelFill: Qt.rgba(surface_container.r, surface_container.g, surface_container.b, 0.9)
    readonly property color chipFill: Qt.rgba(surface_container_highest.r, surface_container_highest.g, surface_container_highest.b, 0.7)
    // Estado hover / seleccionado: tinte suave del color principal.
    readonly property color hoverFill: Qt.rgba(primary.r, primary.g, primary.b, 0.16)
    readonly property color shadowColor: Qt.rgba(shadow.r, shadow.g, shadow.b, 0.45)
    readonly property int shadowBlur: 28
    
    // True while the loaded palette is a light one. Derived from the palette
    // itself rather than read from the GTK preference, so it updates atomically
    // with reloadTheme() and stays correct for any hand-written colors.json.
    readonly property bool isLight: background.hslLightness > 0.5

    // Dynamic color properties
    property color background: "#0e1514"
    property color error: "#ffb4ab"
    property color error_container: "#93000a"
    property color inverse_on_surface: "#2b3231"
    property color inverse_primary: "#006a64"
    property color inverse_surface: "#dde4e2"
    property color on_background: "#dde4e2"
    property color on_error: "#690005"
    property color on_error_container: "#ffdad6"
    property color on_primary: "#003734"
    property color on_primary_container: "#9df2e9"
    property color on_primary_fixed: "#00201e"
    property color on_primary_fixed_variant: "#00504b"
    property color on_secondary: "#1c3532"
    property color on_secondary_container: "#cce8e4"
    property color on_secondary_fixed: "#051f1d"
    property color on_secondary_fixed_variant: "#324b49"
    property color on_surface: "#dde4e2"
    property color on_surface_variant: "#bec9c6"
    property color on_tertiary: "#18324a"
    property color on_tertiary_container: "#cfe5ff"
    property color on_tertiary_fixed: "#001d33"
    property color on_tertiary_fixed_variant: "#304962"
    property color outline: "#899391"
    property color outline_variant: "#3f4947"
    property color primary: "#81d5cd"
    property color primary_container: "#00504b"
    property color primary_fixed: "#9df2e9"
    property color primary_fixed_dim: "#81d5cd"
    property color scrim: "#000000"
    property color secondary: "#b0ccc8"
    property color secondary_container: "#324b49"
    property color secondary_fixed: "#cce8e4"
    property color secondary_fixed_dim: "#b0ccc8"
    property color shadow: "#000000"
    property color source_color: "#458680"
    property color surface: "#0e1514"
    property color surface_bright: "#343a39"
    property color surface_container: "#1a2120"
    property color surface_container_high: "#252b2a"
    property color surface_container_highest: "#303635"
    property color surface_container_low: "#161d1c"
    property color surface_container_lowest: "#090f0f"
    property color surface_dim: "#0e1514"
    property color surface_tint: "#81d5cd"
    property color surface_variant: "#3f4947"
    property color tertiary: "#afc9e7"
    property color tertiary_container: "#304962"
    property color tertiary_fixed: "#cfe5ff"
    property color tertiary_fixed_dim: "#afc9e7"

    property var themeReader: Process {
        id: reader
        command: ["cat", Quickshell.env("HOME") + "/.config/ml4w/colors/colors.json"]
        
        // REQUIRED: Quickshell needs this to parse the binary stream into text
        stdout: StdioCollector {
            onStreamFinished: {
                // "this.text" contains the full output of the cat command
                var output = this.text.trim();
                
                if (output !== "") {
                    try {
                        var newColors = JSON.parse(output);
                        for (var key in newColors) {
                            if (root.hasOwnProperty(key) && key !== "objectName") {
                                root[key] = newColors[key];
                            }
                        }
                        console.log("Theme colors loaded successfully!");
                    } catch (e) {
                        console.log("Failed to parse theme JSON: " + e);
                    }
                }
            }
        }
    }

    function reloadTheme() {
        // Toggle false then true to guarantee Quickshell restarts the cat process
        reader.running = false;
        reader.running = true;
    }

    // Load the JSON colors automatically when Quickshell starts
    // Component.onCompleted: reloadTheme()
}