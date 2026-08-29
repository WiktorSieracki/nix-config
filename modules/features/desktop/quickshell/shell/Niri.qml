pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Single event-stream connection to niri; every widget reads from here.
// `niri msg --json event-stream` replays full state (WorkspacesChanged,
// WindowsChanged) on connect, so a shell restart resyncs automatically.
Singleton {
    id: root

    // Array of workspace objects as niri sends them:
    // { id, idx, name, output, is_active, is_focused, active_window_id }
    property var workspaces: []
    property string focusedWindowTitle: ""
    property string focusedWindowAppId: ""

    // id -> window object; not directly bindable (mutated in place), widgets
    // should use the derived string properties above.
    property var _windows: ({})
    property int _focusedWindowId: -1

    function focusWorkspace(idx: int): void {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    function _updateFocusedWindow(): void {
        const w = _windows[_focusedWindowId];
        focusedWindowTitle = w ? (w.title || "") : "";
        focusedWindowAppId = w ? (w.app_id || "") : "";
    }

    function _handleEvent(ev: var): void {
        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id;
            const focused = ev.WorkspaceActivated.focused;
            const target = workspaces.find(w => w.id === id);
            if (!target)
                return;
            workspaces = workspaces.map(w => {
                const copy = Object.assign({}, w);
                if (w.output === target.output)
                    copy.is_active = (w.id === id);
                if (focused)
                    copy.is_focused = (w.id === id);
                return copy;
            });
        } else if (ev.WindowsChanged) {
            const map = {};
            for (const w of ev.WindowsChanged.windows) {
                map[w.id] = w;
                if (w.is_focused)
                    _focusedWindowId = w.id;
            }
            _windows = map;
            _updateFocusedWindow();
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            _windows[w.id] = w;
            if (w.is_focused)
                _focusedWindowId = w.id;
            _updateFocusedWindow();
        } else if (ev.WindowClosed) {
            delete _windows[ev.WindowClosed.id];
            if (_focusedWindowId === ev.WindowClosed.id)
                _focusedWindowId = -1;
            _updateFocusedWindow();
        } else if (ev.WindowFocusChanged) {
            _focusedWindowId = ev.WindowFocusChanged.id ?? -1;
            _updateFocusedWindow();
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root._handleEvent(JSON.parse(data));
                } catch (e) {
                    console.log("niri event parse error:", e);
                }
            }
        }
    }
}
