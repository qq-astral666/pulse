import QtQuick
import QtQuick.Shapes

// Stroke icons from SVG path data on a 24×24 grid — no image assets.
Item {
    id: root

    property string name: ""
    property color color: "white"
    property real size: 16
    property real strokeWidth: 1.9

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    readonly property var paths: ({
        "cpu": "M8 5h8a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3H8a3 3 0 0 1 -3 -3V8a3 3 0 0 1 3 -3z M10 10h4v4h-4z M9 2v3 M15 2v3 M9 19v3 M15 19v3 M2 9h3 M2 15h3 M19 9h3 M19 15h3",
        "memory": "M3 7h18v10H3z M7 7v10 M11 7v10 M15 7v10 M19 7v10 M6 17v3 M18 17v3",
        "network": "M7 20V4 M3 8l4 -4l4 4 M17 4v16 M13 16l4 4l4 -4",
        "gpu": "M3 6h18v12H3z M6.5 12a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0 M15 10h3 M15 14h3",
        "disk": "M4 6c0 -1.7 3.6 -3 8 -3s8 1.3 8 3v12c0 1.7 -3.6 3 -8 3s-8 -1.3 -8 -3z M4 6c0 1.7 3.6 3 8 3s8 -1.3 8 -3 M4 12c0 1.7 3.6 3 8 3s8 -1.3 8 -3",
        "battery": "M4 7h13a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2H4a2 2 0 0 1 -2 -2V9a2 2 0 0 1 2 -2z M22 11v2",
        "bolt": "M13 2L4 14h7l-1 8l9 -12h-7z",
        "list": "M9 6h11 M9 12h11 M9 18h11 M4.5 6h0.01 M4.5 12h0.01 M4.5 18h0.01",
        "settings": "M4 6h9 M17 6h3 M4 12h3 M11 12h9 M4 18h11 M19 18h1 M15 4v4 M9 10v4 M17 16v4",
        "back": "M15 18l-6 -6l6 -6",
        "pulse": "M3 12h4l2 -6l4 12l2 -6h6",
        "thermo": "M10 14.8V5a2 2 0 1 1 4 0v9.8a4 4 0 1 1 -4 0z",
        "external": "M15 3h6v6 M10 14L21 3 M18 13v6a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V8a2 2 0 0 1 2 -2h6",
        "power": "M12 3v9 M6.3 7.3a8 8 0 1 0 11.4 0",
        "app": "M5 5h6v6H5z M13 5h6v6h-6z M5 13h6v6H5z M13 13h6v6h-6z"
    })

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.paths[root.name] ?? "" }
        }
    }
}
