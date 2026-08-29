import Quickshell
import Quickshell.Wayland
import QtQuick

// Session menu (Mod+P via IPC). Same actions and digit keybinds as the old
// noctalia sessionMenu (minus hibernate/UEFI, which saw no use).
PanelWindow {
    id: root

    property bool shown: false

    readonly property var actions: [
        { key: "1", label: "Lock",     cmd: ["swaylock", "-f"] },
        { key: "2", label: "Suspend",  cmd: ["systemctl", "suspend"] },
        { key: "3", label: "Reboot",   cmd: ["systemctl", "reboot"] },
        { key: "4", label: "Logout",   cmd: ["niri", "msg", "action", "quit", "--skip-confirmation"] },
        { key: "5", label: "Shutdown", cmd: ["systemctl", "poweroff"] }
    ]

    function toggle(): void {
        shown = !shown;
        if (shown)
            keyCatcher.forceActiveFocus();
    }

    function run(cmd: var): void {
        shown = false;
        Quickshell.execDetached(cmd);
    }

    visible: shown
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
    }

    Item {
        id: keyCatcher

        anchors.fill: parent
        focus: root.shown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.shown = false;
                event.accepted = true;
                return;
            }
            const a = root.actions.find(a => a.key === event.text);
            if (a) {
                root.run(a.cmd);
                event.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: row.width + 48
        height: 140
        radius: Theme.radius
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)
        border.color: Theme.bgAlt
        border.width: 1

        MouseArea {
            anchors.fill: parent
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: 16

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData

                    width: 88
                    height: 88
                    radius: Theme.radius
                    color: hover.hovered ? Theme.bgAlt : "transparent"
                    border.color: modelData.label === "Shutdown" ? Theme.urgent : Theme.bgAlt
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.label
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.key
                            color: Theme.fgDim
                            font.family: Theme.fontFixed
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    HoverHandler {
                        id: hover
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.run(parent.modelData.cmd)
                    }
                }
            }
        }
    }
}
