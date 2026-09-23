pragma Singleton
import QtQuick

// Design tokens shared by every view.
QtObject {
    property int mode: 0   // 0 = system, 1 = dark, 2 = light

    readonly property bool dark: mode === 1
        || (mode === 0 && Application.styleHints.colorScheme === Qt.ColorScheme.Dark)

    // surfaces
    readonly property color panel: dark ? "#17181d" : "#f4f4f7"
    readonly property color panelBorder: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color card: dark ? Qt.rgba(1, 1, 1, 0.045) : "#ffffff"
    readonly property color cardBorder: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color divider: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color segmentActive: dark ? Qt.rgba(1, 1, 1, 0.14) : "#ffffff"
    readonly property color toastBg: dark ? "#3a3a42" : "#1c1c20"

    // text
    readonly property color text: dark ? "#f3f3f6" : "#18181b"
    readonly property color textSecondary: dark ? Qt.rgba(1, 1, 1, 0.60) : Qt.rgba(0, 0, 0, 0.56)
    readonly property color textTertiary: dark ? Qt.rgba(1, 1, 1, 0.38) : Qt.rgba(0, 0, 0, 0.36)

    // metric colours
    readonly property color accent: "#8b7cff"
    readonly property color cpu: "#8b7cff"
    readonly property color cpuSystem: "#ff6b9a"
    readonly property color cpuEfficiency: "#5ac8fa"
    readonly property color memory: "#4da3ff"
    readonly property color memoryWired: "#ffb340"
    readonly property color memoryCompressed: "#c07bff"
    readonly property color memoryCached: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.16)
    readonly property color netIn: "#34c759"
    readonly property color netOut: "#ff9f0a"
    readonly property color gpu: "#ff5fa2"
    readonly property color disk: "#5ac8fa"
    readonly property color good: "#34c759"
    readonly property color warning: "#ff9f0a"
    readonly property color danger: "#ff453a"

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" : "monospace"

    function tint(c, alpha) {
        return Qt.rgba(c.r, c.g, c.b, alpha)
    }

    function batteryColor(percent, charging) {
        if (charging) return good
        if (percent <= 10) return danger
        if (percent <= 20) return warning
        return good
    }

    function plural(n, one, few, many) {
        const m10 = n % 10, m100 = n % 100
        if (m10 === 1 && m100 !== 11) return one
        if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return few
        return many
    }

    function minutesText(m) {
        if (m < 0) return "…"
        const h = Math.floor(m / 60), mm = m % 60
        return h > 0 ? h + " ч " + mm + " мин" : mm + " мин"
    }
}
