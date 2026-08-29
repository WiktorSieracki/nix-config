import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

Row {
    spacing: 8

    Repeater {
        model: SystemTray.items

        IconImage {
            id: icon

            required property var modelData

            source: modelData.icon
            implicitSize: 18
            anchors.verticalCenter: parent.verticalCenter

            QsMenuAnchor {
                id: menuAnchor
                menu: icon.modelData.menu
                anchor.item: icon
                anchor.edges: Edges.Bottom
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton && !modelData.onlyMenu)
                        modelData.activate();
                    else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate();
                    else if (modelData.hasMenu)
                        menuAnchor.open();
                }
            }
        }
    }
}
