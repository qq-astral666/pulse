import QtQuick

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias control: slot.data

    implicitHeight: Math.max(44, texts.implicitHeight + 16)

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            font.pixelSize: 13
            color: Theme.text
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: Theme.textSecondary
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
