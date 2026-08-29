import Quickshell
import QtQuick

// Top bar, one instance per screen (created by Variants in shell.qml).
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)

        // Left: clock, system monitor, focused window.
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            ClockWidget {}
            SysMonWidget {}
            ActiveWindowWidget {}
        }

        // Center: workspaces for this bar's output.
        WorkspacesWidget {
            anchors.centerIn: parent
            output: bar.modelData.name
        }

        // Right: tray, battery, volume.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            TrayWidget {}
            BatteryWidget {}
            VolumeWidget {}
        }
    }
}
