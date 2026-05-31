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
        id: appearanceSection
        SectionTitle { 
            text: I18n.tr("Appearance")
            icon: "palette" 
            showReset: catSizePercent.isDirty || activeColor.isDirty || enableBlinking.isDirty
            onResetClicked: {
                catSizePercent.resetToDefault();
                activeColor.resetToDefault();
                enableBlinking.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: catSizePercent
            settingKey: "catSizePercent"
            label: I18n.tr("Cat Size")
            defaultValue: 100
            minimum: 50
            maximum: 200
            unit: "%"
            leftLabel: "50%"
            rightLabel: "200%"
        }

        Separator {}

        ToggleSettingPlus {
            id: activeColor
            settingKey: "activeColor"
            label: I18n.tr("Use Primary Color")
            description: I18n.tr("Apply the system primary color to the cat instead of classic black and white.")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: enableBlinking
            settingKey: "enableBlinking"
            label: I18n.tr("Enable Blinking")
            defaultValue: true
        }
    }

    SettingsCard {
        id: inputSection
        SectionTitle { 
            text: I18n.tr("Input & Behavior")
            icon: "keyboard" 
            showReset: waitingTimeout.isDirty || pawHoldTime.isDirty
            onResetClicked: {
                waitingTimeout.resetToDefault();
                pawHoldTime.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: waitingTimeout
            settingKey: "waitingTimeout"
            label: I18n.tr("Sleep Timeout")
            description: I18n.tr("Inactivity time before the cat falls asleep.")
            minimum: 1
            maximum: 10
            unit: "s"
            defaultValue: 5
            leftLabel: "1s"
            rightLabel: "10s"
        }

        Separator {}

        SliderSettingPlus {
            id: pawHoldTime
            settingKey: "pawHoldTime"
            label: I18n.tr("Paw Hold Duration")
            description: I18n.tr("How long the paws stay down after a key press (0 for instant).")
            minimum: 0
            maximum: 100
            unit: "ms"
            defaultValue: 0
            leftLabel: "0ms"
            rightLabel: "100ms"
        }
    }

    SettingsCard {
        SectionTitle { text: I18n.tr("Setup"); icon: "build" }

        InfoText {
            text: I18n.tr("Add your user to the 'input' group to detect keyboard activity:")
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
        id: behaviorSection
        SectionTitle { 
            text: I18n.tr("Behavior")
            icon: "settings" 
            showReset: showHints.isDirty
            onResetClicked: {
                showHints.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: showHints
            settingKey: "showHints"
            label: I18n.tr("Show Hints")
            defaultValue: true
        }
    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("<b>Left-click</b> the cat to open the settings popout."),
                I18n.tr("<b>Right-click</b> the cat to manually toggle <b>Sleep Mode</b>."),
                I18n.tr("The cat will automatically tap its paws as you type.")
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-bongo-cat"
    }
}
