import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root
    pluginId: "bongoCat"

    minWidth: 80
    minHeight: 80

    // Global variables from daemon
    PluginGlobalVar { id: globalCatState; varName: "catState"; defaultValue: 0 }
    PluginGlobalVar { id: globalIsWaiting; varName: "isWaiting"; defaultValue: true }
    PluginGlobalVar { id: globalIsBlinking; varName: "isBlinking"; defaultValue: false }
    PluginGlobalVar { id: globalForceSleep; varName: "forceSleep"; defaultValue: false }

    readonly property real catSize: ((pluginData && pluginData.catSizePercent !== undefined ? pluginData.catSizePercent : 100)) / 100.0
    readonly property int catYOffset: (pluginData && pluginData.catYOffset !== undefined ? pluginData.catYOffset : 0)
    readonly property bool activeColor: (pluginData && pluginData.activeColor !== undefined ? pluginData.activeColor : false)

    FontLoader {
        id: bongoFont
        source: "./assets/bongocat-Regular.otf"
    }

    readonly property var glyphMap: ["bc", "dc", "ba", "da"]
    readonly property string blinkGlyph: "gh"
    readonly property string sleepGlyph: "ef"

    Text {
        id: catLabel
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.catYOffset * (Math.min(parent.width, parent.height) / 80.0)
        font.family: bongoFont.name
        font.pixelSize: Math.min(parent.width, parent.height) * root.catSize * 0.8
        font.letterSpacing: - (font.pixelSize / 40.0)
        color: globalForceSleep.value ? Theme.surfaceVariantText : ((root.activeColor && !globalIsWaiting.value) ? Theme.primary : Theme.surfaceText)
        opacity: globalForceSleep.value ? 0.5 : 1.0
        text: globalForceSleep.value ? root.sleepGlyph : (globalIsWaiting.value ? root.sleepGlyph : (globalIsBlinking.value && globalCatState.value === 0 ? root.blinkGlyph : root.glyphMap[globalCatState.value]))
    }
}
