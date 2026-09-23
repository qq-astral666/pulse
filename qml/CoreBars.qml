import QtQuick

// One vertical bar per CPU core, labelled E (efficiency) / P (performance).
Item {
    id: root

    property var values: []
    property var kinds: []
    property color color: Theme.cpu
    property color efficiencyColor: Theme.cpuEfficiency

    implicitHeight: 44

    Row {
        anchors.fill: parent
        spacing: 3

        Repeater {
            model: root.values.length

            delegate: Item {
                id: core
                required property int index
                readonly property real load: root.values[index] ?? 0
                readonly property string kind: root.kinds[index] ?? ""

                width: (root.width - 3 * (root.values.length - 1)) / Math.max(1, root.values.length)
                height: root.height

                Rectangle {
                    id: track
                    anchors.top: parent.top
                    anchors.bottom: label.top
                    anchors.bottomMargin: 3
                    width: parent.width
                    radius: 2
                    color: Theme.track

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        radius: 2
                        height: Math.max(2, parent.height * Math.min(1, core.load / 100))
                        color: core.kind === "E" ? root.efficiencyColor : root.color
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    id: label
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: core.kind
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }
            }
        }
    }
}
