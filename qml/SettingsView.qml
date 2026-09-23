import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var controller

    spacing: 10

    Card {
        Layout.fillWidth: true
        title: "Строка меню"
        icon: "pulse"
        accent: Theme.accent

        Text {
            Layout.fillWidth: true
            text: "Что показывать рядом с часами"
            font.pixelSize: 11
            color: Theme.textSecondary
        }

        Repeater {
            model: [
                { key: "cpu", title: "Процессор", hint: "Загрузка CPU в %" },
                { key: "memory", title: "Память", hint: "Занятая RAM в %" },
                { key: "network", title: "Сеть", hint: "Скорость загрузки и отдачи" },
                { key: "gpu", title: "Видеочип", hint: "Загрузка GPU в %" },
                { key: "battery", title: "Аккумулятор", hint: "Заряд в %" }
            ]
            delegate: SettingRow {
                required property var modelData
                Layout.fillWidth: true
                title: modelData.title
                subtitle: modelData.hint
                Toggle {
                    checked: root.controller.bar[modelData.key] === true
                    onToggled: (value) => root.controller.setBarItem(modelData.key, value)
                }
            }
        }
    }

    Card {
        Layout.fillWidth: true
        title: "Общие"
        icon: "settings"
        accent: Theme.memory

        SettingRow {
            Layout.fillWidth: true
            title: "Обновлять каждые"
            Segmented {
                options: ["1 с", "2 с", "5 с"]
                current: root.controller.intervalIndex
                onSelected: (i) => root.controller.intervalIndex = i
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: "Тема"
            Segmented {
                options: ["Система", "Тёмная", "Светлая"]
                current: root.controller.themeMode
                onSelected: (i) => root.controller.themeMode = i
            }
        }

        SettingRow {
            Layout.fillWidth: true
            visible: root.controller.isMac
            title: "Запускать при входе"
            subtitle: "Pulse стартует вместе с macOS"
            Toggle {
                checked: root.controller.launchAtLogin
                onToggled: (value) => root.controller.launchAtLogin = value
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        Text {
            Layout.fillWidth: true
            text: "Pulse " + Qt.application.version + " · C++20 · Qt 6"
            font.pixelSize: 11
            color: Theme.textTertiary
        }
        PillButton {
            text: "Выйти"
            icon: "power"
            tone: Theme.danger
            onClicked: root.controller.quit()
        }
    }
}
