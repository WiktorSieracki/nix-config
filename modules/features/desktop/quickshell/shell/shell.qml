import Quickshell
import Quickshell.Io
import QtQuick

// Custom quickshell system UI (replaces noctalia). Surfaces: per-screen top
// bar, app launcher, session menu, notification popups, volume OSD.
// niri binds reach the launcher/session menu through `qs ipc` — see the
// quickshell-ui-ipc wrapper in quickshell.nix for the generation-drift story.
ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Launcher {
        id: launcher
    }

    SessionMenu {
        id: sessionMenu
    }

    NotificationPopups {}

    Osd {}

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.toggle();
        }
    }

    IpcHandler {
        target: "sessionMenu"

        function toggle(): void {
            sessionMenu.toggle();
        }
    }
}
