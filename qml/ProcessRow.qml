import QtQuick
import QtQuick.Layouts

// Process line with its app icon and a background bar showing its share.
Item {
    id: root

    property int pid: 0
    property string name: ""
    property string valueText: ""
    property real fraction: 0        // 0..1
    property bool hasIcon: false
    property color barColor: Theme.accent

    implicitHeight: 30

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0, parent.width * Math.min(1, root.fraction))
        radius: 7
        color: Theme.tint(root.barColor, Theme.dark ? 0.16 : 0.11)
        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 9

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18

            Image {
                anchors.fill: parent
                visible: root.hasIcon
                source: root.hasIcon ? "image://proc/" + root.pid : ""
                sourceSize.width: 36
                sourceSize.height: 36
                asynchronous: true
                smooth: true
            }
            Rectangle {
                anchors.fill: parent
                visible: !root.hasIcon
                radius: 5
                color: Theme.track
                Icon {
                    anchors.centerIn: parent
                    name: "app"
                    size: 11
                    color: Theme.textTertiary
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.name
            elide: Text.ElideRight
            font.pixelSize: 12
            color: Theme.text
        }

        Text {
            text: root.valueText
            font.pixelSize: 12
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
            color: Theme.textSecondary
        }
    }
}
