import Quickshell
import Quickshell.Wayland
import QtQuick

// App launcher (Mod+Space via IPC): fuzzy-ish name filter over desktop
// entries, arrow-key navigation, Enter launches, Escape closes.
PanelWindow {
    id: root

    property bool shown: false
    property string query: ""

    readonly property var entries: {
        const q = query.toLowerCase();
        let apps = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        if (q !== "") {
            apps = apps.filter(e => e.name.toLowerCase().includes(q)
                || (e.genericName || "").toLowerCase().includes(q));
            apps.sort((a, b) => {
                const as = a.name.toLowerCase().startsWith(q) ? 0 : 1;
                const bs = b.name.toLowerCase().startsWith(q) ? 0 : 1;
                return as - bs || a.name.localeCompare(b.name);
            });
        } else {
            apps.sort((a, b) => a.name.localeCompare(b.name));
        }
        return apps.slice(0, 40);
    }

    function toggle(): void {
        shown = !shown;
        query = "";
        if (shown)
            input.forceActiveFocus();
    }

    function launch(): void {
        const e = list.currentItem?.entry;
        if (e) {
            e.execute();
            shown = false;
        }
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

    // Click outside the panel closes it.
    MouseArea {
        anchors.fill: parent
        onClicked: root.shown = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 520
        height: 480
        radius: Theme.radius
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.barOpacity)
        border.color: Theme.bgAlt
        border.width: 1

        MouseArea {
            // Swallow clicks so they don't reach the close-on-click-outside area.
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: Theme.bgAlt

                TextInput {
                    id: input

                    anchors.fill: parent
                    anchors.margins: 9
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                    text: root.query
                    onTextChanged: {
                        root.query = text;
                        list.currentIndex = 0;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.shown = false;
                        } else if (event.key === Qt.Key_Down) {
                            list.incrementCurrentIndex();
                        } else if (event.key === Qt.Key_Up) {
                            list.decrementCurrentIndex();
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launch();
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "Search apps…"
                        color: Theme.fgDim
                        font: input.font
                    }
                }
            }

            ListView {
                id: list

                width: parent.width
                height: parent.height - 44
                clip: true
                model: root.entries
                currentIndex: 0

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property var entry: modelData

                    width: list.width
                    height: 34
                    radius: 8
                    color: ListView.isCurrentItem ? Theme.bgAlt : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        text: parent.entry.name
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: list.currentIndex = parent.index
                        onClicked: root.launch()
                    }
                }
            }
        }
    }
}
