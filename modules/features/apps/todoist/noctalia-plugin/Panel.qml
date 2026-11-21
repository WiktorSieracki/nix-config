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

  // Text you can select and copy. Unlike NText it can't elide, so it wraps. Only
  // the text itself takes the mouse, so the rest of the row stays clickable.
  component SelectableText: TextEdit {
    id: selectable
    property real pointSize: Style.fontSizeM

    containmentMask: QtObject {
      function contains(point: point): bool {
        return point.x <= selectable.contentWidth && point.y <= selectable.contentHeight;
      }
    }

    Layout.fillWidth: true
    readOnly: true
    selectByMouse: true
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.Wrap
    font.family: Settings.data.ui.fontDefault
    font.pointSize: Math.max(1, pointSize * Settings.data.ui.fontDefaultScale * Style.uiScaleRatio)
    font.weight: Style.fontWeightMedium
    selectionColor: Color.mPrimary
    selectedTextColor: Color.mOnPrimary

    HoverHandler {
      cursorShape: Qt.IBeamCursor
    }
  }

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

  // Task ids whose description is unfolded. Kept here, not in the delegate:
  // every refresh hands the ListView a new rows array, which rebuilds rows.
  property var expanded: ({})

  function toggleExpanded(id) {
    var next = Object.assign({}, expanded);
    if (next[id])
      delete next[id];
    else
      next[id] = true;
    expanded = next;
  }

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

  // New tasks land on top, so a scrolled list has to come back up to show one.
  property bool scrollToTopOnNewRow: false

  function submit() {
    if (!main || newTaskInput.text.trim() === "")
      return;
    var text = newTaskInput.text;
    newTaskInput.text = "";
    main.addTask(text, function (ok) {
      if (ok)
        scrollToTopOnNewRow = true;
      else
        newTaskInput.text = text; // keep it for another try
    });
  }

  // Dragging a row by its grip. dragGap is the gap the drop lands in: before row
  // dragGap, or past the end when it equals the row count.
  readonly property bool canDrag: view === "inbox" && main !== null && Todoist.canReorder(main.inboxTasks)
  property int dragFrom: -1
  property int dragGap: -1
  // List-relative pointer y, for scrolling while the pointer rests near an edge.
  property real dragY: 0

  function updateDrag(y) {
    dragY = y;
    var contentY = y + taskList.contentY;
    var last = rows.length - 1;
    var i = taskList.indexAt(taskList.width / 2, contentY);
    if (i < 0)
      i = contentY < 0 ? 0 : last;
    var item = taskList.itemAtIndex(i);
    dragGap = item && contentY > item.y + item.height / 2 ? i + 1 : i;
  }

  function endDrag(drop) {
    var from = dragFrom;
    var gap = dragGap;
    dragFrom = -1;
    dragGap = -1;
    if (drop && main && from >= 0 && gap >= 0)
      main.moveTask(from, Todoist.gapToIndex(from, gap));
  }

  // The task open in the editor, which takes the place of the list. It is a copy
  // kept here, so a refresh rebuilding the rows can't touch what is being typed.
  property var editing: null
  property bool saving: false

  function startEdit(task) {
    editing = task;
    editTitle.text = task.content;
    editDescription.text = task.description;
    editTitle.inputItem.forceActiveFocus();
  }

  function saveEdit() {
    if (!main || !editing || saving || editTitle.text.trim() === "")
      return;
    var args = Todoist.updateTaskArgs(editing, editTitle.text, editDescription.text);
    if (!args) {
      editing = null;
      return;
    }
    saving = true;
    main.updateTask(args, function (ok) {
      saving = false;
      if (ok)
        editing = null;
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
            visible: !root.editing

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
              visible: root.rows.length > 0 && !root.editing
              clip: true
              spacing: Style.marginXS
              boundsBehavior: Flickable.StopAtBounds
              model: root.rows

              onCountChanged: {
                if (root.scrollToTopOnNewRow) {
                  root.scrollToTopOnNewRow = false;
                  positionViewAtBeginning();
                }
              }

              delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool isHeader: modelData.kind === "header"
                readonly property var task: modelData.task || null
                readonly property bool done: !isHeader && root.main !== null && root.main.completing[task.id] === true
                readonly property string prio: isHeader ? "" : Todoist.priorityColor(task.priority)
                readonly property string due: isHeader ? "" : Todoist.dueLabel(task, root.today)
                readonly property bool overdue: !isHeader && Todoist.isOverdue(task, root.today)
                readonly property string project: isHeader || root.view === "inbox" ? "" : (root.main?.projects[task.projectId] ?? "")
                readonly property string descPreview: isHeader ? "" : Todoist.descriptionPreview(task.description)
                readonly property bool expanded: !isHeader && root.expanded[task.id] === true
                // Worth unfolding when there is more than the one line shown.
                readonly property bool expandable: descPreview !== "" && (expanded || descText.truncated || Todoist.descriptionLines(task.description).length > 1)

                width: ListView.view.width
                height: isHeader ? Style.baseWidgetSize * 0.9 : Math.max(Math.round(Style.baseWidgetSize * 1.55), textColumn.implicitHeight + Style.marginS * 2)

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
                  opacity: row.index === root.dragFrom ? 0.4 : (row.done ? 0.6 : 1)

                  Behavior on opacity {
                    NumberAnimation {
                      duration: Style.animationFast
                    }
                  }

                  HoverHandler {
                    id: rowHover
                  }

                  // Clicking the row folds the description in or out. Declared
                  // before the content, so the checkbox's own area stays on top.
                  MouseArea {
                    anchors.fill: parent
                    enabled: row.expandable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleExpanded(row.task.id)
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.marginM
                    anchors.rightMargin: Style.marginM
                    anchors.topMargin: Style.marginS
                    anchors.bottomMargin: Style.marginS
                    spacing: Style.marginM

                    // The grip, not the row, starts a drag: pressing the row's
                    // text has to select it instead.
                    NIcon {
                      visible: root.canDrag
                      Layout.alignment: row.expanded ? Qt.AlignTop : Qt.AlignVCenter
                      Layout.leftMargin: -Style.marginS
                      Layout.rightMargin: -Style.marginS
                      icon: "grip-vertical"
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                      opacity: rowHover.hovered || row.index === root.dragFrom ? 1 : 0

                      MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Style.marginXS
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        function listY(mouse) {
                          return mapToItem(taskList, mouse.x, mouse.y).y;
                        }

                        onPressed: mouse => {
                          root.dragFrom = row.index;
                          root.updateDrag(listY(mouse));
                        }
                        onPositionChanged: mouse => root.updateDrag(listY(mouse))
                        onReleased: root.endDrag(true)
                        onCanceled: root.endDrag(false)
                        // A refresh that changes the tasks rebuilds this row mid-drag.
                        Component.onDestruction: {
                          if (pressed)
                            root.endDrag(false);
                        }
                      }
                    }

                    // Todoist-style round checkbox, ringed in the priority color.
                    // An unfolded row is tall, so the box moves up to the title.
                    Rectangle {
                      id: check
                      readonly property color ring: row.prio !== "" ? row.prio : Color.mOutline
                      Layout.alignment: row.expanded ? Qt.AlignTop : Qt.AlignVCenter
                      Layout.topMargin: row.expanded ? Math.max(0, (titleText.height - height) / 2) : 0
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
                      id: textColumn
                      Layout.fillWidth: true
                      Layout.alignment: row.expanded ? Qt.AlignTop : Qt.AlignVCenter
                      spacing: Style.marginXXS

                      SelectableText {
                        id: titleText
                        text: row.task ? Todoist.plainText(row.task.content) : ""
                        font.strikeout: row.done
                        color: row.done ? Color.mOnSurfaceVariant : Color.mOnSurface
                      }

                      // Description: its first line, greyed and cut to fit; the
                      // whole text, wrapped, once the row is unfolded.
                      RowLayout {
                        visible: row.descPreview !== ""
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        NText {
                          id: descText
                          visible: !row.expanded
                          Layout.fillWidth: true
                          text: row.descPreview
                          pointSize: Style.fontSizeXS
                          font.weight: Font.Normal
                          color: Color.mOnSurfaceVariant
                        }

                        SelectableText {
                          visible: row.expanded
                          text: row.expanded ? Todoist.descriptionFull(row.task.description) : ""
                          pointSize: Style.fontSizeXS
                          font.weight: Font.Normal
                          color: Color.mOnSurfaceVariant
                        }

                        // Pushes the chevron to the edge past a short description.
                        Item {
                          visible: row.expanded
                          Layout.fillWidth: true
                        }

                        NIcon {
                          visible: row.expandable
                          Layout.alignment: Qt.AlignTop
                          icon: row.expanded ? "chevron-up" : "chevron-down"
                          pointSize: Style.fontSizeXS
                          color: Color.mOnSurfaceVariant
                        }
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

                    // Shown on hover, but always taking their space, so text
                    // doesn't reflow under the pointer.
                    RowLayout {
                      Layout.alignment: Qt.AlignTop
                      spacing: Style.marginXXS
                      opacity: rowHover.hovered ? 1 : 0

                      NIconButton {
                        icon: "copy"
                        tooltipText: "Copy title and description"
                        baseSize: Style.baseWidgetSize * 0.7
                        border.width: 0
                        colorBg: "transparent"
                        colorFg: Color.mOnSurfaceVariant
                        onClicked: root.main?.copyTask(row.task)
                      }

                      NIconButton {
                        icon: "pencil"
                        tooltipText: "Edit"
                        baseSize: Style.baseWidgetSize * 0.7
                        border.width: 0
                        colorBg: "transparent"
                        colorFg: Color.mOnSurfaceVariant
                        onClicked: root.startEdit(row.task)
                      }
                    }
                  }
                }
              }
            }

            // Where a dragged row will land.
            Rectangle {
              visible: root.dragGap >= 0
              width: taskList.width
              height: Style.borderM
              color: Color.mPrimary
              y: {
                if (root.dragGap < 0)
                  return 0;
                var before = root.dragGap > 0 ? taskList.itemAtIndex(root.dragGap - 1) : null;
                var after = taskList.itemAtIndex(root.dragGap);
                var y = after ? after.y - taskList.spacing / 2 : before ? before.y + before.height + taskList.spacing / 2 : 0;
                return Math.max(0, Math.min(taskList.height - height, y - taskList.contentY));
              }
            }

            // Scrolls while the pointer rests near an edge, where no motion
            // events arrive; re-measures the gap as the rows slide by.
            Timer {
              interval: 30
              repeat: true
              running: root.dragFrom >= 0
              onTriggered: {
                var edge = Style.baseWidgetSize;
                var step = root.dragY < edge ? -8 : root.dragY > taskList.height - edge ? 8 : 0;
                if (step === 0)
                  return;
                var max = Math.max(0, taskList.contentHeight - taskList.height);
                taskList.contentY = Math.max(0, Math.min(max, taskList.contentY + step));
                root.updateDrag(root.dragY);
              }
            }

            // ── editor ─────────────────────────────────────────────────────
            // Esc would otherwise reach noctalia's window-wide shortcut and
            // close the whole panel, so claim it before the shortcut fires.
            ColumnLayout {
              anchors.fill: parent
              visible: root.editing !== null
              spacing: Style.marginS

              Keys.onShortcutOverride: event => {
                if (event.key === Qt.Key_Escape)
                  event.accepted = true;
              }
              Keys.onEscapePressed: root.editing = null

              NTextInput {
                id: editTitle
                Layout.fillWidth: true
                placeholderText: "Title"
                Keys.onReturnPressed: root.saveEdit()
                Keys.onEnterPressed: root.saveEdit()
              }

              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurface
                radius: Style.iRadiusM
                border.width: Style.borderS
                border.color: editDescription.activeFocus ? Color.mSecondary : Color.mOutline

                ScrollView {
                  anchors.fill: parent
                  anchors.margins: Style.marginS

                  TextArea {
                    id: editDescription
                    placeholderText: "Description (markdown)"
                    placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.6)
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    background: null
                    color: Color.mOnSurface
                    selectionColor: Color.mPrimary
                    selectedTextColor: Color.mOnPrimary
                    font.family: Settings.data.ui.fontDefault
                    font.pointSize: Style.fontSizeS * Style.uiScaleRatio

                    // Plain Enter is a new line here; Ctrl+Enter saves.
                    Keys.onPressed: event => {
                      if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                        event.accepted = true;
                        root.saveEdit();
                      }
                    }
                  }
                }
              }

              RowLayout {
                spacing: Style.marginS

                NText {
                  Layout.fillWidth: true
                  text: "Ctrl+Enter saves, Esc cancels"
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                }

                NButton {
                  text: "Cancel"
                  fontSize: Style.fontSizeS
                  onClicked: root.editing = null
                }

                NButton {
                  text: "Save"
                  icon: "check"
                  fontSize: Style.fontSizeS
                  enabled: !root.saving && editTitle.text.trim() !== ""
                  onClicked: root.saveEdit()
                }
              }
            }

            // Empty / loading / error states share the centre of the body.
            ColumnLayout {
              anchors.centerIn: parent
              width: parent.width * 0.8
              visible: root.rows.length === 0 && !root.editing
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
