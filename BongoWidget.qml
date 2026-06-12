import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.X11
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins
import "./dms-common"


PluginComponent {
    id: root
    pluginId: "bongoCat"
    pluginService: PluginService

    readonly property bool showHints: pluginData.showHints ?? true


    property int catState: 0
    property bool leftWasLast: false
    property bool isBlinking: false
    property bool isWaiting: true
    property bool forceSleep: false
    onForceSleepChanged: {
        if (forceSleep) isWaiting = true;
    }

    property var deviceOptions: ["All Keyboards (Auto)"]
    property var deviceMap: ({ "All Keyboards (Auto)": "all" })
    readonly property string selectedDevicePath: (pluginData && pluginData.selectedDevicePath !== undefined ? pluginData.selectedDevicePath : "all")

    // Surface silent input-monitor failures (missing CLI tool / missing
    // input group) instead of leaving the cat motionless without a hint.
    property bool inputToolMissing: false
    property bool notInInputGroup: false
    readonly property bool inputBroken: inputToolMissing || notInInputGroup
    readonly property string requiredTool: selectedDevicePath === "all" ? "libinput" : "evtest"

    onRequiredToolChanged: {
        toolCheck.running = false;
        toolCheck.running = true;
        refreshMouseToolCheck();
    }

    Process {
        id: toolCheck
        command: ["sh", "-c", "command -v " + root.requiredTool + " >/dev/null 2>&1"]
        running: true
        onExited: (exitCode, exitStatus) => {
            root.inputToolMissing = (exitCode !== 0);
        }
    }

    // When a specific keyboard is selected, its evtest stream contains no
    // mouse events — those still come from libinput.
    readonly property bool mouseBroken: mouseEnabled && selectedDevicePath !== "all" && mouseToolMissing
    property bool mouseToolMissing: false

    onMouseEnabledChanged: refreshMouseToolCheck()

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
        onExited: (exitCode, exitStatus) => {
            root.mouseToolMissing = (exitCode !== 0);
        }
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
        onExited: (exitCode, exitStatus) => {
            root.notInInputGroup = (exitCode !== 0);
        }
    }
    onSelectedDevicePathChanged: {
        console.log("[BongoCat] Device selection changed to:", selectedDevicePath);
        inputProc.running = false;
        inputRestartTimer.restart();
    }

    Timer {
        id: inputRestartTimer
        interval: 200
        onTriggered: inputProc.running = true
    }

    readonly property string selectedDeviceName: {
        for (let name in deviceMap) {
            if (deviceMap[name] === selectedDevicePath) return name;
        }
        return "All Keyboards (Auto)";
    }

    readonly property real catSize: ((pluginData && pluginData.catSizePercent !== undefined ? pluginData.catSizePercent : 100)) / 100.0
    readonly property int catYOffset: (pluginData && pluginData.catYOffset !== undefined ? pluginData.catYOffset : 0)
    readonly property bool enableBlinking: (pluginData && pluginData.enableBlinking !== undefined ? pluginData.enableBlinking : true)
    readonly property bool mouseEnabled: (pluginData && pluginData.mouseEnabled !== undefined ? pluginData.mouseEnabled : true)

    // --- Mouse interaction (roadmap item) ---
    // Left button holds the left paw down, right button the right paw,
    // any other button slams both. Scrolling drums with alternating paws.
    property bool mouseLeftDown: false
    property bool mouseRightDown: false
    property bool mouseOtherDown: false

    function updateMousePaws() {
        isWaiting = false;
        if ((mouseLeftDown && mouseRightDown) || mouseOtherDown) {
            catState = 3;
        } else if (mouseLeftDown) {
            catState = 1;
        } else if (mouseRightDown) {
            catState = 2;
        } else {
            catState = 0;
        }
        waitingTimer.restart();
    }

    function onMouseButton(buttonName, pressed) {
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
        leftWasLast = !leftWasLast;
        catState = leftWasLast ? 1 : 2;
        scrollReleaseTimer.restart();
        waitingTimer.restart();
    }

    Timer {
        id: scrollReleaseTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (!root.mouseLeftDown && !root.mouseRightDown && !root.mouseOtherDown)
                root.catState = 0;
        }
    }

    function handlePointerLine(data) {
        if (data.includes("POINTER_BUTTON")) {
            const match = data.match(/(BTN_[A-Z0-9_]+)/);
            const name = match ? match[1] : "BTN_OTHER";
            if (data.includes("pressed")) {
                root.onMouseButton(name, true);
            } else if (data.includes("released")) {
                root.onMouseButton(name, false);
            }
        } else if (data.includes("POINTER_SCROLL")) {
            root.onScrollTick();
        }
    }
    readonly property int waitingTimeout: ((pluginData && pluginData.waitingTimeout !== undefined ? pluginData.waitingTimeout : 5)) * 1000

    readonly property int pawHoldTime: (pluginData && pluginData.pawHoldTime !== undefined ? pluginData.pawHoldTime : 0)
    readonly property bool activeColor: (pluginData && pluginData.activeColor !== undefined ? pluginData.activeColor : false)

    function saveSetting(key, value) {
        try {
            pluginService.savePluginData(pluginId, key, value);
            if (pluginData) pluginData[key] = value;
        } catch(e) {
            console.log("[BongoCat] Failed to save setting:", key, e);
        }
    }

    FontLoader {
        id: bongoFont
        source: "./assets/bongocat-Regular.otf"
        onStatusChanged: {
            if (status === FontLoader.Error) {
                console.warn("[BongoCat] Failed to load font");
            }
        }
    }

    readonly property var glyphMap: ["bc", "dc", "ba", "da"]
    readonly property int iconSize: Theme.iconSizeSmall
    readonly property int padding: Theme.spacingS
    readonly property int spacing: Theme.spacingXS
    readonly property string blinkGlyph: "gh"
    readonly property string sleepGlyph: "ef"

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
        // Devices whose lowercase name matches this regex are always included,
        // even if they would otherwise be filtered by the exclude list.
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
            root.deviceOptions = options;
            root.deviceMap = map;
        });
    }

    Component.onCompleted: fetchDevices()

    // Refresh devices when popout is triggered
    function triggerPopoutWithRefresh() {
        fetchDevices();
        root.triggerPopout();
    }

    Process {
        id: inputProc
        command: {
            const cmd = selectedDevicePath === "all" ? ["libinput", "debug-events"] : ["evtest", selectedDevicePath];
            console.log("[BongoCat] Starting input process with command:", JSON.stringify(cmd));
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
                } else if (root.mouseEnabled && (data.includes("POINTER_BUTTON") || data.includes("POINTER_SCROLL"))) {
                    root.handlePointerLine(data);
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
                console.warn("[BongoCat] evtest failed. Error code:", exitCode);
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: catLabel.implicitWidth + Theme.spacingS
            implicitHeight: Theme.iconSize

            MouseArea {
                id: clickArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.forceSleep = !root.forceSleep;
                        console.log("[BongoCat] Right click - forceSleep:", root.forceSleep);
                        if (root.forceSleep) root.isWaiting = true;
                    } else {
                        root.triggerPopoutWithRefresh();
                    }
                }
                onPressAndHold: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.forceSleep = !root.forceSleep;
                        if (root.forceSleep) root.isWaiting = true;
                    }
                }
            }

            Text {
                id: catLabel
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.catYOffset
                font.family: bongoFont.name
                font.pixelSize: 24 * root.catSize
                color: root.forceSleep ? Theme.surfaceVariantText : ((root.activeColor && !root.isWaiting) ? Theme.primary : Theme.surfaceText)
                opacity: root.forceSleep ? 0.5 : 1.0
                text: root.forceSleep ? root.sleepGlyph : (root.isWaiting ? root.sleepGlyph : (root.isBlinking && root.catState === 0 ? root.blinkGlyph : root.glyphMap[root.catState]))
            }

            DankIcon {
                visible: root.inputBroken || root.mouseBroken
                name: "warning"
                size: 11
                color: Theme.error
                anchors.top: parent.top
                anchors.right: parent.right
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 280
    popoutHeight: 450

    popoutContent: Component {
        PopoutComponent {
            id: popout
            width: root.popoutWidth
            headerText: "Bongo Cat"
            showCloseButton: true

            readonly property bool isActive: !root.isWaiting && !root.forceSleep

            Column {
                width: parent.width
                spacing: Theme.spacingL

                Rectangle {
                    width: parent.width
                    visible: root.inputBroken || root.mouseBroken
                    radius: Theme.cornerRadius
                    color: Theme.errorHover
                    implicitHeight: warnCol.implicitHeight + Theme.spacingM * 2

                    Column {
                        id: warnCol
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            visible: root.inputToolMissing
                            text: root.selectedDevicePath === "all"
                                ? I18n.tr("The 'libinput' CLI was not found, so Auto mode can't see your keyboard. Install it (Arch: libinput-tools, Debian/Ubuntu: libinput-tools, Fedora: libinput-utils) or pick a specific keyboard below.")
                                : I18n.tr("'evtest' was not found — install it to monitor a specific keyboard, or switch to Auto mode.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.error
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: parent.width
                            visible: root.notInInputGroup
                            text: I18n.tr("Your user is not in the 'input' group, so keyboard events can't be read. Run: sudo usermod -aG input $USER — then log out and back in.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.error
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: parent.width
                            visible: root.mouseBroken
                            text: I18n.tr("Mouse interaction needs the 'libinput' CLI (Arch/Debian: libinput-tools, Fedora: libinput-utils) — or switch the keyboard to Auto mode.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.error
                            wrapMode: Text.Wrap
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: 140
                    radius: Theme.cornerRadius
                    color: popout.isActive ? Theme.primaryContainer : Theme.surface
                    clip: true
                    
                    // Gradient overlay
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0,0,0, 0.1) }
                        }
                    }

                    // The Big Cat
                    Text {
                        anchors.centerIn: parent
                        font.family: bongoFont.name
                        font.pixelSize: 80
                        font.letterSpacing: -2
                        color: popout.isActive ? Theme.onPrimaryContainer : Theme.surfaceText
                        text: root.forceSleep ? root.sleepGlyph : (!popout.isActive ? root.sleepGlyph : (root.isBlinking && root.catState === 0 ? root.blinkGlyph : root.glyphMap[root.catState]))
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    // Header for settings
                    StyledText {
                        text: "Appearance & Behavior"
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        color: Theme.primary
                        opacity: 0.8
                    }

                    // Keyboard Selection
                    Row {
                        width: parent.width
                        height: 36
                        spacing: Theme.spacingM
                        DankIcon { name: "keyboard"; size: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DankDropdown {
                            id: keyboardDropdown
                            width: parent.width - 40
                            options: root.deviceOptions
                            currentValue: root.selectedDeviceName
                            maxPopupHeight: 200
                            compactMode: true
                            onValueChanged: v => root.saveSetting("selectedDevicePath", root.deviceMap[v])
                        }
                    }

                    // Size Setting
                    Column {
                        width: parent.width
                        spacing: 2

                        StyledText {
                            text: "Cat Size"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            width: parent.width
                            height: 32
                            spacing: Theme.spacingM
                            DankIcon { name: "aspect_ratio"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: sizeSlider
                                width: parent.width - 80
                                value: root.catSize * 100
                                minimum: 50; maximum: 200
                                centerMinimum: false; unit: "%"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("catSizePercent", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"
                                size: 18
                                color: Theme.primary
                                opacity: (root.catSize * 100) !== 100 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: (root.catSize * 100) !== 100
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        root.saveSetting("catSizePercent", 100);
                                        sizeSlider.value = 100;
                                    }
                                }
                            }
                        }
                    }

                    // Sleep Timeout
                    Column {
                        width: parent.width
                        spacing: 2

                        StyledText {
                            text: "Sleep Timeout"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            width: parent.width
                            height: 32
                            spacing: Theme.spacingM
                            DankIcon { name: "bedtime"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: sleepSlider
                                width: parent.width - 80
                                value: root.waitingTimeout / 1000
                                minimum: 1; maximum: 10
                                centerMinimum: false; unit: "s"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("waitingTimeout", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"
                                size: 18
                                color: Theme.primary
                                opacity: (root.waitingTimeout / 1000) !== 5 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: (root.waitingTimeout / 1000) !== 5
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        root.saveSetting("waitingTimeout", 5);
                                        sleepSlider.value = 5;
                                    }
                                }
                            }
                        }
                    }

                    // Vertical Offset
                    Column {
                        width: parent.width
                        spacing: 2

                        StyledText {
                            text: "Vertical Offset"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            width: parent.width
                            height: 32
                            spacing: Theme.spacingM
                            DankIcon { name: "swap_vert"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: offsetSlider
                                width: parent.width - 80
                                value: root.catYOffset
                                minimum: -10; maximum: 10
                                centerMinimum: false; unit: "px"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("catYOffset", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"
                                size: 18
                                color: Theme.primary
                                opacity: root.catYOffset !== 0 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.catYOffset !== 0
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        root.saveSetting("catYOffset", 0);
                                        offsetSlider.value = 0;
                                    }
                                }
                            }
                        }
                    }

                    // Paw Hold Time
                    Column {
                        width: parent.width
                        spacing: 2

                        StyledText {
                            text: "Paw Hold Time"
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Row {
                            width: parent.width
                            height: 32
                            spacing: Theme.spacingM
                            DankIcon { name: "timer"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: pawHoldSlider
                                width: parent.width - 80
                                value: root.pawHoldTime
                                minimum: 0; maximum: 100
                                centerMinimum: false; unit: "ms"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("pawHoldTime", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"
                                size: 18
                                color: Theme.primary
                                opacity: root.pawHoldTime !== 0 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: root.pawHoldTime !== 0
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        root.saveSetting("pawHoldTime", 0);
                                        pawHoldSlider.value = 0;
                                    }
                                }
                            }
                        }
                    }

                    // Quick Toggles
                    Row {
                        width: parent.width
                        height: 40
                        spacing: Theme.spacingL
                        
                        // Blink Toggle
                        Row {
                            spacing: Theme.spacingS
                            DankIcon {
                                name: root.enableBlinking ? "visibility" : "visibility_off"
                                size: 22
                                color: root.enableBlinking ? Theme.primary : Theme.surfaceText
                                opacity: root.enableBlinking ? 1.0 : 0.4
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.saveSetting("enableBlinking", !root.enableBlinking)
                                }
                            }
                            StyledText {
                                text: "Blink"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Color Toggle
                        Row {
                            spacing: Theme.spacingS
                            DankIcon {
                                name: "palette"
                                size: 22
                                color: root.activeColor ? Theme.primary : Theme.surfaceText
                                opacity: root.activeColor ? 1.0 : 0.4
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.saveSetting("activeColor", !root.activeColor)
                                }
                            }
                            StyledText {
                                text: "Active Color"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                HintSection {
                    width: parent.width
                    showHints: root.showHints

                    HintItem {
                        icon: "mouse"
                        text: "Right-click bar icon to toggle sleep mode."
                    }
                }
            }
        }
    }
}
