import QtQuick
import QtQuick.Layouts

// Rounded section with an icon + title header. Children go into a
// ColumnLayout, so they can use Layout.* attached properties.
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property color accent: Theme.accent
    property alias trailing: trailingSlot.data
    default property alias content: body.data

    implicitHeight: column.implicitHeight + 28
    radius: 12
    color: Theme.card
    border.width: 1
    border.color: Theme.cardBorder

    ColumnLayout {
        id: column
        x: 14
        y: 14
        width: root.width - 28
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 6
                color: Theme.tint(root.accent, Theme.dark ? 0.20 : 0.14)
                Icon {
                    anchors.centerIn: parent
                    name: root.icon
                    size: 14
                    color: root.accent
                }
            }

            Text {
                text: root.title
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Item { Layout.fillWidth: true }

            Item {
                id: trailingSlot
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
            }
        }

        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 10
        }
    }
}
