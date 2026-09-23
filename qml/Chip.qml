import QtQuick

Rectangle {
    id: root

    property string text: ""
    property color tone: Theme.accent

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 20
    radius: 10
    color: Theme.tint(tone, Theme.dark ? 0.20 : 0.13)

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: root.tone
    }
}
