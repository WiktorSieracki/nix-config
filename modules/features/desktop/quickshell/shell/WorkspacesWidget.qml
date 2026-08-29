import QtQuick

// Workspace pills for one output; click to focus.
Row {
    id: root

    required property string output

    spacing: 6

    Repeater {
        model: Niri.workspaces.filter(w => w.output === root.output)

        Rectangle {
            required property var modelData

            width: 22
            height: 22
            radius: 11
            color: modelData.is_focused ? Theme.accent
                 : modelData.is_active ? Theme.bgAlt
                 : "transparent"
            border.color: modelData.active_window_id !== null ? Theme.fgDim : Theme.bgAlt
            border.width: modelData.is_focused ? 0 : 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: modelData.name || modelData.idx
                color: modelData.is_focused ? Theme.bg : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.bold: modelData.is_focused
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Niri.focusWorkspace(modelData.idx)
            }
        }
    }
}
