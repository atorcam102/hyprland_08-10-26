import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.CustomTheme

// Capturas temporales (shotbar). Muestra el icono y, si hay capturas, cuántas.
// Al hacer clic abre el panel del historial colgando bajo el módulo, como el
// calendario. `shotbar` avisa por IPC (target "shotbar") tras cada captura:
// el contador se actualiza al instante y el icono destella ~500 ms.
Rectangle {
    id: shots

    property int count: 0
    // Set by the keyboard navigation in StatusbarWindow.
    property bool focused: false
    // Destello tras una captura.
    property bool flashing: false

    readonly property bool active: mouseArea.containsMouse || shots.focused

    function activate(): void {
        // Centro del módulo y borde superior de la tarjeta, en coordenadas de
        // la ventana de la barra (anclada arriba a todo lo ancho = las del
        // monitor). El hueco replica el del calendario bajo la píldora.
        let p = shots.mapToItem(null, shots.width / 2, shots.height)
        let win = QsWindow.window
        let output = (win && win.screen) ? win.screen.name : ""
        Quickshell.execDetached(["shotbar", "panel",
            "--output", output,
            "--x", String(Math.round(p.x)),
            "--y", String(Math.round(p.y + 29))])
    }

    function refresh(): void {
        countProc.running = false
        countProc.running = true
    }

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 30
    radius: Theme.radiusControl

    // Mismo relleno que BarButton: tinte en hover, principal al seleccionar o
    // durante el destello.
    color: (shots.focused || shots.flashing) ? Theme.primary
        : (mouseArea.containsMouse ? Theme.hoverFill : "transparent")
    Behavior on color {
        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Image {
            id: icon
            Layout.alignment: Qt.AlignVCenter
            source: "../shared/icons/screenshot.svg"
            sourceSize.width: 17
            sourceSize.height: 17
            width: 17
            height: 17
            fillMode: Image.PreserveAspectFit
            scale: mouseArea.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: (shots.focused || shots.flashing) ? Theme.on_primary : Theme.primary
                Behavior on colorizationColor {
                    ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: shots.count > 0
            text: shots.count
            color: (shots.focused || shots.flashing) ? Theme.on_primary : Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
            Behavior on color {
                ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }

    // Pequeño "pop" del icono al capturar.
    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: row; property: "scale"; to: 1.18; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: row; property: "scale"; to: 1.0; duration: 260; easing.type: Easing.OutBack }
    }

    Timer {
        id: flashTimer
        interval: 500
        onTriggered: shots.flashing = false
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: shots.activate()
    }

    Process {
        id: countProc
        command: ["shotbar", "count"]
        stdout: StdioCollector {
            onStreamFinished: {
                let n = parseInt(this.text.trim())
                shots.count = isNaN(n) ? 0 : n
            }
        }
    }

    IpcHandler {
        target: "shotbar"
        function refresh(): void { shots.refresh() }
        function captured(): void {
            shots.refresh()
            shots.flashing = true
            flashTimer.restart()
            popAnim.restart()
        }
    }

    // Al (re)arrancar la barra se lee el estado actual del historial.
    Component.onCompleted: refresh()
}
