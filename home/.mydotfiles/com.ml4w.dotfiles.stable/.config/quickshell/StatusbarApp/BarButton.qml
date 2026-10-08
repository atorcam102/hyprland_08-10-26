import QtQuick
import QtQuick.Effects
import qs.CustomTheme

// Reusable round icon button used across the status bar modules.
Rectangle {
    id: btn
    property string iconSrc: ""
    property bool colorize: true
    // Set by the keyboard navigation in StatusbarWindow to highlight the
    // currently selected module.
    property bool focused: false
    signal clicked()

    // Run the button's action (mouse click or keyboard Return).
    function activate(): void { btn.clicked() }

    // Highlighted when hovered with the mouse or selected via the keyboard.
    readonly property bool active: mouseArea.containsMouse || btn.focused

    implicitWidth: 30
    implicitHeight: 30
    radius: Theme.radiusControl

    // Horizonte: el hover tiñe suavemente el control; la selección con teclado
    // lo rellena con el color principal. (colorize solo decide si se recolorea
    // el icono, para que el logo de ML4W conserve sus colores.)
    color: btn.focused ? Theme.primary
        : (mouseArea.containsMouse ? Theme.hoverFill : "transparent")

    Behavior on color {
        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Image {
        anchors.centerIn: parent
        source: btn.iconSrc
        width: 17
        height: 17
        sourceSize.width: 17
        sourceSize.height: 17
        fillMode: Image.PreserveAspectFit
        scale: mouseArea.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        layer.enabled: btn.colorize
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: btn.focused ? Theme.on_primary : Theme.primary

            Behavior on colorizationColor {
                ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
