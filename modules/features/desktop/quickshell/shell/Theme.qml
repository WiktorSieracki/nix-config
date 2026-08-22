pragma Singleton
import Quickshell
import QtQuick

// Gruvbox-dark palette, matching the scheme the previous noctalia setup used
// (colorSchemes.predefinedScheme = "Gruvbox") and the static ghostty theme.
Singleton {
    readonly property color bg: "#282828"
    readonly property color bgAlt: "#3c3836"
    readonly property color fg: "#ebdbb2"
    readonly property color fgDim: "#a89984"
    readonly property color accent: "#83a598"
    readonly property color good: "#b8bb26"
    readonly property color warn: "#fabd2f"
    readonly property color urgent: "#fb4934"

    readonly property real barOpacity: 0.93
    readonly property int barHeight: 30
    readonly property int radius: 12
    readonly property string font: "Sans"
    readonly property string fontFixed: "monospace"
    readonly property int fontSize: 12
}
