import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"


PluginComponent {
    id: root
    readonly property bool showHints: pluginData.showHints ?? true


    property int catState: 0
    property bool leftWasLast: false
    property bool isBlinking: false
    property bool isWaiting: true
    property bool forceSleep: false

    property var deviceOptions: ["All Keyboards (Auto)"]
    property var deviceMap: ({ "All Keyboards (Auto)": "all" })
    readonly property string selectedDevicePath: pluginData?.selectedDevicePath ?? "all"
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

    readonly property real catSize: (pluginData?.catSizePercent ?? 100) / 100.0
    readonly property int catYOffset: pluginData?.catYOffset ?? 0
    readonly property bool enableBlinking: pluginData?.enableBlinking ?? true
    readonly property int waitingTimeout: pluginData?.waitingTimeout ?? 5000
    readonly property int pawHoldTime: pluginData?.pawHoldTime ?? 0
    readonly property bool activeColor: pluginData?.activeColor ?? false

    function saveSetting(key, value) {
        try {
            pluginService?.savePluginData(pluginId, key, value);
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
        const cmd = "cat /proc/bus/input/devices | awk '/^N: Name=/ { n=$0; sub(/^N: Name=/, \"\", n); sub(/^\"/, \"\", n); sub(/\"$/, \"\", n); } /^H: Handlers=/ { nl=tolower(n); if ($0 ~ /kbd/ && $0 !~ /mouse/ && nl !~ /power button|video bus|speaker|headphone|lid switch|touchpad|extra buttons|uinput|server|hitune|inphic|instant/) { for(i=1;i<=NF;i++) if($i ~ /event/) { print n \"|\" \"/dev/input/\" $i; next } } }'";
        
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