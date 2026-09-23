import QtQuick

// Stacked horizontal bar: [{ value, color }, ...] out of `total`.
Item {
    id: root

    property var segments: []
    property real total: 1
    property real barHeight: 8

    implicitHeight: barHeight

    Rectangle {
        anchors.fill: parent
        radius: root.barHeight / 2
        color: Theme.track
    }

    Row {
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.segments

            delegate: Rectangle {
                required property var modelData
                height: root.barHeight
                radius: root.barHeight / 2
                color: modelData.color
                width: Math.max(0, (root.width - 2 * root.segments.length) * modelData.value / Math.max(1, root.total))
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            }
        }
    }
}
