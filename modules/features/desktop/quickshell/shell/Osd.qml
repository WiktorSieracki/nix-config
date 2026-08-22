import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Volume OSD: pops top-right for 2s on any default-sink volume/mute change
// (matches the old noctalia osd.autoHideMs = 2000).
Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            osd.show();
        }

        function onMutedChanged() {
            osd.show();
        }
    }

    PanelWindow {
        id: osd

        property bool shown: false

        function show(): void {
            shown = true;
            hideTimer.restart();
        }

        visible: shown
        anchors {
            top: true
            right: true
        }
        margins.top: Theme.barHeight + 8
        margins.right: 8
        implicitWidth: 220
        implicitHeight: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        Timer {
            id: hideTimer

            interval: 2000
            onTriggered: osd.shown = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
            border.color: Theme.bgAlt
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.sink?.audio?.muted ?? false) ? "\u{1f507}" : "\u{1f50a}"
                    color: Theme.fg
                    font.pixelSize: Theme.fontSize + 2
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    height: 6
                    radius: 3
                    color: Theme.bgAlt

                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: parent.width * Math.min(1, root.sink?.audio?.volume ?? 0)
                        color: (root.sink?.audio?.muted ?? false) ? Theme.fgDim : Theme.accent
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round((root.sink?.audio?.volume ?? 0) * 100) + "%"
                    color: Theme.fg
                    font.family: Theme.fontFixed
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
