import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    minWidth: 80
    minHeight: 80
    widgetWidth: 160
    widgetHeight: 160

    PluginGlobalVar { id: globalCatState; varName: "catState"; defaultValue: 0 }
    PluginGlobalVar { id: globalIsWaiting; varName: "isWaiting"; defaultValue: true }
    PluginGlobalVar { id: globalIsBlinking; varName: "isBlinking"; defaultValue: false }
    PluginGlobalVar { id: globalForceSleep; varName: "forceSleep"; defaultValue: false }

    readonly property real catSize: ((pluginData && pluginData.catSizePercent !== undefined ? pluginData.catSizePercent : 100)) / 100.0
    readonly property int catYOffset: (pluginData && pluginData.catYOffset !== undefined ? pluginData.catYOffset : 0)
    readonly property bool classicIdle: (pluginData && pluginData.classicIdle !== undefined ? pluginData.classicIdle : false)
    readonly property string catColorMode: {
        if (pluginData && pluginData.catColorMode !== undefined) return pluginData.catColorMode;
        if (pluginData && pluginData.activeColor === true) return "primary";
        return "classic";
    }
    readonly property string catCustomColor: (pluginData && pluginData.catCustomColor) ? pluginData.catCustomColor : "primary"
    readonly property color resolvedCatColor: {
        if (root.classicIdle && globalIsWaiting.value) return Theme.surfaceText;
        if (catColorMode === "primary") return Theme.primary;
        if (catColorMode === "custom") return catCustomColor === "primary" ? Theme.primary : Qt.color(catCustomColor);
        return Theme.surfaceText;
    }

    readonly property real desktopOpacity: (pluginData && pluginData.desktop_opacity !== undefined ? pluginData.desktop_opacity : 85) / 100.0
    readonly property string desktopSkin: (pluginData && pluginData.desktop_skin !== undefined ? pluginData.desktop_skin : "classic")

    FontLoader {
        id: bongoFont
        source: "./assets/bongocat-Regular.otf"
        onStatusChanged: {
            if (status === FontLoader.Error) console.warn("[BongoDesktop] Failed to load font");
        }
    }

    readonly property var glyphMap: ["bc", "dc", "ba", "da"]
    readonly property string blinkGlyph: "gh"
    readonly property string sleepGlyph: "ef"

    readonly property string _catGlyph: globalForceSleep.value ? root.sleepGlyph
        : (globalIsWaiting.value ? root.sleepGlyph
            : (globalIsBlinking.value && globalCatState.value === 0 ? root.blinkGlyph
                : root.glyphMap[globalCatState.value]))

    readonly property string _catStateName: globalForceSleep.value ? "sleep"
        : (globalIsWaiting.value ? "sleep"
            : (globalIsBlinking.value && globalCatState.value === 0 ? "blink"
                : ["idle", "left", "right", "both"][globalCatState.value]))

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: root.desktopOpacity
        border.color: root.editMode ? Theme.primary : "transparent"
        border.width: root.editMode ? 2 : 0

        Item {
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            Text {
                id: catLabel
                visible: root.desktopSkin === "classic"
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.catYOffset * (Math.min(parent.width, parent.height) / 80.0)
                font.family: bongoFont.name
                font.pixelSize: Math.min(parent.width, parent.height) * root.catSize * 0.8
                font.letterSpacing: -(font.pixelSize / 40.0)
                color: globalForceSleep.value ? Theme.surfaceVariantText : root.resolvedCatColor
                opacity: globalForceSleep.value ? 0.5 : 1.0
                text: root._catGlyph
            }

            Image {
                id: catImage
                visible: root.desktopSkin === "assets"
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * root.catSize * 0.8
                height: width
                fillMode: Image.PreserveAspectFit
                source: root._catStateName ? "assets/skin/" + root._catStateName + ".png" : ""
            }

            Text {
                visible: root.desktopSkin === "assets" && catImage.status === Image.Error
                anchors.centerIn: parent
                text: "?"
                font.pixelSize: 20
                color: Theme.surfaceText
            }
        }
    }
}
