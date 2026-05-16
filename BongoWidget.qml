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
    property int pressedKeysCount: 0

    readonly property string keyboardDevice: "/dev/input/event3"
    readonly property real catSize: (pluginData?.catSizePercent ?? 100) / 100.0
    readonly property int idleTimeout: pluginData?.idleTimeout ?? 250
    readonly property bool enableBlinking: pluginData?.enableBlinking ?? true
    readonly property int waitingTimeout: pluginData?.waitingTimeout ?? 5000
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

    function onKeyPress(isBigHit, isRepeat = false) {
        isWaiting = false;
        
        if (!isRepeat) {
            pressedKeysCount++;
            if (isBigHit) {
                catState = 3;
            } else {
                leftWasLast = !leftWasLast;
                catState = leftWasLast ? 1 : 2;
            }
        }

        idleTimer.restart();
        waitingTimer.restart();
    }

    function onKeyRelease(isBigHit) {
        pressedKeysCount = Math.max(0, pressedKeysCount - 1);
        
        if (pressedKeysCount === 0) {
            catState = 0;
            idleTimer.restart();
        }
    }

    Timer {
        id: idleTimer
        interval: root.idleTimeout
        onTriggered: {
            catState = 0;
            pressedKeysCount = 0; // Watchdog: reset count if idle
        }
    }

    Timer {
        id: waitingTimer
        interval: root.waitingTimeout
        onTriggered: isWaiting = true
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

    Process {
        id: evtestProc
        command: ["evtest", root.keyboardDevice]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.includes("EV_KEY")) {
                    const isBigHit = data.includes("KEY_SPACE") || data.includes("KEY_ENTER");
                    if (data.includes("value 1")) {
                        root.onKeyPress(isBigHit);
                    } else if (data.includes("value 0")) {
                        root.onKeyRelease(isBigHit);
                    } else if (data.includes("value 2")) {
                        root.onKeyPress(isBigHit, true);
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
                        root.triggerPopout();
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
                font.family: bongoFont.name
                font.pixelSize: 24 * root.catSize
                color: root.forceSleep ? Theme.surfaceVariantText : ((root.activeColor && !root.isWaiting) ? Theme.primary : Theme.surfaceText)
                opacity: root.forceSleep ? 0.5 : 1.0
                text: root.forceSleep ? root.sleepGlyph : (root.isWaiting ? root.sleepGlyph : (root.isBlinking ? root.blinkGlyph : root.glyphMap[root.catState]))
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 280
    popoutHeight: 320

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
                        text: root.forceSleep ? root.sleepGlyph : (!popout.isActive ? root.sleepGlyph : (root.isBlinking ? root.blinkGlyph : root.glyphMap[root.catState]))
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

                    // Size Setting
                    Row {
                        width: parent.width
                        height: 48
                        spacing: Theme.spacingM
                        DankIcon { name: "aspect_ratio"; size: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
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

                    // Idle Timeout
                    Row {
                        width: parent.width
                        height: 48
                        spacing: Theme.spacingM
                        DankIcon { name: "timer"; size: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DankSlider {
                            id: timeoutSlider
                            width: parent.width - 80
                            value: root.idleTimeout
                            minimum: 100; maximum: 1000
                            centerMinimum: false; unit: "ms"; showValue: true
                            onSliderValueChanged: v => root.saveSetting("idleTimeout", v)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        DankIcon {
                            name: "restore"
                            size: 18
                            color: Theme.primary
                            opacity: root.idleTimeout !== 250 ? 1.0 : 0.3
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                enabled: root.idleTimeout !== 250
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    root.saveSetting("idleTimeout", 250);
                                    timeoutSlider.value = 250;
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