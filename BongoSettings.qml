import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import Quickshell.Io
import "./dms-common"

PluginSettings {
    id: root
    pluginId: "bongoCat"

    SettingsCard {
        SectionTitle { text: I18n.tr("Usage Guide"); icon: "menu_book" }
        UsageGuide {
            items: [
                I18n.tr("Click the cat to open settings."),
                I18n.tr("Right-click to toggle sleep mode.")
            ]
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Setup"); icon: "build" }

        InfoText {
            text: I18n.tr("Add your user to the 'input' group to detect mouse/keyboard activity:")
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { cmd: "sudo usermod -aG input $USER", label: I18n.tr("Add to input group") }
                ]

                delegate: CopyBox {
                    label: modelData.label
                    text: modelData.cmd
                }
            }
        }

        InfoText {
            text: I18n.tr("After running the command, logout and login again for changes to take effect.")
            color: Theme.primary
            font.italic: true
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Interface"); icon: "display_settings" }

        ToggleSetting {
            settingKey: "showHints"
            label: I18n.tr("Show Hints")
            description: I18n.tr("Display helpful usage tips and shortcuts at the bottom of the popout.")
            defaultValue: true
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-bongo-cat"
    }
}