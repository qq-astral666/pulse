import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Pulse

// Popover that drops down from the menu-bar item.
Window {
    id: win

    required property AppController controller
    readonly property SystemMonitor mon: controller.monitor

    readonly property int margin: 20          // room for the shadow
    readonly property int panelWidth: 392
    property int maxPanelHeight: 760
    property bool settingsOpen: false
    property bool hadFocus: false
    property double lastDismiss: 0

    width: panelWidth + margin * 2
    height: panel.height + margin * 2
    visible: false
    color: "transparent"
    title: "Pulse"
    flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint | Qt.NoDropShadowWindowHint

    Binding { target: Theme; property: "mode"; value: win.controller.themeMode }

    // ------------------------------------------------------------ lifecycle

    function present() {
        const a = controller.anchorRect()
        const g = controller.availableGeometryAt(a.x + a.width / 2, a.y + a.height + 10)
        maxPanelHeight = Math.max(360, g.height - 16)

        let px = Math.round(a.x + a.width / 2 - width / 2)
        px = Math.max(g.x - margin + 6, Math.min(px, g.x + g.width - width + margin - 6))
        x = px
        y = Math.round(Math.max(g.y, a.y + a.height) + 6 - margin)

        settingsOpen = false
        flick.contentY = 0
        hadFocus = false
        visible = true
        controller.bringToFront(win)
        requestActivate()
        panel.forceActiveFocus()
        appear.restart()
    }

    function dismiss() {
        if (!visible)
            return
        visible = false
        lastDismiss = Date.now()
    }

    // A click on the status item first steals focus (closing the popup) and
    // then arrives as "toggle" — don't reopen in that case.
    function toggle() {
        if (visible)
            dismiss()
        else if (Date.now() - lastDismiss > 350)
            present()
    }

    onVisibleChanged: mon.detailed = visible
    onActiveChanged: {
        if (active)
            hadFocus = true
        else if (visible && hadFocus)
            dismiss()
    }

    Connections {
        target: win.controller
        function onTogglePopup() { win.toggle() }
        function onShowPopup() { win.present() }
        function onToast(message) { toast.show(message) }
    }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "y"; from: win.margin - 8; to: win.margin; duration: 180; easing.type: Easing.OutCubic }
    }

    RectangularShadow {
        anchors.fill: panel
        opacity: panel.opacity
        radius: panel.radius
        blur: 30
        offset: Qt.vector2d(0, 10)
        color: Qt.rgba(0, 0, 0, Theme.dark ? 0.55 : 0.20)
    }

    // --------------------------------------------------------------- panel

    Rectangle {
        id: panel

        x: win.margin
        y: win.margin
        width: win.panelWidth
        height: Math.min(header.height + flick.contentHeight + 12, win.maxPanelHeight)
        radius: 16
        color: Theme.panel
        border.width: 1
        border.color: Theme.panelBorder
        clip: true

        Keys.onEscapePressed: {
            if (win.settingsOpen)
                win.settingsOpen = false
            else
                win.dismiss()
        }

        Item {
            id: header
            width: parent.width
            height: 56

            Rectangle {
                id: logo
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 8
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: "#9b8cff" }
                    GradientStop { position: 1; color: "#5b45e0" }
                }
                Icon { anchors.centerIn: parent; name: "pulse"; size: 18; color: "white"; strokeWidth: 2.3 }
            }

            Column {
                anchors.left: logo.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: win.settingsOpen ? "Настройки" : "Pulse"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Theme.text
                }
                Text {
                    text: win.mon.uptime > 0 ? "Мак работает " + win.mon.formatDuration(win.mon.uptime) : "Системный монитор"
                    font.pixelSize: 11
                    color: Theme.textTertiary
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.mon.thermalState >= 1 && !win.settingsOpen
                    text: win.mon.thermalState >= 3 ? "Перегрев!" : win.mon.thermalState === 2 ? "Горячо" : "Тепло"
                    tone: win.mon.thermalState >= 2 ? Theme.danger : Theme.warning
                }

                Repeater {
                    model: win.settingsOpen ? ["back"] : ["external", "settings"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 30
                        height: 30
                        radius: 8
                        color: buttonMouse.containsMouse ? Theme.hover : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            name: parent.modelData
                            size: 16
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: buttonMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.modelData === "external") {
                                    win.controller.openActivityMonitor()
                                    win.dismiss()
                                } else {
                                    win.settingsOpen = !win.settingsOpen
                                    flick.contentY = 0
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.divider
            }
        }

        Flickable {
            id: flick
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: (win.settingsOpen ? settingsView.implicitHeight : dashboard.implicitHeight) + 24
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Dashboard {
                id: dashboard
                x: 12
                y: 12
                width: flick.width - 24
                visible: !win.settingsOpen
                mon: win.mon
            }

            SettingsView {
                id: settingsView
                x: 12
                y: 12
                width: flick.width - 24
                visible: win.settingsOpen
                controller: win.controller
            }
        }

        // Thin scroll indicator.
        Rectangle {
            visible: flick.contentHeight > flick.height
            anchors.right: parent.right
            anchors.rightMargin: 3
            y: flick.y + (flick.height - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
            width: 4
            height: Math.max(30, flick.height * flick.height / Math.max(1, flick.contentHeight))
            radius: 2
            color: Theme.textTertiary
            opacity: flick.moving ? 0.8 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }

        // Toast
        Rectangle {
            id: toast

            function show(message) {
                toastText.text = message
                opacity = 1
                toastTimer.restart()
            }

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: toastText.implicitWidth + 28
            height: 32
            radius: 9
            color: Theme.toastBg
            opacity: 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Text {
                id: toastText
                anchors.centerIn: parent
                font.pixelSize: 12
                color: "white"
            }
            Timer {
                id: toastTimer
                interval: 1800
                onTriggered: toast.opacity = 0
            }
        }
    }
}
