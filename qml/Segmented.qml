import QtQuick

Rectangle {
    id: root

    property var options: []
    property int current: 0
    property int fontSize: 12
    signal selected(int index)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: fontSize + 14
    radius: 7
    color: Theme.track

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: segment
                required property int index
                required property string modelData
                readonly property bool active: index === root.current

                width: segmentLabel.implicitWidth + 18
                height: root.height - 4
                radius: 5
                color: active ? Theme.segmentActive : (segmentMouse.containsMouse ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: 110 } }

                Text {
                    id: segmentLabel
                    anchors.centerIn: parent
                    text: segment.modelData
                    font.pixelSize: root.fontSize
                    font.weight: segment.active ? Font.DemiBold : Font.Normal
                    color: segment.active ? Theme.text : Theme.textSecondary
                }

                MouseArea {
                    id: segmentMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(segment.index)
                }
            }
        }
    }
}
