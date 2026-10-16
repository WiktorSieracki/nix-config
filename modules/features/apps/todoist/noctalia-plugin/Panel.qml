import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "todoist.js" as Todoist

// The dropdown: Inbox / Today / Upcoming tabs, a quick-add field and the task
// list. Loaded on open and destroyed on close, so opening it is what triggers
// a fresh fetch. All state lives in Main.qml.
Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 620 * Style.uiScaleRatio
  property real contentPreferredHeight: 540 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  readonly property var main: pluginApi?.mainInstance ?? null
  readonly property string view: main?.view ?? "inbox"
  readonly property string today: main?.today ?? Todoist.localDate(new Date())
  readonly property var rows: main ? Todoist.buildRows(view, main.tasksFor(view), today) : []
  readonly property bool loading: main ? main.isLoading(view) : true

  readonly property var views: [
    {
      "id": "inbox",
      "label": "Inbox",
      "icon": "inbox"
    },
    {
      "id": "today",
      "label": "Today",
      "icon": "calendar-event"
    },
    {
      "id": "upcoming",
      "label": "Upcoming",
      "icon": "calendar-week"
    }
  ]

  function tabCount(v) {
    if (!main)
      return 0;
    return v === "inbox" ? main.inboxCount : v === "today" ? main.todayCount : 0;
  }

  Component.onCompleted: {
    if (main)
      main.refreshAll();
  }

  function setView(v) {
    if (!pluginApi || v === view)
      return;
    pluginApi.pluginSettings.view = v;
    pluginApi.saveSettings();
    main.refresh(v);
  }

  function submit() {
    if (!main || newTaskInput.text.trim() === "")
      return;
    var text = newTaskInput.text;
    newTaskInput.text = "";
    main.addTask(text, function (ok) {
      if (!ok)
        newTaskInput.text = text; // keep it for another try
    });
  }

  function syncLabel() {
    if (!main || isNaN(main.lastSync))
      return "";
    return "Synced " + Qt.formatTime(main.lastSync, "HH:mm");
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          // ── header ─────────────────────────────────────────────────────
          RowLayout {
            spacing: Style.marginM

            NIcon {
              icon: "clipboard-check"
              pointSize: Style.fontSizeXL
            }

            NText {
              text: "Todoist"
              pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item {
              Layout.fillWidth: true
            }

            NText {
              text: root.syncLabel()
              pointSize: Style.fontSizeXS
              color: Color.mOnSurfaceVariant
            }

            NIconButton {
              icon: "refresh"
              tooltipText: "Refresh"
              enabled: !root.loading
              onClicked: root.main?.refreshAll()
            }

            NButton {
              text: "Open Todoist"
              icon: "external-link"
              fontSize: Style.fontSizeS
              onClicked: {
                root.main?.openApp();
                root.pluginApi?.withCurrentScreen(screen => root.pluginApi.closePanel(screen));
              }
            }
          }

          // ── view tabs ──────────────────────────────────────────────────
          NTabBar {
            id: tabBar
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            distributeEvenly: true
            currentIndex: Math.max(0, root.views.findIndex(v => v.id === root.view))

            Repeater {
              model: root.views

              delegate: NTabButton {
                text: root.tabCount(modelData.id) > 0 ? modelData.label + "  " + root.tabCount(modelData.id) : modelData.label
                icon: modelData.icon
                tabIndex: index
                checked: index === tabBar.currentIndex

                Component.onCompleted: {
                  topLeftRadius = Style.iRadiusM;
                  bottomLeftRadius = Style.iRadiusM;
                  topRightRadius = Style.iRadiusM;
                  bottomRightRadius = Style.iRadiusM;
                }

                onClicked: root.setView(modelData.id)
              }
            }
          }

          // ── quick add ──────────────────────────────────────────────────
          RowLayout {
            spacing: Style.marginS
            enabled: root.main !== null && !root.main.needsAuth

            NTextInput {
              id: newTaskInput
              Layout.fillWidth: true
              placeholderText: "Add a task: \"Buy milk tomorrow p1 #Shopping\""
              Keys.onReturnPressed: root.submit()
              Keys.onEnterPressed: root.submit()
            }

            NIconButton {
              icon: "plus"
              tooltipText: "Add to Todoist (natural language: dates, p1–p4, #project, @label)"
              baseSize: Style.baseWidgetSize * 1.2
              customRadius: Style.iRadiusS
              onClicked: root.submit()
            }
          }

          // ── body ───────────────────────────────────────────────────────
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
              id: taskList
              anchors.fill: parent
              visible: root.rows.length > 0
              clip: true
              spacing: Style.marginXS
              boundsBehavior: Flickable.StopAtBounds
              model: root.rows

              delegate: Item {
                id: row

                required property var modelData
                readonly property bool isHeader: modelData.kind === "header"
                readonly property var task: modelData.task || null
                readonly property bool done: !isHeader && root.main !== null && root.main.completing[task.id] === true
                readonly property string prio: isHeader ? "" : Todoist.priorityColor(task.priority)
                readonly property string due: isHeader ? "" : Todoist.dueLabel(task, root.today)
                readonly property bool overdue: !isHeader && Todoist.isOverdue(task, root.today)
                readonly property string project: isHeader || root.view === "inbox" ? "" : (root.main?.projects[task.projectId] ?? "")

                width: ListView.view.width
                height: isHeader ? Style.baseWidgetSize * 0.9 : Math.round(Style.baseWidgetSize * 1.55)

                // Section header: "Overdue  2"
                NText {
                  visible: row.isHeader
                  anchors.left: parent.left
                  anchors.leftMargin: Style.marginS
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.marginXS
                  text: row.isHeader ? row.modelData.title + "  " + row.modelData.count : ""
                  pointSize: Style.fontSizeS
                  font.weight: Font.DemiBold
                  color: row.isHeader && row.modelData.urgent ? Color.mError : Color.mOnSurfaceVariant
                }

                Rectangle {
                  visible: !row.isHeader
                  anchors.fill: parent
                  color: Color.mSurface
                  radius: Style.radiusS
                  opacity: row.done ? 0.6 : 1

                  Behavior on opacity {
                    NumberAnimation {
                      duration: Style.animationFast
                    }
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginM
                    anchors.rightMargin: Style.marginM
                    spacing: Style.marginM

                    // Todoist-style round checkbox, ringed in the priority color.
                    Rectangle {
                      id: check
                      readonly property color ring: row.prio !== "" ? row.prio : Color.mOutline
                      Layout.preferredWidth: Math.round(Style.baseWidgetSize * 0.6)
                      Layout.preferredHeight: Layout.preferredWidth
                      radius: width / 2
                      border.width: Style.borderM
                      border.color: ring
                      color: row.done ? ring : (checkArea.containsMouse ? Qt.alpha(ring, 0.18) : "transparent")

                      Behavior on color {
                        ColorAnimation {
                          duration: Style.animationFast
                        }
                      }

                      NIcon {
                        anchors.centerIn: parent
                        visible: row.done || checkArea.containsMouse
                        icon: "check"
                        pointSize: Style.fontSizeXS
                        color: row.done ? Color.mSurface : check.ring
                      }

                      MouseArea {
                        id: checkArea
                        anchors.fill: parent
                        anchors.margins: -Style.marginXS
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.main?.toggleTask(row.task.id)
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      spacing: Style.marginXXS

                      NText {
                        Layout.fillWidth: true
                        text: row.task ? Todoist.plainText(row.task.content) : ""
                        elide: Text.ElideRight
                        font.strikeout: row.done
                        color: row.done ? Color.mOnSurfaceVariant : Color.mOnSurface
                      }

                      RowLayout {
                        visible: row.due !== "" || row.project !== ""
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        NIcon {
                          visible: row.due !== ""
                          icon: row.task && row.task.due && row.task.due.isRecurring ? "repeat" : "calendar"
                          pointSize: Style.fontSizeXS
                          color: dueText.color
                        }

                        NText {
                          id: dueText
                          visible: row.due !== ""
                          text: row.due
                          pointSize: Style.fontSizeXS
                          color: row.overdue ? Color.mError : (row.task && Todoist.dueDay(row.task) === root.today ? Color.mPrimary : Color.mOnSurfaceVariant)
                        }

                        Item {
                          Layout.fillWidth: true
                        }

                        NText {
                          visible: row.project !== ""
                          text: "#" + row.project
                          pointSize: Style.fontSizeXS
                          color: Color.mOnSurfaceVariant
                          elide: Text.ElideRight
                          Layout.maximumWidth: 180 * Style.uiScaleRatio
                        }
                      }
                    }
                  }
                }
              }
            }

            // Empty / loading / error states share the centre of the body.
            ColumnLayout {
              anchors.centerIn: parent
              width: parent.width * 0.8
              visible: root.rows.length === 0
              spacing: Style.marginM

              NBusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: root.loading && !root.main?.needsAuth && root.main?.errorText === ""
                running: visible
              }

              NIcon {
                Layout.alignment: Qt.AlignHCenter
                visible: !root.loading || root.main?.needsAuth || root.main?.errorText !== ""
                icon: root.main?.needsAuth ? "key" : (root.main?.errorText ? "alert-triangle" : "circle-check")
                pointSize: Style.fontSizeXXL
                color: root.main?.errorText && !root.main?.needsAuth ? Color.mError : Color.mOnSurfaceVariant
              }

              NText {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: !root.loading || root.main?.needsAuth || root.main?.errorText !== ""
                color: Color.mOnSurface
                text: {
                  if (!root.main)
                    return "";
                  if (root.main.needsAuth)
                    return root.main.authInProgress ? "Finish the login in your browser…" : "Connect Todoist: log in once in your browser and the token stays in your keyring.";
                  if (root.main.errorText)
                    return root.main.errorText;
                  return root.view === "inbox" ? "Inbox is empty" : root.view === "upcoming" ? "Nothing in the next 7 days" : "Nothing left for today";
                }
              }

              NButton {
                Layout.alignment: Qt.AlignHCenter
                visible: !!root.main && (root.main.needsAuth || root.main.errorText !== "")
                enabled: !root.main?.authInProgress
                text: root.main?.needsAuth ? "Log in with Todoist" : "Retry"
                icon: root.main?.needsAuth ? "login" : "refresh"
                onClicked: root.main.needsAuth ? root.main.login() : root.main.refreshAll()
              }
            }
          }
        }
      }
    }
  }
}
