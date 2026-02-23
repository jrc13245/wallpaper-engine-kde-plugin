import QtQuick 2.5
import QtQuick.Layouts 1.2

Item {
    id: infoItem
    anchors.fill: parent
    property string info: "error"
    property string type: "unknown"
    property string wid: "unknown"
    property string source

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.75
            spacing: 12

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "⚠ Wallpaper Failed to Load"
                color: "#f0a500"
                font.pointSize: 18
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#444"
            }

            Text {
                Layout.fillWidth: true
                text: [
                    `Workshop ID: ${infoItem.wid || "N/A"}`,
                    `Type: ${infoItem.type || "unknown"}`,
                    ``,
                    `Error: ${infoItem.info}`
                ].join("\n")
                color: "#cccccc"
                wrapMode: Text.Wrap
                font.pointSize: 11
                font.family: "monospace"
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#444"
            }

            Text {
                Layout.fillWidth: true
                text: infoItem.type === "scene"
                    ? "Scene wallpapers require Vulkan 1.1+ and the compiled plugin library.\n\nIf KDE crashed previously, run:\n  kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Wallpaper --key WallpaperSource ''\n  systemctl --user restart plasma-plasmashell.service"
                    : "Check the plugin requirements in the About tab."
                color: "#aaaaaa"
                wrapMode: Text.Wrap
                font.pointSize: 9
            }
        }
    }

    Component.onCompleted:{
        background.nowBackend = "InfoShow";
    }

    function play(){}
    function pause(){}
    function getMouseTarget() {}
}
