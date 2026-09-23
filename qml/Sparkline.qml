import QtQuick
import QtQuick.Shapes

// Area chart of the latest N samples, newest on the right.
Item {
    id: root

    property var values: []
    property real maxValue: 0        // 0 = auto-scale to the data
    property real minScale: 1        // auto-scale never goes below this
    property int capacity: 90
    property color color: Theme.accent
    property real lineWidth: 1.6
    property bool filled: true

    readonly property real scaleMax: {
        if (maxValue > 0)
            return maxValue
        let m = minScale
        for (let i = 0; i < values.length; ++i)
            m = Math.max(m, values[i])
        return m * 1.15
    }

    readonly property var points: {
        const n = values.length
        if (n < 2 || width <= 0 || height <= 0)
            return []
        const step = width / Math.max(1, Math.max(capacity, n) - 1)
        const usable = height - lineWidth
        const out = []
        for (let i = 0; i < n; ++i) {
            const v = Math.max(0, Math.min(1, values[i] / scaleMax))
            out.push(Qt.point(width - (n - 1 - i) * step, height - lineWidth / 2 - v * usable))
        }
        return out
    }

    readonly property var areaPoints: points.length < 2 ? []
        : points.concat([Qt.point(points[points.length - 1].x, height), Qt.point(points[0].x, height)])

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.points.length > 1

        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: root.height
                GradientStop { position: 0; color: Theme.tint(root.color, root.filled ? 0.30 : 0) }
                GradientStop { position: 1; color: Theme.tint(root.color, 0) }
            }
            PathPolyline { path: root.areaPoints }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.points }
        }
    }
}
