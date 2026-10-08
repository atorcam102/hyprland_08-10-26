import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.CustomTheme

// Hyprland workspace switcher.
RowLayout {
    id: wsRoot
    spacing: 2

    // Minimum number of workspaces to always display, even when empty. The list
    // still grows beyond this to reveal any higher-numbered workspace that
    // exists (e.g. switching to workspace 6 while this is 5 adds a 6th dot).
    property int minWorkspaces: 5

    // The individual workspace buttons, exposed so StatusbarWindow can splice
    // them into its keyboard-navigation list. Rebuilt whenever workspaces are
    // added or removed.
    property var navButtons: []

    function rebuildNavButtons(): void {
        let a = []
        for (let i = 0; i < rep.count; i++)
            a.push(rep.itemAt(i))
        wsRoot.navButtons = a
    }

    // The workspace ids to render: 1..N, where N is at least minWorkspaces and
    // extends to cover the highest-numbered workspace that currently exists.
    readonly property var workspaceIds: {
        let maxId = Math.max(1, wsRoot.minWorkspaces)
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++)
            if (list[i].id > maxId)
                maxId = list[i].id
        let ids = []
        for (let id = 1; id <= maxId; id++)
            ids.push(id)
        return ids
    }

    // The live Hyprland workspace for an id, or null when it is empty (Hyprland
    // only tracks workspaces that hold windows or are focused).
    function workspaceById(id: int): var {
        const list = Hyprland.workspaces.values
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i]
        return null
    }

    Repeater {
        id: rep
        model: wsRoot.workspaceIds

        onItemAdded: wsRoot.rebuildNavButtons()
        onItemRemoved: wsRoot.rebuildNavButtons()

        delegate: Rectangle {
            id: ws
            required property var modelData   // the workspace id (int)
            // Set by StatusbarWindow's keyboard navigation.
            property bool focused: false

            // Whether this workspace is the currently focused one.
            readonly property bool isActive: Hyprland.focusedWorkspace
                && Hyprland.focusedWorkspace.id === ws.modelData
            // Whether the workspace currently holds windows (exists in Hyprland).
            readonly property bool occupied: wsRoot.workspaceById(ws.modelData) !== null

            // Run this workspace's action (mouse click or keyboard Return).
            // Hyprland with Lua dispatchers ignores the plain "workspace N"
            // string, so branch on usingLua the same way the overview does.
            function activate(): void {
                if (Hyprland.usingLua)
                    Hyprland.dispatch("hl.dsp.focus({workspace = '" + ws.modelData + "'})")
                else
                    Hyprland.dispatch("workspace " + ws.modelData)
            }

            // Horizonte: indicadores tipo punto. El activo se estira en una
            // cápsula del color principal; los ocupados son puntos marcados y
            // los vacíos, puntos tenues. El área de clic sigue siendo cómoda.
            implicitWidth: ws.isActive ? 34 : 16
            implicitHeight: 26
            radius: height / 2
            color: "transparent"

            Behavior on implicitWidth {
                NumberAnimation { duration: 380; easing.type: Easing.OutExpo }
            }

            Rectangle {
                id: mark
                anchors.centerIn: parent
                height: ws.isActive || wsMouse.containsMouse ? 10 : 8
                width: ws.isActive ? parent.width - 6 : height
                radius: height / 2
                color: ws.isActive ? Theme.primary
                    : (wsMouse.containsMouse ? Theme.primary
                    : (ws.occupied ? Theme.on_surface_variant : Theme.outline_variant))
                opacity: (ws.isActive || ws.occupied || wsMouse.containsMouse) ? 1 : 0.9

                Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutExpo } }
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }

            // Anillo de selección con teclado
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: height / 2
                color: "transparent"
                border.color: Theme.primary
                border.width: 1.5
                opacity: ws.focused ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ws.activate()
            }
        }
    }
}
