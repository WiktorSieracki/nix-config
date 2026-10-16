import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Bar capsule: "3 todos" = Inbox + due today/overdue (Main.counts); it turns
// red while anything is overdue. Left click opens the panel.
Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property var main: pluginApi?.mainInstance ?? null
  readonly property int count: main?.activeCount ?? 0
  readonly property bool hasOverdue: (main?.overdueCount ?? 0) > 0
  readonly property bool needsAuth: main?.needsAuth ?? false

  readonly property string label: needsAuth ? "connect" : (count === 1 ? "1 todo" : count + " todos")
  readonly property string tooltipText: {
    if (!main)
      return "Todoist";
    if (needsAuth)
      return "Todoist: not logged in";
    var t = "Todoist: " + main.inboxCount + " in Inbox, " + main.todayCount + " for today";
    return hasOverdue ? t + " (" + main.overdueCount + " overdue)" : t;
  }
  readonly property color contentColor: mouseArea.containsMouse ? Color.mOnHover : (hasOverdue ? Color.mError : Color.mOnSurface)

  readonly property real contentWidth: isVertical ? capsuleHeight : horizontalRow.implicitWidth + Style.marginM * 2

  implicitWidth: contentWidth
  implicitHeight: capsuleHeight

  Rectangle {
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.capsuleHeight
    radius: Style.radiusL
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Row {
      id: horizontalRow
      anchors.centerIn: parent
      spacing: Style.marginS
      visible: !root.isVertical

      NIcon {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.needsAuth ? "key" : "clipboard-check"
        applyUiScale: false
        color: root.contentColor
      }

      NText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.contentColor
        pointSize: root.barFontSize
        applyUiScale: false
      }
    }

    NIcon {
      anchors.centerIn: parent
      visible: root.isVertical
      icon: "clipboard-check"
      applyUiScale: false
      color: root.contentColor
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.pluginApi?.openPanel(root.screen, this)
    onEntered: TooltipService.show(root, root.tooltipText, BarService.getTooltipDirection(root.screen?.name))
    onExited: TooltipService.hide()
  }
}
