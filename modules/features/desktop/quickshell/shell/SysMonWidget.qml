import Quickshell.Io
import QtQuick

// CPU% (delta of /proc/stat between polls) and used-memory, 3s cadence.
Text {
    id: root

    property real prevIdle: 0
    property real prevTotal: 0
    property string cpu: "--"
    property string mem: "--"

    text: "cpu " + cpu + "  mem " + mem
    color: Theme.fgDim
    font.family: Theme.fontFixed
    font.pixelSize: Theme.fontSize

    function parse(out: string): void {
        let memTotal = 0;
        let memAvail = 0;
        for (const line of out.trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f[0] === "cpu") {
                const n = f.slice(1).map(Number);
                const idle = n[3] + n[4];
                const total = n.reduce((a, b) => a + b, 0);
                const dIdle = idle - prevIdle;
                const dTotal = total - prevTotal;
                if (prevTotal > 0 && dTotal > 0)
                    cpu = Math.round(100 * (1 - dIdle / dTotal)) + "%";
                prevIdle = idle;
                prevTotal = total;
            } else if (f[0] === "MemTotal:") {
                memTotal = Number(f[1]);
            } else if (f[0] === "MemAvailable:") {
                memAvail = Number(f[1]);
            }
        }
        if (memTotal > 0)
            mem = ((memTotal - memAvail) / 1048576).toFixed(1) + "G";
    }

    Process {
        id: statProc
        command: ["sh", "-c", "head -n1 /proc/stat; grep -E 'MemTotal|MemAvailable' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }
}
