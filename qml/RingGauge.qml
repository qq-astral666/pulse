import QtQuick
import QtQuick.Shapes

// Circular percentage gauge with the value in the middle.
Item {
    id: root

    property real value: 0           // 0..100
    property color color: Theme.accent
    property real size: 76
    property real thickness: 7
    property string caption: ""

    implicitWidth: size
    implicitHeight: size

    property real shown: value
    Behavior on shown { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    readonly property real radius: (size - thickness) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.track
            strokeWidth: root.thickness
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.radius; radiusY: root.radius
                startAngle: 0; sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.radius; radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * Math.max(0.5, Math.min(100, root.shown)) / 100
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: -2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(root.value) + "%"
            font.pixelSize: Math.round(root.size * 0.24)
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
            color: Theme.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.caption !== ""
            text: root.caption
            font.pixelSize: Math.max(9, Math.round(root.size * 0.12))
            font.weight: Font.DemiBold
            color: Theme.textTertiary
        }
    }
}
