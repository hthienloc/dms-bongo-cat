import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "bongoCat"
    pluginService: PluginService

    // Global variables we will publish to
    PluginGlobalVar { id: globalCatState; varName: "catState"; defaultValue: 0 }
    PluginGlobalVar { id: globalIsWaiting; varName: "isWaiting"; defaultValue: true }
    PluginGlobalVar { id: globalIsBlinking; varName: "isBlinking"; defaultValue: false }
    PluginGlobalVar { id: globalForceSleep; varName: "forceSleep"; defaultValue: false }
    PluginGlobalVar { id: globalDeviceOptions; varName: "deviceOptions"; defaultValue: ["All Keyboards (Auto)"] }
    PluginGlobalVar { id: globalDeviceMap; varName: "deviceMap"; defaultValue: ({ "All Keyboards (Auto)": "all" }) }

    // Read settings from pluginData
    readonly property bool enableBlinking: (pluginData && pluginData.enableBlinking !== undefined ? pluginData.enableBlinking : true)
    readonly property int waitingTimeout: ((pluginData && pluginData.waitingTimeout !== undefined ? pluginData.waitingTimeout : 5)) * 1000
    readonly property int pawHoldTime: (pluginData && pluginData.pawHoldTime !== undefined ? pluginData.pawHoldTime : 0)
    readonly property string selectedDevicePath: (pluginData && pluginData.selectedDevicePath !== undefined ? pluginData.selectedDevicePath : "all")

    // Force sleep setting (can be changed from widgets)
    property bool forceSleep: (pluginData && pluginData.forceSleep !== undefined ? pluginData.forceSleep : false)
    onForceSleepChanged: {
        globalForceSleep.set(forceSleep);
        if (forceSleep) {
            isWaiting = true;
        } else {
            // Wake up immediately when disabling force sleep
            isWaiting = false;
            waitingTimer.restart();
        }
    }

    // React to changes from widgets on forceSleep
    Connections {
        target: PluginService
        function onPluginDataChanged(pid) {
            if (pid === root.pluginId) {
                const nextForceSleep = PluginService.loadPluginData(root.pluginId, "forceSleep", false);
                if (root.forceSleep !== nextForceSleep) {
                    root.forceSleep = nextForceSleep;
                }
            }
        }
    }

    // Logic and timers
    property int catState: 0
    onCatStateChanged: globalCatState.set(catState)

    property bool isWaiting: true
    onIsWaitingChanged: globalIsWaiting.set(isWaiting)

    property bool isBlinking: false
    onIsBlinkingChanged: globalIsBlinking.set(isBlinking)

    property bool leftWasLast: false

    // evtest/libinput device detection
    onSelectedDevicePathChanged: {
        console.log("[BongoDaemon] Device selection changed to:", selectedDevicePath);
        inputProc.running = false;
        inputRestartTimer.restart();
    }

    Timer {
        id: inputRestartTimer
        interval: 200
        onTriggered: inputProc.running = true
    }

    function onKeyPress(isBigHit) {
        isWaiting = false;
        let targetState;
        if (isBigHit) {
            targetState = 3;
        } else {
            if (catState !== 0) {
                targetState = 3;
            } else {
                leftWasLast = !leftWasLast;
                targetState = leftWasLast ? 1 : 2;
            }
        }
        catState = targetState;
        waitingTimer.restart();
    }

    function onKeyRelease(isBigHit) {
        let targetState;
        if (isBigHit) {
            targetState = 0;
        } else {
            if (catState === 3) {
                targetState = leftWasLast ? 1 : 2;
            } else {
                targetState = 0;
            }
        }
        if (root.pawHoldTime > 0) {
            pawHoldTimer.interval = root.pawHoldTime;
            pawHoldTimer.restart();
        } else {
            catState = targetState;
        }
    }

    function onKeyRepeat(isBigHit) {
        isWaiting = false;
        let targetState;
        if (catState !== 0) {
            targetState = catState;
        } else {
            if (isBigHit) {
                targetState = 3;
            } else {
                targetState = leftWasLast ? 1 : 2;
            }
        }
        catState = targetState;
        waitingTimer.restart();
    }

    Timer {
        id: waitingTimer
        interval: root.waitingTimeout
        onTriggered: isWaiting = true
    }

    Timer {
        id: pawHoldTimer
        onTriggered: {
            if (catState !== 0) {
                catState = 0;
            }
        }
    }

    Timer {
        id: blinkIntervalTimer
        interval: 6000 + Math.random() * 8000
        repeat: true
        running: root.enableBlinking && !root.isWaiting
        onTriggered: {
            interval = 6000 + Math.random() * 8000;
            isBlinking = true;
            blinkDurationTimer.start();
        }
    }

    Timer {
        id: blinkDurationTimer
        interval: 300
        onTriggered: isBlinking = false
    }

    function fetchDevices() {
        const includePattern = "kanata";
        const excludePattern = [
            "power button", "video bus", "speaker", "headphone",
            "lid switch", "touchpad", "extra buttons", "uinput",
            "server", "hitune", "inphic", "instant"
        ].join("|");

        const awkScript = `
            /^N: Name=/ {
                name = $0
                sub(/^N: Name="/, "", name)
                sub(/"$/, "", name)
            }
            /^H: Handlers=/ {
                lower = tolower(name)
                include = (lower ~ /${includePattern}/)
                exclude = (lower ~ /${excludePattern}/)
                if ($0 ~ /kbd/ && (include || ($0 !~ /mouse/ && !exclude))) {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^event[0-9]+$/) {
                            print name "|/dev/input/" $i
                            next
                        }
                    }
                }
            }
        `;
        const cmd = `awk '${awkScript}' /proc/bus/input/devices`;
        
        Proc.runCommand("bongoCat.fetchDevices", ["bash", "-c", cmd], (stdout, exitCode) => {
            if (exitCode !== 0) return;
            const output = stdout.trim();
            if (!output) return;

            let options = ["All Keyboards (Auto)"];
            let map = { "All Keyboards (Auto)": "all" };
            let seenPaths = new Set();
            seenPaths.add("all");

            output.split("\n").forEach(line => {
                const parts = line.split("|");
                if (parts.length === 2) {
                    const name = parts[0].trim();
                    const path = parts[1].trim();
                    if (seenPaths.has(path)) return;
                    seenPaths.add(path);

                    let uniqueName = name;
                    let i = 2;
                    while (options.includes(uniqueName)) {
                        uniqueName = name + " (" + i + ")";
                        i++;
                    }
                    options.push(uniqueName);
                    map[uniqueName] = path;
                }
            });
            globalDeviceOptions.set(options);
            globalDeviceMap.set(map);
        });
    }

    IpcHandler {
        target: "bongoDaemon"
        function refreshDevices() {
            root.fetchDevices();
        }
    }

    Component.onCompleted: {
        fetchDevices();
        globalForceSleep.set(root.forceSleep);
    }

    Process {
        id: inputProc
        command: {
            const cmd = selectedDevicePath === "all" ? ["libinput", "debug-events"] : ["evtest", selectedDevicePath];
            console.log("[BongoDaemon] Starting input process with command:", JSON.stringify(cmd));
            return cmd;
        }
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.includes("EV_KEY")) {
                    const isBigHit = data.includes("KEY_SPACE") || data.includes("KEY_ENTER") || data.includes("KEY_KPENTER");
                    if (data.includes("value 1")) {
                        root.onKeyPress(isBigHit);
                    } else if (data.includes("value 0")) {
                        root.onKeyRelease(isBigHit);
                    } else if (data.includes("value 2")) {
                        root.onKeyRepeat(isBigHit);
                    }
                } else if (data.includes("KEYBOARD_KEY")) {
                    const isBigHit = data.includes("KEY_SPACE") || data.includes("KEY_ENTER") || data.includes("KEY_KPENTER");
                    if (data.includes("pressed")) {
                        root.onKeyPress(isBigHit);
                    } else if (data.includes("released")) {
                        root.onKeyRelease(isBigHit);
                    } else if (data.includes("repeat")) {
                        root.onKeyRepeat(isBigHit);
                    }
                }
            }
        }

        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[BongoDaemon] evtest failed. Error code:", exitCode);
            }
        }
    }
}
