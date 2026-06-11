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

    // Global variables from daemon
    PluginGlobalVar { id: globalCatState; varName: "catState"; defaultValue: 0 }
    PluginGlobalVar { id: globalIsWaiting; varName: "isWaiting"; defaultValue: true }
    PluginGlobalVar { id: globalIsBlinking; varName: "isBlinking"; defaultValue: false }
    PluginGlobalVar { id: globalForceSleep; varName: "forceSleep"; defaultValue: false }
    PluginGlobalVar { id: globalDeviceOptions; varName: "deviceOptions"; defaultValue: ["All Keyboards (Auto)"] }
    PluginGlobalVar { id: globalDeviceMap; varName: "deviceMap"; defaultValue: ({ "All Keyboards (Auto)": "all" }) }

    readonly property bool showHints: pluginData.showHints ?? true

    readonly property real catSize: ((pluginData && pluginData.catSizePercentBar !== undefined ? pluginData.catSizePercentBar : 100)) / 100.0
    readonly property int catYOffset: (pluginData && pluginData.catYOffsetBar !== undefined ? pluginData.catYOffsetBar : 0)
    readonly property bool activeColor: (pluginData && pluginData.activeColorBar !== undefined ? pluginData.activeColorBar : false)
    readonly property bool enableBlinking: (pluginData && pluginData.enableBlinking !== undefined ? pluginData.enableBlinking : true)
    readonly property string selectedDevicePath: (pluginData && pluginData.selectedDevicePath !== undefined ? pluginData.selectedDevicePath : "all")
    readonly property int waitingTimeout: ((pluginData && pluginData.waitingTimeout !== undefined ? pluginData.waitingTimeout : 5)) * 1000
    readonly property int pawHoldTime: (pluginData && pluginData.pawHoldTime !== undefined ? pluginData.pawHoldTime : 0)

    readonly property var deviceOptions: globalDeviceOptions.value
    readonly property var deviceMap: globalDeviceMap.value

    readonly property string selectedDeviceName: {
        for (let name in deviceMap) {
            if (deviceMap[name] === selectedDevicePath) return name;
        }
        return "All Keyboards (Auto)";
    }

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

    // Refresh devices when popout is triggered via daemon IPC
    function triggerPopoutWithRefresh() {
        // Open popout immediately to avoid lag
        root.triggerPopout();
        // Refresh devices asynchronously
        Qt.callLater(() => {
            Ipc.call("bongoDaemon.refreshDevices");
        });
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
                        const nextSleep = !globalForceSleep.value;
                        root.saveSetting("forceSleep", nextSleep);
                        console.log("[BongoCat] Right click - forceSleep:", nextSleep);
                    } else {
                        root.triggerPopoutWithRefresh();
                    }
                }
                onPressAndHold: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        const nextSleep = !globalForceSleep.value;
                        root.saveSetting("forceSleep", nextSleep);
                    }
                }
            }

            Text {
                id: catLabel
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.catYOffset
                font.family: bongoFont.name
                font.pixelSize: 24 * root.catSize
                font.letterSpacing: - (font.pixelSize / 40.0)
                color: globalForceSleep.value ? Theme.surfaceVariantText : ((root.activeColor && !globalIsWaiting.value) ? Theme.primary : Theme.surfaceText)
                opacity: globalForceSleep.value ? 0.5 : 1.0
                text: globalForceSleep.value ? root.sleepGlyph : (globalIsWaiting.value ? root.sleepGlyph : (globalIsBlinking.value && globalCatState.value === 0 ? root.blinkGlyph : root.glyphMap[globalCatState.value]))
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

            readonly property bool isActive: !globalIsWaiting.value && !globalForceSleep.value

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
                        text: globalForceSleep.value ? root.sleepGlyph : (!popout.isActive ? root.sleepGlyph : (globalIsBlinking.value && globalCatState.value === 0 ? root.blinkGlyph : root.glyphMap[globalCatState.value]))
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
                            text: "Cat Size (Bar)"
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
                                onSliderValueChanged: v => root.saveSetting("catSizePercentBar", v)
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
                                        root.saveSetting("catSizePercentBar", 100);
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
                            text: "Vertical Offset (Bar)"
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
                                onSliderValueChanged: v => root.saveSetting("catYOffsetBar", v)
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
                                        root.saveSetting("catYOffsetBar", 0);
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
                                    onClicked: root.saveSetting("activeColorBar", !root.activeColor)
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
