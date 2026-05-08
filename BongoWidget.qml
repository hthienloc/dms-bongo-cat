import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // --- State ---
    property int catState: 0  // 0: idle, 1: left, 2: right, 3: both
    property bool leftWasLast: false
    property bool isBlinking: false
    property bool isWaiting: true
    
    // --- Settings ---
    readonly property string resolvedDevice: {
        let dev = pluginData.inputDevice || "";
        if (dev === "manual") return pluginData.manualDevicePath || "";
        return dev;
    }
    readonly property real catSize: (pluginData.catSizePercent !== undefined ? pluginData.catSizePercent : 100) / 100.0
    readonly property int idleTimeout: pluginData.idleTimeout || 250
    readonly property bool enableBlinking: pluginData.enableBlinking ?? true

    // --- Font ---
    FontLoader {
        id: bongoFont
        source: "./assets/bongocat-Regular.otf"
    }

    // --- Glyphs ---
    readonly property var glyphMap: ["bc", "dc", "ba", "da"]
    readonly property string blinkGlyph: "gh"
    readonly property string sleepGlyph: "ef"

    // --- Logic ---
    function onKeyPress(isBigHit) {
        isWaiting = false;
        if (isBigHit) {
            catState = 3;
        } else {
            if (catState !== 0) {
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
        if (isBigHit) {
            catState = 0;
        } else {
            catState = (catState === 3) ? (leftWasLast ? 1 : 2) : 0;
        }
    }

    // --- Timers ---
    Timer {
        id: idleTimer
        interval: root.idleTimeout
        onTriggered: catState = 0
    }

    Timer {
        id: waitingTimer
        interval: 5000
        onTriggered: isWaiting = true
    }

    Timer {
        id: blinkIntervalTimer
        interval: 6000 + Math.random() * 8000
        repeat: true
        running: root.enableBlinking && !isWaiting
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

    // --- Input Process ---
    Process {
        id: evtestProc
        command: ["evtest", root.resolvedDevice]
        running: root.resolvedDevice !== ""
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.includes("EV_KEY")) {
                    const isBigHit = data.includes("KEY_SPACE") || data.includes("KEY_ENTER");
                    if (data.includes("value 1")) { // Press
                        root.onKeyPress(isBigHit);
                    } else if (data.includes("value 0")) { // Release
                        root.onKeyRelease(isBigHit);
                    }
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && root.inputDevice !== "") {
                console.warn("[BongoCat] evtest failed. Error code:", exitCode);
            }
        }
    }

    // --- UI ---
    horizontalBarPill: Component {
        Item {
            implicitWidth: catLabel.implicitWidth + 8
            implicitHeight: 32

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerPopout()
            }

            Text {
                id: catLabel
                anchors.centerIn: parent
                font.family: bongoFont.name
                font.pixelSize: 24 * root.catSize
                color: Theme.surfaceText
                text: isWaiting ? sleepGlyph : (isBlinking ? blinkGlyph : glyphMap[catState])
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 300
    popoutHeight: 160

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Bongo Cat"
            detailsText: "Keyboard activity tracker"
            showCloseButton: false

            Column {
                width: parent.width
                spacing: 12

                StyledText {
                    text: root.resolvedDevice ? "Connected to: " + root.resolvedDevice.split("/").pop() : "No device selected"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.isWaiting ? "Sleeping..." : "Typing active!"
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.isWaiting ? Theme.surfaceVariantText : Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
