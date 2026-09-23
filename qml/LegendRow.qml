import QtQuick
import QtQuick.Layouts

// "● Label ........ value"
RowLayout {
    id: root

    property color dot: "transparent"
    property string label: ""
    property string value: ""

    spacing: 7

    Rectangle {
        Layout.preferredWidth: 7
        Layout.preferredHeight: 7
        radius: 3.5
        color: root.dot
        visible: root.dot.a > 0
    }

    Text {
        Layout.fillWidth: true
        text: root.label
        elide: Text.ElideRight
        font.pixelSize: 12
        color: Theme.textSecondary
    }

    Text {
        text: root.value
        font.pixelSize: 12
        font.weight: Font.Medium
        font.features: ({ "tnum": 1 })
        color: Theme.text
    }
}
