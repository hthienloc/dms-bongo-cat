import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import Quickshell.Io
import "../dms-common"

PluginSettings {
    id: root
    pluginId: "bongoCat"

    PluginHeader {
        title: "Bongo Cat"
        description: "Click the cat to open settings. Right-click to toggle sleep mode."
    }

    SettingsCard {
        SectionTitle { text: "Setup" }

        InfoText {
            text: "Add your user to the 'input' group to detect mouse/keyboard activity:"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { cmd: "sudo usermod -aG input $USER", label: "Add to input group" }
                ]

                delegate: CopyBox {
                    label: modelData.label
                    text: modelData.cmd
                }
            }
        }

        InfoText {
            text: "After running the command, logout and login again for changes to take effect."
            color: Theme.primary
            font.italic: true
        }
    }

    SettingsCard {
        SectionTitle { text: "Interface" }

        ToggleSetting {
            settingKey: "showHints"
            label: "Show Hints"
            description: "Display helpful usage tips and shortcuts at the bottom of the popout."
            defaultValue: true
        }
    }
}