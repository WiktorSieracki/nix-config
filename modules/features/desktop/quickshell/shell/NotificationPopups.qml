import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Freedesktop notification daemon + top-right popup stack. Durations per
// urgency match the old noctalia settings (3s / 8s / 15s). No history panel —
// a popup missed is a popup gone (see notes.md).
Scope {
    id: root

    NotificationServer {
        id: server

        bodySupported: true
        actionsSupported: false
        imageSupported: false
        persistenceSupported: false

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    PanelWindow {
        visible: server.trackedNotifications.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins.top: Theme.barHeight + 8
        margins.right: 8
        implicitWidth: 360
        implicitHeight: Math.max(1, column.implicitHeight)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        Column {
            id: column

            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                Rectangle {
                    id: popup

                    required property var modelData

                    readonly property int duration: {
                        if (modelData.urgency === NotificationUrgency.Critical)
                            return 15000;
                        if (modelData.urgency === NotificationUrgency.Low)
                            return 3000;
                        return 8000;
                    }

                    width: column.width
                    implicitHeight: content.implicitHeight + 20
                    radius: Theme.radius
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
                    border.color: modelData.urgency === NotificationUrgency.Critical
                        ? Theme.urgent : Theme.bgAlt
                    border.width: 1

                    Column {
                        id: content

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 3

                        Text {
                            width: parent.width
                            visible: popup.modelData.appName !== ""
                            text: popup.modelData.appName
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: popup.modelData.summary
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            visible: popup.modelData.body !== ""
                            text: popup.modelData.body
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            wrapMode: Text.Wrap
                            maximumLineCount: 5
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: popup.modelData.dismiss()
                    }

                    Timer {
                        interval: popup.duration
                        running: true
                        onTriggered: popup.modelData.expire()
                    }
                }
            }
        }
    }
}
