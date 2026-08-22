import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Default-sink volume: scroll to change, left-click mutes, middle-click
// opens the mixer (same fallback chain noctalia used).
Text {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int pct: Math.round((sink?.audio?.volume ?? 0) * 100)

    PwObjectTracker {
        objects: [root.sink]
    }

    text: (muted ? "\u{1f507}" : "\u{1f50a}") + " " + pct + "%"
    color: muted ? Theme.fgDim : Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (!root.sink?.audio)
                return;
            if (mouse.button === Qt.LeftButton)
                root.sink.audio.muted = !root.sink.audio.muted;
            else
                Quickshell.execDetached(["sh", "-c", "pwvucontrol || pavucontrol"]);
        }
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
