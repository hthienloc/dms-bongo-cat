import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import "./services"

PluginComponent {
    id: root
    pluginId: "bongoCat"
    pluginService: PluginService

    PluginGlobalVar { id: globalCatState; varName: "catState"; defaultValue: 0 }
    PluginGlobalVar { id: globalIsWaiting; varName: "isWaiting"; defaultValue: true }
    PluginGlobalVar { id: globalIsBlinking; varName: "isBlinking"; defaultValue: false }
    PluginGlobalVar { id: globalForceSleep; varName: "forceSleep"; defaultValue: false }
    PluginGlobalVar { id: globalDeviceOptions; varName: "deviceOptions"; defaultValue: ["All Keyboards (Auto)"] }
    PluginGlobalVar { id: globalDeviceMap; varName: "deviceMap"; defaultValue: ({ "All Keyboards (Auto)": "all" }) }
    PluginGlobalVar { id: globalInputBroken; varName: "inputBroken"; defaultValue: false }
    PluginGlobalVar { id: globalMouseBroken; varName: "mouseBroken"; defaultValue: false }
    PluginGlobalVar { id: globalLiveWpm; varName: "liveWpm"; defaultValue: 0 }
    PluginGlobalVar { id: globalCleanPercent; varName: "cleanPercent"; defaultValue: 100 }

    readonly property string selectedDevicePath: (pluginData && pluginData.selectedDevicePath !== undefined ? pluginData.selectedDevicePath : "all")
    readonly property int waitingTimeout: ((pluginData && pluginData.waitingTimeout !== undefined ? pluginData.waitingTimeout : 5)) * 1000
    readonly property int pawHoldTime: (pluginData && pluginData.pawHoldTime !== undefined ? pluginData.pawHoldTime : 0)
    readonly property bool doubleSlam: (pluginData && pluginData.doubleSlam !== undefined ? pluginData.doubleSlam : true)
    readonly property bool enableBlinking: (pluginData && pluginData.enableBlinking !== undefined ? pluginData.enableBlinking : true)
    readonly property bool mouseEnabled: (pluginData && pluginData.mouseEnabled !== undefined ? pluginData.mouseEnabled : false)
    readonly property bool showMetrics: (pluginData && pluginData.showMetrics !== undefined ? pluginData.showMetrics : false)
    readonly property int metricsWindowSec: (pluginData && pluginData.metricsWindowSec !== undefined ? pluginData.metricsWindowSec : 60)
    readonly property int metricsWindowMs: metricsWindowSec * 1000
    readonly property bool soundEnabled: (pluginData && pluginData.soundEnabled !== undefined ? pluginData.soundEnabled : false)
    readonly property int soundVolume: (pluginData && pluginData.soundVolume !== undefined ? pluginData.soundVolume : 60)
    readonly property bool soundOnMouse: (pluginData && pluginData.soundOnMouse !== undefined ? pluginData.soundOnMouse : false)
    readonly property string soundProfile: (pluginData && pluginData.soundProfile !== undefined ? pluginData.soundProfile : "bongo")
    readonly property real _soundVol: Math.max(0, Math.min(1, soundVolume / 100))

    property bool forceSleep: (pluginData && pluginData.forceSleep !== undefined ? pluginData.forceSleep : false)
    onForceSleepChanged: {
        globalForceSleep.set(forceSleep);
        if (forceSleep) isWaiting = true;
    }
    Connections {
        target: pluginData ? pluginData : null
        function onForceSleepChanged() { root.forceSleep = pluginData.forceSleep; }
    }

    property bool inputToolMissing: false
    property bool notInInputGroup: false
    readonly property bool inputBroken: inputToolMissing || notInInputGroup
    onInputBrokenChanged: globalInputBroken.set(inputBroken)
    readonly property string requiredTool: selectedDevicePath === "all" ? "libinput" : "evtest"

    onRequiredToolChanged: {
        toolCheck.running = false;
        toolCheck.running = true;
        clearMouseState();
        refreshMouseToolCheck();
    }

    Process {
        id: toolCheck
        command: ["sh", "-c", "command -v " + root.requiredTool + " >/dev/null 2>&1"]
        running: true
        onExited: (exitCode, exitStatus) => { root.inputToolMissing = (exitCode !== 0); }
    }

    readonly property bool mouseBroken: mouseEnabled && selectedDevicePath !== "all" && mouseToolMissing
    onMouseBrokenChanged: globalMouseBroken.set(mouseBroken)
    property bool mouseToolMissing: false

    onMouseEnabledChanged: { clearMouseState(); refreshMouseToolCheck(); }

    function refreshMouseToolCheck() {
        if (mouseEnabled && selectedDevicePath !== "all") {
            mouseToolCheck.running = false;
            mouseToolCheck.running = true;
        }
    }

    Process {
        id: mouseToolCheck
        command: ["sh", "-c", "command -v libinput >/dev/null 2>&1"]
        running: true
        onExited: (exitCode, exitStatus) => { root.mouseToolMissing = (exitCode !== 0); }
    }

    Process {
        id: mouseProc
        command: ["libinput", "debug-events"]
        running: root.mouseEnabled && root.selectedDevicePath !== "all" && !root.mouseToolMissing
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.includes("POINTER_BUTTON") || data.includes("POINTER_SCROLL")) {
                    root.handlePointerLine(data);
                }
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: groupCheck
        command: ["sh", "-c", "id -nG | tr ' ' '\n' | grep -qx input"]
        running: true
        onExited: (exitCode, exitStatus) => { root.notInInputGroup = (exitCode !== 0); }
    }

    onSelectedDevicePathChanged: {
        console.log("[BongoDaemon] Device selection changed to:", selectedDevicePath);
        inputProc.running = false;
        inputRestartTimer.restart();
        resetMetrics();
    }

    Timer {
        id: inputRestartTimer
        interval: 200
        onTriggered: inputProc.running = true
    }

    property int catState: 0
    onCatStateChanged: globalCatState.set(catState)
    property bool isWaiting: true
    onIsWaitingChanged: globalIsWaiting.set(isWaiting)
    property bool isBlinking: false
    onIsBlinkingChanged: globalIsBlinking.set(isBlinking)
    property bool leftWasLast: false

    property int kbState: 0
    property int mouseState: 0
    property int scrollState: 0
    property bool scrollLeftWasLast: false
    property bool mouseLeftDown: false
    property bool mouseRightDown: false
    property bool mouseOtherDown: false

    function resolveCatState() {
        const states = [kbState, mouseState, scrollState].filter(s => s !== 0);
        if (states.length === 0) {
            catState = 0;
        } else if (states.indexOf(3) !== -1 || (states.indexOf(1) !== -1 && states.indexOf(2) !== -1)) {
            catState = 3;
        } else {
            catState = states[0];
        }
    }

    function updateMousePaws() {
        isWaiting = false;
        if ((mouseLeftDown && mouseRightDown) || mouseOtherDown) {
            mouseState = 3;
        } else if (mouseLeftDown) {
            mouseState = 1;
        } else if (mouseRightDown) {
            mouseState = 2;
        } else {
            mouseState = 0;
        }
        resolveCatState();
        waitingTimer.restart();
    }

    function clearMouseState() {
        mouseLeftDown = false;
        mouseRightDown = false;
        mouseOtherDown = false;
        mouseState = 0;
        scrollState = 0;
        scrollReleaseTimer.stop();
        resolveCatState();
    }

    function onMouseButton(buttonName, pressed) {
        if (pressed && soundOnMouse) playClick(false);
        if (buttonName === "BTN_LEFT") {
            mouseLeftDown = pressed;
        } else if (buttonName === "BTN_RIGHT") {
            mouseRightDown = pressed;
        } else {
            mouseOtherDown = pressed;
        }
        updateMousePaws();
    }

    function onScrollTick() {
        isWaiting = false;
        scrollReleaseTimer.restart();
        waitingTimer.restart();
        if (scrollThrottle.running) return;
        scrollThrottle.restart();
        scrollLeftWasLast = !scrollLeftWasLast;
        scrollState = scrollLeftWasLast ? 1 : 2;
        resolveCatState();
    }

    Timer {
        id: scrollThrottle; interval: 75; repeat: false
    }
    Timer {
        id: scrollReleaseTimer; interval: 150; repeat: false
        onTriggered: { root.scrollState = 0; root.resolveCatState(); }
    }

    function handlePointerLine(data) {
        if (data.includes("POINTER_BUTTON")) {
            const match = data.match(/(BTN_[A-Z0-9_]+)/);
            const name = match ? match[1] : "BTN_OTHER";
            if (data.includes("pressed")) root.onMouseButton(name, true);
            else if (data.includes("released")) root.onMouseButton(name, false);
        } else if (data.includes("POINTER_SCROLL")) {
            const vert = data.match(/vert\s+(-?\d+(?:\.\d+)?)/);
            const horiz = data.match(/horiz\s+(-?\d+(?:\.\d+)?)/);
            if (vert && horiz && parseFloat(vert[1]) === 0 && parseFloat(horiz[1]) === 0) return;
            root.onScrollTick();
        }
    }

    function onKeyPress(isBigHit) {
        isWaiting = false;
        playClick(isBigHit);
        let targetState;
        if (isBigHit) {
            targetState = 3;
        } else {
            if (kbState !== 0) {
                targetState = 3;
            } else {
                leftWasLast = !leftWasLast;
                targetState = leftWasLast ? 1 : 2;
            }
        }
        kbState = targetState;
        resolveCatState();
        waitingTimer.restart();
    }

    function onKeyRelease(isBigHit) {
        let targetState;
        if (isBigHit) {
            targetState = 0;
        } else {
            if (kbState === 3) {
                targetState = leftWasLast ? 1 : 2;
            } else {
                targetState = 0;
            }
        }
        if (root.pawHoldTime > 0) {
            pawHoldTimer.interval = root.pawHoldTime;
            pawHoldTimer.restart();
        } else {
            kbState = targetState;
            resolveCatState();
        }
    }

    function onKeyRepeat(isBigHit) {
        isWaiting = false;
        let targetState;
        if (kbState !== 0) {
            targetState = kbState;
        } else {
            if (isBigHit) {
                targetState = 3;
            } else {
                targetState = leftWasLast ? 1 : 2;
            }
        }
        kbState = targetState;
        resolveCatState();
        waitingTimer.restart();
    }

    Timer {
        id: waitingTimer
        interval: root.waitingTimeout
        onTriggered: {
            if (root.mouseLeftDown || root.mouseRightDown || root.mouseOtherDown) { restart(); return; }
            isWaiting = true;
        }
    }

    Timer {
        id: pawHoldTimer
        onTriggered: {
            if (kbState !== 0) { kbState = 0; resolveCatState(); }
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

    property int liveWpm: 0
    property int cleanPercent: 100
    onLiveWpmChanged: globalLiveWpm.set(liveWpm)
    onCleanPercentChanged: globalCleanPercent.set(cleanPercent)
    property var _charStamps: []
    property var _correctionStamps: []

    readonly property var _nonCharKeys: ({
        "KEY_LEFTSHIFT": 1, "KEY_RIGHTSHIFT": 1, "KEY_LEFTCTRL": 1, "KEY_RIGHTCTRL": 1,
        "KEY_LEFTALT": 1, "KEY_RIGHTALT": 1, "KEY_LEFTMETA": 1, "KEY_RIGHTMETA": 1,
        "KEY_CAPSLOCK": 1, "KEY_NUMLOCK": 1, "KEY_SCROLLLOCK": 1,
        "KEY_ESC": 1, "KEY_ENTER": 1, "KEY_KPENTER": 1, "KEY_TAB": 1,
        "KEY_LEFT": 1, "KEY_RIGHT": 1, "KEY_UP": 1, "KEY_DOWN": 1,
        "KEY_HOME": 1, "KEY_END": 1, "KEY_PAGEUP": 1, "KEY_PAGEDOWN": 1, "KEY_INSERT": 1,
        "KEY_COMPOSE": 1, "KEY_MENU": 1, "KEY_SYSRQ": 1, "KEY_PAUSE": 1
    })

    function classifyKey(name) {
        if (name === "KEY_BACKSPACE" || name === "KEY_DELETE") return "correction";
        if (_nonCharKeys[name] || /^KEY_F\d+$/.test(name)) return "ignore";
        return "char";
    }

    function recordKeystroke(keyName) {
        if (!showMetrics || !keyName) return;
        const kind = classifyKey(keyName);
        if (kind === "ignore") return;
        if (kind === "correction") _correctionStamps.push(Date.now());
        else _charStamps.push(Date.now());
    }

    function _pruneAndCompute() {
        const cutoff = Date.now() - metricsWindowMs;
        _charStamps = _charStamps.filter(t => t >= cutoff);
        _correctionStamps = _correctionStamps.filter(t => t >= cutoff);
        const chars = _charStamps.length;
        const corrections = _correctionStamps.length;
        liveWpm = metricsWindowMs > 0 ? Math.round(chars / 5 * 60000 / metricsWindowMs) : 0;
        cleanPercent = (chars + corrections) > 0 ? Math.round(100 * chars / (chars + corrections)) : 100;
    }

    function resetMetrics() {
        _charStamps = []; _correctionStamps = []; liveWpm = 0; cleanPercent = 100;
    }

    onShowMetricsChanged: resetMetrics()
    onMetricsWindowSecChanged: resetMetrics()

    Timer {
        id: metricsTicker
        interval: 1000; repeat: true; running: root.showMetrics
        onTriggered: root._pruneAndCompute()
    }

    function saveSetting(key, value) {
        try {
            pluginService.savePluginData(pluginId, key, value);
            if (pluginData) pluginData[key] = value;
        } catch(e) {
            console.warn("[BongoDaemon] Failed to save setting:", key, e);
        }
    }

    function playClick(isBigHit) {
        if (!soundEnabled || forceSleep) return;
        BongoSoundService.volume = _soundVol;
        BongoSoundService.soundProfile = soundProfile;
        BongoSoundService.play(isBigHit);
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
                    while (options.includes(uniqueName)) { uniqueName = name + " (" + i + ")"; i++; }
                    options.push(uniqueName);
                    map[uniqueName] = path;
                }
            });
            globalDeviceOptions.set(options);
            globalDeviceMap.set(map);
        });
    }

    onPluginDataChanged: migrateColorSetting()
    Component.onCompleted: {
        fetchDevices();
        migrateColorSetting();
        BongoSoundService.volume = _soundVol;
        BongoSoundService.soundProfile = soundProfile;
    }

    function migrateColorSetting() {
        if (pluginData && pluginData.catColorMode === undefined && pluginData.activeColor === true) {
            saveSetting("catColorMode", "primary");
        }
    }

    IpcHandler {
        target: "bongoDaemon"
        function refreshDevices() { root.fetchDevices(); }
    }

    Process {
        id: inputProc
        command: {
            const cmd = selectedDevicePath === "all"
                ? ["libinput", "debug-events", "--show-keycodes"]
                : ["evtest", selectedDevicePath];
            console.log("[BongoDaemon] Starting input process with command:", JSON.stringify(cmd));
            return cmd;
        }
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.includes("EV_KEY")) {
                    const keyMatch = data.match(/(KEY_[A-Z0-9_]+)/);
                    const keyName = keyMatch ? keyMatch[1] : "";
                    const isBigHit = root.doubleSlam && (keyName === "KEY_SPACE" || keyName === "KEY_ENTER" || keyName === "KEY_KPENTER");
                    if (data.includes("value 1")) { root.recordKeystroke(keyName); root.onKeyPress(isBigHit); }
                    else if (data.includes("value 0")) { root.onKeyRelease(isBigHit); }
                    else if (data.includes("value 2")) { root.onKeyRepeat(isBigHit); }
                } else if (root.mouseEnabled && (data.includes("POINTER_BUTTON") || data.includes("POINTER_SCROLL"))) {
                    root.handlePointerLine(data);
                } else if (data.includes("KEYBOARD_KEY")) {
                    const keyMatch = data.match(/(KEY_[A-Z0-9_]+)/);
                    const keyName = keyMatch ? keyMatch[1] : "";
                    const isBigHit = root.doubleSlam && (keyName === "KEY_SPACE" || keyName === "KEY_ENTER" || keyName === "KEY_KPENTER");
                    if (data.includes("pressed")) { root.recordKeystroke(keyName); root.onKeyPress(isBigHit); }
                    else if (data.includes("released")) { root.onKeyRelease(isBigHit); }
                    else if (data.includes("repeat")) { root.onKeyRepeat(isBigHit); }
                }
            }
        }

        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) console.warn("[BongoDaemon] evtest failed. Error code:", exitCode);
        }
    }
}
