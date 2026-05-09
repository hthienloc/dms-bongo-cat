import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "bongoCat"

    StyledText {
        width: parent.width
        text: "Bongo Cat"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledText {
        width: parent.width
        text: "Click the cat to open settings. Right-click to toggle sleep mode. Make sure you are in the 'input' group (run 'sudo usermod -aG input $USER' and reboot)."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}