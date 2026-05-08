import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "bongoCat"

    property var availableDevices: []

    function scanDevices() {
        // Very simple command to avoid any parsing issues
        Proc.runCommand(
            "list-inputs",
            ["sh", "-c", "find /dev/input -maxdepth 2 -name 'event*' 2>/dev/null"],
            (stdout, exitCode) => {
                var opts = [{ label: "Manual Entry...", value: "manual" }];
                var output = stdout.trim();
                if (output !== "") {
                    var lines = output.split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var path = lines[i].trim();
                        if (path === "") continue;
                        opts.push({ label: path.split("/").pop(), value: path });
                    }
                }
                availableDevices = opts;
            },
            0
        );
    }

    Component.onCompleted: scanDevices()

    StyledText {
        width: parent.width
        text: "Bongo Cat Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledRect {
        width: parent.width
        height: settingsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer

        Column {
            id: settingsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "General Settings"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "inputDevice"
                label: "Keyboard Device"
                description: "Select your keyboard device. You may need to be in the 'input' group."
                options: root.availableDevices
                defaultValue: "manual"
            }

            // Manual device path input
            Column {
                width: parent.width
                spacing: 4
                visible: root.loadValue("inputDevice", "manual") === "manual"

                StyledText {
                    text: "Manual Device Path"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }

                DankTextField {
                    width: parent.width
                    placeholderText: "/dev/input/eventX"
                    text: root.loadValue("manualDevicePath", "")
                    onTextChanged: root.saveValue("manualDevicePath", text)
                }
            }

            SliderSetting {
                settingKey: "catSizePercent"
                label: "Cat Size"
                description: "Scale of the Bongo Cat."
                minimum: 50
                maximum: 200
                unit: "%"
                defaultValue: 100
            }

            SliderSetting {
                settingKey: "idleTimeout"
                label: "Idle Timeout"
                description: "Time (ms) to return to idle state after typing."
                minimum: 100
                maximum: 1000
                unit: "ms"
                defaultValue: 250
            }

            ToggleSetting {
                settingKey: "enableBlinking"
                label: "Enable Blinking"
                description: "Make the cat blink occasionally."
                defaultValue: true
            }
        }
    }
    
    StyledText {
        width: parent.width
        text: "Note: You must be in the 'input' group and REBOOT to read keyboard events. Run 'sudo usermod -aG input $USER' and reboot."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }
}
