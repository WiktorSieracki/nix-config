import Quickshell.Services.UPower
import QtQuick

// Hidden on machines without a battery (mirrors noctalia's hideIfNotDetected).
Text {
    readonly property var dev: UPower.displayDevice
    readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging
        || dev.state === UPowerDeviceState.FullyCharged)
    readonly property int pct: dev ? Math.round(dev.percentage * 100) : 0

    visible: dev !== null && dev.isLaptopBattery
    text: (charging ? "⚡" : "■") + " " + pct + "%"
    color: pct <= 20 && !charging ? Theme.urgent : Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
}
