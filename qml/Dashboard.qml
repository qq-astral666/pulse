import QtQuick
import QtQuick.Layouts

// All metric cards. `mon` is the SystemMonitor.
ColumnLayout {
    id: root

    required property var mon

    spacing: 10

    function maxOf(list) {
        let m = 0
        for (let i = 0; i < list.length; ++i)
            m = Math.max(m, list[i])
        return m
    }

    // ------------------------------------------------------------------ CPU
    Card {
        Layout.fillWidth: true
        title: "Процессор"
        icon: "cpu"
        accent: Theme.cpu
        trailing: Text {
            text: root.mon.cpuModel
            font.pixelSize: 11
            color: Theme.textTertiary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            RingGauge {
                value: root.mon.cpuUsage
                color: Theme.cpu
                size: 78
                caption: "CPU"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7
                LegendRow {
                    Layout.fillWidth: true
                    dot: Theme.cpu
                    label: "Пользователь"
                    value: root.mon.cpuUser.toFixed(0) + "%"
                }
                LegendRow {
                    Layout.fillWidth: true
                    dot: Theme.cpuSystem
                    label: "Система"
                    value: root.mon.cpuSystem.toFixed(0) + "%"
                }
                LegendRow {
                    Layout.fillWidth: true
                    label: "Нагрузка 1 · 5 · 15 мин"
                    value: root.mon.loadAverage
                }
            }
        }

        Sparkline {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            values: root.mon.cpuHistory
            capacity: root.mon.historyLength
            maxValue: 100
            color: Theme.cpu
        }

        CoreBars {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: root.mon.coreUsage.length > 0
            values: root.mon.coreUsage
            kinds: root.mon.coreKinds
        }
    }

    // --------------------------------------------------------------- Memory
    Card {
        Layout.fillWidth: true
        title: "Память"
        icon: "memory"
        accent: Theme.memory
        trailing: Chip {
            text: root.mon.memPressure >= 4 ? "Критично" : root.mon.memPressure >= 2 ? "Высокая нагрузка" : "Норма"
            tone: root.mon.memPressure >= 4 ? Theme.danger : root.mon.memPressure >= 2 ? Theme.warning : Theme.good
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: root.mon.formatBytes(root.mon.memUsed)
                font.pixelSize: 22
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
                color: Theme.text
            }
            Text {
                Layout.alignment: Qt.AlignBaseline
                text: "из " + root.mon.formatBytes(root.mon.memTotal)
                font.pixelSize: 12
                color: Theme.textSecondary
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (root.mon.memTotal > 0 ? Math.round(100 * root.mon.memUsed / root.mon.memTotal) : 0) + "%"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: Theme.memory
            }
        }

        SegmentBar {
            Layout.fillWidth: true
            total: root.mon.memTotal
            segments: [
                { value: root.mon.memApp, color: Theme.memory },
                { value: root.mon.memWired, color: Theme.memoryWired },
                { value: root.mon.memCompressed, color: Theme.memoryCompressed },
                { value: root.mon.memCached, color: Theme.memoryCached }
            ]
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 18
            rowSpacing: 6
            LegendRow { Layout.fillWidth: true; dot: Theme.memory; label: "Приложения"; value: root.mon.formatBytes(root.mon.memApp) }
            LegendRow { Layout.fillWidth: true; dot: Theme.memoryWired; label: "Ядро"; value: root.mon.formatBytes(root.mon.memWired) }
            LegendRow { Layout.fillWidth: true; dot: Theme.memoryCompressed; label: "Сжатая"; value: root.mon.formatBytes(root.mon.memCompressed) }
            LegendRow { Layout.fillWidth: true; dot: Theme.memoryCached; label: "Кэш"; value: root.mon.formatBytes(root.mon.memCached) }
        }

        LegendRow {
            Layout.fillWidth: true
            visible: root.mon.swapUsed > 0
            label: "Файл подкачки"
            value: root.mon.formatBytes(root.mon.swapUsed)
        }
    }

    // -------------------------------------------------------------- Network
    Card {
        id: netCard
        Layout.fillWidth: true
        title: "Сеть"
        icon: "network"
        accent: Theme.netIn
        trailing: Text {
            text: root.mon.netInterface === "" ? "нет подключения"
                  : root.mon.netInterface + (root.mon.netAddress !== "" ? " · " + root.mon.netAddress : "")
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
            color: Theme.textTertiary
        }

        readonly property real netScale: Math.max(64 * 1024,
                                               root.maxOf(root.mon.netInHistory),
                                               root.maxOf(root.mon.netOutHistory)) * 1.15

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "↓ Загрузка"; font.pixelSize: 11; color: Theme.netIn }
                Text {
                    text: root.mon.formatRate(root.mon.netIn)
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    color: Theme.text
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "↑ Отдача"; font.pixelSize: 11; color: Theme.netOut }
                Text {
                    text: root.mon.formatRate(root.mon.netOut)
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    color: Theme.text
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Sparkline {
                anchors.fill: parent
                values: root.mon.netInHistory
                capacity: root.mon.historyLength
                maxValue: netCard.netScale
                color: Theme.netIn
            }
            Sparkline {
                anchors.fill: parent
                values: root.mon.netOutHistory
                capacity: root.mon.historyLength
                maxValue: netCard.netScale
                color: Theme.netOut
                filled: false
            }
        }

        LegendRow {
            Layout.fillWidth: true
            label: "С запуска Pulse"
            value: "↓ " + root.mon.formatBytes(root.mon.netTotalIn) + "   ↑ " + root.mon.formatBytes(root.mon.netTotalOut)
        }
    }

    // ---------------------------------------------------------- GPU + Disk
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Card {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            visible: root.mon.gpuUsage >= 0
            title: "Видеочип"
            icon: "gpu"
            accent: Theme.gpu

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                RingGauge {
                    value: Math.max(0, root.mon.gpuUsage)
                    color: Theme.gpu
                    size: 54
                    thickness: 6
                }
                Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    values: root.mon.gpuHistory
                    capacity: root.mon.historyLength
                    maxValue: 100
                    color: Theme.gpu
                }
            }
        }

        Card {
            id: diskCard
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            title: "Диск"
            icon: "disk"
            accent: Theme.disk

            readonly property real usedBytes: Math.max(0, root.mon.diskTotal - root.mon.diskFree)

            Text {
                text: "Свободно " + root.mon.formatBytes(root.mon.diskFree)
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
            SegmentBar {
                Layout.fillWidth: true
                total: root.mon.diskTotal
                segments: [ { value: diskCard.usedBytes, color: Theme.disk } ]
            }
            Text {
                text: "Занято " + root.mon.formatBytes(diskCard.usedBytes) + " из " + root.mon.formatBytes(root.mon.diskTotal)
                font.pixelSize: 11
                color: Theme.textTertiary
            }
        }
    }

    // -------------------------------------------------------------- Battery
    Card {
        Layout.fillWidth: true
        visible: root.mon.batteryPresent
        title: "Аккумулятор"
        icon: "battery"
        accent: Theme.batteryColor(root.mon.batteryPercent, root.mon.batteryCharging)
        trailing: Chip {
            text: root.mon.batteryCharging ? "Заряжается" : root.mon.batteryOnAC ? "От сети" : "От батареи"
            tone: root.mon.batteryCharging || root.mon.batteryOnAC ? Theme.good : Theme.textSecondary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: Math.max(0, root.mon.batteryPercent) + "%"
                font.pixelSize: 22
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
                color: Theme.text
            }
            Icon {
                visible: root.mon.batteryCharging
                name: "bolt"
                size: 16
                color: Theme.good
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.mon.batteryCharging
                      ? (root.mon.batteryMinutes > 0 ? "до полной " + Theme.minutesText(root.mon.batteryMinutes) : "")
                      : (!root.mon.batteryOnAC && root.mon.batteryMinutes > 0 ? "осталось " + Theme.minutesText(root.mon.batteryMinutes) : "")
                font.pixelSize: 12
                color: Theme.textSecondary
            }
        }

        SegmentBar {
            Layout.fillWidth: true
            total: 100
            segments: [ {
                value: Math.max(0, root.mon.batteryPercent),
                color: Theme.batteryColor(root.mon.batteryPercent, root.mon.batteryCharging)
            } ]
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 18
            rowSpacing: 6
            LegendRow {
                Layout.fillWidth: true
                label: "Состояние"
                value: root.mon.batteryHealth > 0 ? root.mon.batteryHealth + "%" : "—"
            }
            LegendRow {
                Layout.fillWidth: true
                label: "Циклы"
                value: root.mon.batteryCycles >= 0 ? String(root.mon.batteryCycles) : "—"
            }
            LegendRow {
                Layout.fillWidth: true
                label: "Температура"
                value: root.mon.batteryTemperature > -100 ? root.mon.batteryTemperature.toFixed(1) + " °C" : "—"
            }
            LegendRow {
                Layout.fillWidth: true
                label: "Адаптер"
                value: root.mon.adapterWatts > 0 ? root.mon.adapterWatts + " Вт" : "—"
            }
        }
    }

    // ------------------------------------------------------------ Processes
    Card {
        id: processCard
        Layout.fillWidth: true
        title: "Процессы"
        icon: "list"
        accent: Theme.accent
        trailing: Segmented {
            options: ["CPU", "Память"]
            fontSize: 11
            current: root.mon.processSort
            onSelected: (i) => root.mon.processSort = i
        }

        readonly property bool byMemory: root.mon.processSort === 1
        readonly property real topValue: {
            let m = 0.0001
            const list = root.mon.processes
            for (let i = 0; i < list.length; ++i)
                m = Math.max(m, byMemory ? list[i].memory : list[i].cpu)
            return m
        }

        Text {
            visible: root.mon.processes.length === 0
            text: "Собираю данные…"
            font.pixelSize: 12
            color: Theme.textTertiary
        }

        Column {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: root.mon.processes
                delegate: ProcessRow {
                    required property var modelData
                    width: parent ? parent.width : 0
                    pid: modelData.pid
                    name: modelData.name
                    hasIcon: modelData.hasIcon
                    barColor: processCard.byMemory ? Theme.memory : Theme.cpu
                    valueText: processCard.byMemory ? root.mon.formatBytes(modelData.memory)
                                                    : modelData.cpu.toFixed(1) + "%"
                    fraction: (processCard.byMemory ? modelData.memory : modelData.cpu) / processCard.topValue
                }
            }
        }
    }
}
