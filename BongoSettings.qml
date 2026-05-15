import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import Quickshell.Io

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
        text: "Click the cat to open settings. Right-click to toggle sleep mode."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: setupColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: setupColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Setup"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Add your user to the 'input' group to detect mouse/keyboard activity:"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { cmd: "sudo usermod -aG input $USER && echo 'Logout and login to apply changes'", label: "Add to input group" }
                    ]

                    delegate: Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            color: Theme.surfaceVariantText
                        }

                        Rectangle {
                            width: parent.width
                            height: Math.max(40, cmdRow.implicitHeight + 16)
                            color: Theme.surfaceContainerHigh
                            radius: 4

                            Row {
                                id: cmdRow
                                width: parent.width - 16
                                anchors.centerIn: parent
                                spacing: 8

                                StyledText {
                                    width: parent.width - 32
                                    text: modelData.cmd
                                    font.family: "Monospace"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondary
                                    wrapMode: Text.Wrap
                                }

                                DankButton {
                                    width: 24
                                    height: 24
                                    iconName: "content_copy"
                                    backgroundColor: "transparent"
                                    textColor: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    onClicked: {
                                        Proc.runCommand("copy-cmd", ["wl-copy", "--", modelData.cmd], function() {
                                            ToastService.showInfo("Copied to clipboard");
                                        });
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                text: "After running the command, logout and login again for changes to take effect."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
                font.italic: true
            }
        }
    StyledRect {
        width: parent.width
        height: hintColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: hintColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Interface"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "showHints"
                label: "Show Hints"
                description: "Display helpful usage tips and shortcuts at the bottom of the popout."
                defaultValue: true
            }
        }
    }
}