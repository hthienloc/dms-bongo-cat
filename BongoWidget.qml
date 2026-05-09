import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int catState: 0
    property bool leftWasLast: false
    property bool isBlinking: false
    property bool isWaiting: true
    property bool forceSleep: false

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
    readonly property string blinkGlyph: "gh"
    readonly property string sleepGlyph: "ef"

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

    Timer {
        id: idleTimer
        interval: root.idleTimeout
        onTriggered: catState = 0
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
            implicitWidth: catLabel.implicitWidth + 8
            implicitHeight: 32

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
                color: root.forceSleep ? Theme.surfaceVariantText : ((root.activeColor && !isWaiting) ? Theme.primary : Theme.surfaceText)
                opacity: root.forceSleep ? 0.5 : 1.0
                text: root.forceSleep ? sleepGlyph : (isWaiting ? sleepGlyph : (isBlinking ? blinkGlyph : glyphMap[catState]))
            }
        }
    }

    verticalBarPill: horizontalBarPill

    popoutWidth: 280
    popoutHeight: 320

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: "Bongo Cat"
            detailsText: root.isWaiting ? "Sleeping" : "Typing"
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.topMargin: Theme.spacingM
                anchors.bottomMargin: Theme.spacingM

                Row {
                    width: parent.width
                    height: 40
                    spacing: Theme.spacingS
                    StyledText {
                        text: "Size"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    DankSlider {
                        width: parent.width - 50
                        value: root.catSize * 100
                        minimum: 50; maximum: 200
                        centerMinimum: false; unit: "%"; showValue: true
                        onSliderValueChanged: v => root.saveSetting("catSizePercent", v)
                    }
                }

                Row {
                    width: parent.width
                    height: 40
                    spacing: Theme.spacingS
                    StyledText {
                        text: "Idle"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    DankSlider {
                        width: parent.width - 50
                        value: root.idleTimeout
                        minimum: 100; maximum: 1000
                        centerMinimum: false; unit: "ms"; showValue: true
                        onSliderValueChanged: v => root.saveSetting("idleTimeout", v)
                    }
                }

                Row {
                    width: parent.width
                    height: 40
                    spacing: Theme.spacingS
                    StyledText {
                        text: "Sleep"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        width: 50
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    DankSlider {
                        width: parent.width - 50
                        value: root.waitingTimeout / 1000
                        minimum: 1; maximum: 30
                        centerMinimum: false; unit: "s"; showValue: true
                        onSliderValueChanged: v => root.saveSetting("waitingTimeout", v * 1000)
                    }
                }

                Row {
                    width: parent.width
                    height: 36
                    spacing: Theme.spacingM
                    DankIcon {
                        name: root.enableBlinking ? "check_box" : "check_box_outline_blank"
                        size: 24
                        color: root.enableBlinking ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
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

                Row {
                    width: parent.width
                    height: 36
                    spacing: Theme.spacingM
                    DankIcon {
                        name: root.activeColor ? "check_box" : "check_box_outline_blank"
                        size: 24
                        color: root.activeColor ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveSetting("activeColor", !root.activeColor)
                        }
                    }
                    StyledText {
                        text: "Color"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    text: "Right-click icon to toggle sleep mode"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }
        }
    }
}