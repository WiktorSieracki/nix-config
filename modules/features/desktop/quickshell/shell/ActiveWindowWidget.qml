import QtQuick

Text {
    visible: Niri.focusedWindowTitle !== ""
    text: Niri.focusedWindowTitle
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 300)
}
