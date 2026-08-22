import Quickshell
import QtQuick

Text {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "HH:mm ddd, MMM dd")
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
}
