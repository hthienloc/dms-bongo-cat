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

    readonly property bool showHints: pluginData.showHints ?? true

    readonly property real catSize: ((pluginData && pluginData.catSizePercent !== undefined ? pluginData.catSizePercent : 100)) / 100.0
    readonly property int catYOffset: (pluginData && pluginData.catYOffset !== undefined ? pluginData.catYOffset : 0)
    readonly property bool enableBlinking: (pluginData && pluginData.enableBlinking !== undefined ? pluginData.enableBlinking : true)
    readonly property string selectedDevicePath: (pluginData && pluginData.selectedDevicePath !== undefined ? pluginData.selectedDevicePath : "all")
    readonly property int waitingTimeout: ((pluginData && pluginData.waitingTimeout !== undefined ? pluginData.waitingTimeout : 5)) * 1000
    readonly property int pawHoldTime: (pluginData && pluginData.pawHoldTime !== undefined ? pluginData.pawHoldTime : 0)
    readonly property bool showMetrics: (pluginData && pluginData.showMetrics !== undefined ? pluginData.showMetrics : false)
    readonly property bool metricsInBar: (pluginData && pluginData.metricsInBar !== undefined ? pluginData.metricsInBar : false)
    readonly property bool soundEnabled: (pluginData && pluginData.soundEnabled !== undefined ? pluginData.soundEnabled : false)
    readonly property int soundVolume: (pluginData && pluginData.soundVolume !== undefined ? pluginData.soundVolume : 60)
    readonly property bool soundOnMouse: (pluginData && pluginData.soundOnMouse !== undefined ? pluginData.soundOnMouse : false)
    readonly property string soundProfile: (pluginData && pluginData.soundProfile !== undefined ? pluginData.soundProfile : "bongo")
    readonly property bool mouseEnabled: (pluginData && pluginData.mouseEnabled !== undefined ? pluginData.mouseEnabled : false)

    readonly property string catColorMode: {
        if (pluginData && pluginData.catColorMode !== undefined) return pluginData.catColorMode;
        if (pluginData && pluginData.activeColor === true) return "primary";
        return "classic";
    }
    readonly property string catCustomColor: (pluginData && pluginData.catCustomColor) ? pluginData.catCustomColor : "primary"
    readonly property bool classicIdle: (pluginData && pluginData.classicIdle !== undefined ? pluginData.classicIdle : false)
    readonly property color resolvedCatColor: {
        if (root.classicIdle && globalIsWaiting.value) return Theme.surfaceText;
        if (catColorMode === "primary") return Theme.primary;
        if (catColorMode === "custom") return catCustomColor === "primary" ? Theme.primary : Qt.color(catCustomColor);
        return Theme.surfaceText;
    }
    readonly property bool inputBroken: globalInputBroken.value
    readonly property bool mouseBroken: globalMouseBroken.value

    readonly property var deviceOptions: globalDeviceOptions.value
    readonly property var deviceMap: globalDeviceMap.value

    readonly property var colorModeOptions: [I18n.tr("Classic B/W"), I18n.tr("Theme Primary"), I18n.tr("Custom")]
    function colorModeToLabel(m) {
        if (m === "primary") return I18n.tr("Theme Primary");
        if (m === "custom") return I18n.tr("Custom");
        return I18n.tr("Classic B/W");
    }
    function labelToColorMode(l) {
        if (l === I18n.tr("Theme Primary")) return "primary";
        if (l === I18n.tr("Custom")) return "custom";
        return "classic";
    }

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
            console.warn("[BongoCat] Failed to save setting:", key, e);
        }
    }

    function triggerPopoutWithRefresh() {
        Ipc.call("bongoDaemon.refreshDevices");
        root.triggerPopout();
    }

    FontLoader {
        id: bongoFont
        source: "./assets/bongocat-Regular.otf"
        onStatusChanged: {
            if (status === FontLoader.Error) console.warn("[BongoCat] Failed to load font");
        }
    }

    readonly property var glyphMap: ["bc", "dc", "ba", "da"]
    readonly property int iconSize: Theme.iconSizeSmall
    readonly property int padding: Theme.spacingS
    readonly property int spacing: Theme.spacingXS
    readonly property string blinkGlyph: "gh"
    readonly property string sleepGlyph: "ef"

    horizontalBarPill: Component {
        Item {
            implicitWidth: pillContent.implicitWidth + Theme.spacingS
            implicitHeight: Math.max(Theme.iconSize, pillContent.implicitHeight)

            MouseArea {
                id: clickArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.saveSetting("forceSleep", !globalForceSleep.value);
                        console.log("[BongoCat] Right click - forceSleep:", !globalForceSleep.value);
                    } else {
                        root.triggerPopoutWithRefresh();
                    }
                }
                onPressAndHold: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root.saveSetting("forceSleep", !globalForceSleep.value);
                    }
                }
            }

            Grid {
                id: pillContent
                anchors.centerIn: parent
                columns: root.isVertical ? 1 : 2
                columnSpacing: Theme.spacingXS
                rowSpacing: 0
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                Text {
                    id: catLabel
                    font.family: bongoFont.name
                    font.pixelSize: 24 * root.catSize
                    font.letterSpacing: -(font.pixelSize / 40.0)
                    color: globalForceSleep.value ? Theme.surfaceVariantText : root.resolvedCatColor
                    opacity: globalForceSleep.value ? 0.5 : 1.0
                    text: globalForceSleep.value ? root.sleepGlyph
                        : (globalIsWaiting.value ? root.sleepGlyph
                            : (globalIsBlinking.value && globalCatState.value === 0 ? root.blinkGlyph
                                : root.glyphMap[globalCatState.value]))
                    transform: Translate { y: root.catYOffset }
                }

                StyledText {
                    visible: root.showMetrics && root.metricsInBar
                    text: globalLiveWpm.value + " \u00b7 " + globalCleanPercent.value + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: globalForceSleep.value ? Theme.surfaceVariantText : Theme.surfaceText
                    opacity: globalForceSleep.value ? 0.5 : 1.0
                }
            }

            DankIcon {
                visible: root.inputBroken
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

            readonly property bool isActive: !globalIsWaiting.value && !globalForceSleep.value

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
                            visible: globalInputBroken.value
                            text: I18n.tr("The 'libinput' CLI or 'evtest' was not found. Install the required tools to use Bongo Cat.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.error
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: parent.width
                            visible: root.mouseBroken
                            text: I18n.tr("Mouse interaction needs the 'libinput' CLI \u2014 install it (Arch: libinput-tools, Debian/Ubuntu: libinput-tools, Fedora: libinput-utils) or switch the keyboard to Auto mode.")
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
                    color: (popout.isActive && root.catColorMode === "classic") ? Theme.primaryContainer : Theme.surface
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0,0,0, 0.1) }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        font.family: bongoFont.name
                        font.pixelSize: 80
                        font.letterSpacing: -2
                        color: root.catColorMode === "classic"
                            ? (popout.isActive ? Theme.onPrimaryContainer : Theme.surfaceText)
                            : root.resolvedCatColor
                        text: globalForceSleep.value ? root.sleepGlyph
                            : (!popout.isActive ? root.sleepGlyph
                                : (globalIsBlinking.value && globalCatState.value === 0 ? root.blinkGlyph
                                    : root.glyphMap[globalCatState.value]))
                    }
                }

                Row {
                    width: parent.width
                    visible: root.showMetrics
                    spacing: Theme.spacingM

                    StyledRect {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 64
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            anchors.centerIn: parent; spacing: 0
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: globalLiveWpm.value
                                font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.primary
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "WPM"; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.surfaceVariantText
                            }
                        }
                    }

                    StyledRect {
                        width: (parent.width - Theme.spacingM) / 2
                        height: 64
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            anchors.centerIn: parent; spacing: 0
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: globalCleanPercent.value + "%"
                                font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.primary
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Clean"; font.pixelSize: Theme.fontSizeExtraSmall; color: Theme.surfaceVariantText
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: "Appearance & Behavior"
                        font.pixelSize: Theme.fontSizeSmall; font.bold: true; color: Theme.primary; opacity: 0.8
                    }

                    Row {
                        width: parent.width; height: 36; spacing: Theme.spacingM
                        DankIcon { name: "keyboard"; size: 20; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        DankDropdown {
                            id: keyboardDropdown
                            width: parent.width - 40; options: root.deviceOptions; currentValue: root.selectedDeviceName
                            maxPopupHeight: 200; compactMode: true
                            onValueChanged: v => root.saveSetting("selectedDevicePath", root.deviceMap[v])
                        }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        StyledText {
                            text: "Cat Size"; font.pixelSize: Theme.fontSizeExtraSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText
                        }
                        Row {
                            width: parent.width; height: 32; spacing: Theme.spacingM
                            DankIcon { name: "aspect_ratio"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: sizeSlider
                                width: parent.width - 80; value: root.catSize * 100; minimum: 50; maximum: 200
                                centerMinimum: false; unit: "%"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("catSizePercent", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"; size: 18; color: Theme.primary
                                opacity: (root.catSize * 100) !== 100 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent; enabled: (root.catSize * 100) !== 100
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: { root.saveSetting("catSizePercent", 100); sizeSlider.value = 100; }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        StyledText {
                            text: "Sleep Timeout"; font.pixelSize: Theme.fontSizeExtraSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText
                        }
                        Row {
                            width: parent.width; height: 32; spacing: Theme.spacingM
                            DankIcon { name: "bedtime"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: sleepSlider
                                width: parent.width - 80; value: root.waitingTimeout / 1000; minimum: 1; maximum: 10
                                centerMinimum: false; unit: "s"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("waitingTimeout", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"; size: 18; color: Theme.primary
                                opacity: (root.waitingTimeout / 1000) !== 5 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent; enabled: (root.waitingTimeout / 1000) !== 5
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: { root.saveSetting("waitingTimeout", 5); sleepSlider.value = 5; }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        StyledText {
                            text: "Vertical Offset"; font.pixelSize: Theme.fontSizeExtraSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText
                        }
                        Row {
                            width: parent.width; height: 32; spacing: Theme.spacingM
                            DankIcon { name: "swap_vert"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: offsetSlider
                                width: parent.width - 80; value: root.catYOffset; minimum: -10; maximum: 10
                                centerMinimum: false; unit: "px"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("catYOffset", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"; size: 18; color: Theme.primary
                                opacity: root.catYOffset !== 0 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent; enabled: root.catYOffset !== 0
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: { root.saveSetting("catYOffset", 0); offsetSlider.value = 0; }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        StyledText {
                            text: "Paw Hold Time"; font.pixelSize: Theme.fontSizeExtraSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText
                        }
                        Row {
                            width: parent.width; height: 32; spacing: Theme.spacingM
                            DankIcon { name: "timer"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankSlider {
                                id: pawHoldSlider
                                width: parent.width - 80; value: root.pawHoldTime; minimum: 0; maximum: 100
                                centerMinimum: false; unit: "ms"; showValue: true
                                onSliderValueChanged: v => root.saveSetting("pawHoldTime", v)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            DankIcon {
                                name: "restore"; size: 18; color: Theme.primary
                                opacity: root.pawHoldTime !== 0 ? 1.0 : 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                MouseArea {
                                    anchors.fill: parent; enabled: root.pawHoldTime !== 0
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: { root.saveSetting("pawHoldTime", 0); pawHoldSlider.value = 0; }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: 2
                        StyledText {
                            text: I18n.tr("Cat Color"); font.pixelSize: Theme.fontSizeExtraSmall; font.weight: Font.Medium; color: Theme.surfaceVariantText
                        }
                        Row {
                            width: parent.width; height: 32; spacing: Theme.spacingM
                            DankIcon { name: "palette"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                            DankDropdown {
                                id: colorModeDropdown
                                width: parent.width - 40 - (customSwatch.visible ? 40 + Theme.spacingM : 0)
                                options: root.colorModeOptions; currentValue: root.colorModeToLabel(root.catColorMode)
                                maxPopupHeight: 200; compactMode: true
                                anchors.verticalCenter: parent.verticalCenter
                                onValueChanged: v => root.saveSetting("catColorMode", root.labelToColorMode(v))
                            }
                            Rectangle {
                                id: customSwatch
                                visible: root.catColorMode === "custom"
                                width: 40; height: 28; radius: Theme.cornerRadius
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.catCustomColor === "primary" ? Theme.primary : Qt.color(root.catCustomColor)
                                border.color: Theme.outlineStrong; border.width: 2
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                                            const widget = root;
                                            PopoutService.colorPickerModal.selectedColor = root.catCustomColor === "primary" ? Theme.primary : Qt.color(root.catCustomColor);
                                            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Cat Color");
                                            PopoutService.colorPickerModal.onColorSelectedCallback = function(selectedColor) {
                                                widget.saveSetting("catCustomColor", selectedColor.toString());
                                            };
                                            PopoutService.colorPickerModal.show();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Flow {
                        width: parent.width; spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingS
                            DankIcon {
                                name: root.enableBlinking ? "visibility" : "visibility_off"
                                size: 22; color: root.enableBlinking ? Theme.primary : Theme.surfaceText
                                opacity: root.enableBlinking ? 1.0 : 0.4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveSetting("enableBlinking", !root.enableBlinking) }
                            }
                            StyledText { text: "Blink"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            spacing: Theme.spacingS
                            DankIcon {
                                name: root.soundEnabled ? "volume_up" : "volume_off"
                                size: 22; color: root.soundEnabled ? Theme.primary : Theme.surfaceText
                                opacity: root.soundEnabled ? 1.0 : 0.4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveSetting("soundEnabled", !root.soundEnabled) }
                            }
                            StyledText { text: "Sound"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            spacing: Theme.spacingS
                            DankIcon {
                                name: "speed"; size: 22; color: root.showMetrics ? Theme.primary : Theme.surfaceText
                                opacity: root.showMetrics ? 1.0 : 0.4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveSetting("showMetrics", !root.showMetrics) }
                            }
                            StyledText { text: "Metrics"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                HintSection {
                    width: parent.width; showHints: root.showHints
                    HintItem { icon: "mouse"; text: "Right-click bar icon to toggle sleep mode." }
                }
            }
        }
    }
}
