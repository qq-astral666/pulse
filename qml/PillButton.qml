import QtQuick

Rectangle {
    id: root

    property alias text: label.text
    property string icon: ""
    property color tone: Theme.text
    signal clicked()

    implicitWidth: content.implicitWidth + 22
    implicitHeight: 28
    radius: 8
    color: mouse.containsMouse ? Theme.hover : Theme.card
    border.width: 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 13
            color: root.tone
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            font.weight: Font.Medium
            color: root.tone
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
