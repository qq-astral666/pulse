#pragma once

#include "Metrics.h"
#include "Probe.h"

#include <QElapsedTimer>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <memory>

class IconCache;

// Samples the system on a timer and exposes the numbers to QML.
//
// Two speeds: while the popup is closed only what the menu bar needs is
// read (cheap); `detailed` (popup open) adds processes, battery details,
// disk and uptime.
class SystemMonitor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by AppController")

    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(bool detailed READ detailed WRITE setDetailed NOTIFY detailedChanged)
    Q_PROPERTY(int processSort READ processSort WRITE setProcessSort NOTIFY processSortChanged)
    Q_PROPERTY(int historyLength READ historyLength CONSTANT)

    // CPU
    Q_PROPERTY(double cpuUsage MEMBER m_cpuUsage NOTIFY updated)
    Q_PROPERTY(double cpuUser MEMBER m_cpuUser NOTIFY updated)
    Q_PROPERTY(double cpuSystem MEMBER m_cpuSystem NOTIFY updated)
    Q_PROPERTY(QVariantList cpuHistory MEMBER m_cpuHistoryList NOTIFY updated)
    Q_PROPERTY(QVariantList coreUsage MEMBER m_coreUsage NOTIFY updated)
    Q_PROPERTY(QStringList coreKinds MEMBER m_coreKinds NOTIFY updated)
    Q_PROPERTY(QString cpuModel MEMBER m_cpuModel NOTIFY updated)
    Q_PROPERTY(QString loadAverage MEMBER m_loadAverage NOTIFY updated)

    // Memory
    Q_PROPERTY(double memTotal MEMBER m_memTotal NOTIFY updated)
    Q_PROPERTY(double memUsed MEMBER m_memUsed NOTIFY updated)
    Q_PROPERTY(double memApp MEMBER m_memApp NOTIFY updated)
    Q_PROPERTY(double memWired MEMBER m_memWired NOTIFY updated)
    Q_PROPERTY(double memCompressed MEMBER m_memCompressed NOTIFY updated)
    Q_PROPERTY(double memCached MEMBER m_memCached NOTIFY updated)
    Q_PROPERTY(double swapUsed MEMBER m_swapUsed NOTIFY updated)
    Q_PROPERTY(int memPressure MEMBER m_memPressure NOTIFY updated)
    Q_PROPERTY(QVariantList memHistory MEMBER m_memHistoryList NOTIFY updated)

    // Network
    Q_PROPERTY(double netIn MEMBER m_netIn NOTIFY updated)
    Q_PROPERTY(double netOut MEMBER m_netOut NOTIFY updated)
    Q_PROPERTY(double netTotalIn MEMBER m_netTotalIn NOTIFY updated)
    Q_PROPERTY(double netTotalOut MEMBER m_netTotalOut NOTIFY updated)
    Q_PROPERTY(QVariantList netInHistory MEMBER m_netInHistoryList NOTIFY updated)
    Q_PROPERTY(QVariantList netOutHistory MEMBER m_netOutHistoryList NOTIFY updated)
    Q_PROPERTY(QString netInterface MEMBER m_netInterface NOTIFY updated)
    Q_PROPERTY(QString netAddress MEMBER m_netAddress NOTIFY updated)

    // GPU
    Q_PROPERTY(int gpuUsage MEMBER m_gpuUsage NOTIFY updated)
    Q_PROPERTY(QVariantList gpuHistory MEMBER m_gpuHistoryList NOTIFY updated)

    // Battery
    Q_PROPERTY(bool batteryPresent MEMBER m_batteryPresent NOTIFY updated)
    Q_PROPERTY(int batteryPercent MEMBER m_batteryPercent NOTIFY updated)
    Q_PROPERTY(bool batteryCharging MEMBER m_batteryCharging NOTIFY updated)
    Q_PROPERTY(bool batteryOnAC MEMBER m_batteryOnAC NOTIFY updated)
    Q_PROPERTY(int batteryMinutes MEMBER m_batteryMinutes NOTIFY updated)
    Q_PROPERTY(int batteryCycles MEMBER m_batteryCycles NOTIFY updated)
    Q_PROPERTY(int batteryHealth MEMBER m_batteryHealth NOTIFY updated)
    Q_PROPERTY(double batteryTemperature MEMBER m_batteryTemperature NOTIFY updated)
    Q_PROPERTY(int adapterWatts MEMBER m_adapterWatts NOTIFY updated)

    // Misc
    Q_PROPERTY(double diskTotal MEMBER m_diskTotal NOTIFY updated)
    Q_PROPERTY(double diskFree MEMBER m_diskFree NOTIFY updated)
    Q_PROPERTY(int thermalState MEMBER m_thermalState NOTIFY updated)
    Q_PROPERTY(qint64 uptime MEMBER m_uptime NOTIFY updated)
    Q_PROPERTY(QVariantList processes MEMBER m_processes NOTIFY updated)

public:
    SystemMonitor(std::shared_ptr<IconCache> icons, QObject* parent = nullptr);

    void start();

    int interval() const { return m_interval; }
    void setInterval(int ms);
    bool detailed() const { return m_detailed; }
    void setDetailed(bool detailed);
    int processSort() const { return m_processSort; }
    void setProcessSort(int sort);
    int historyLength() const { return kHistory; }

    // Used by the menu-bar renderer.
    double cpuUsage() const { return m_cpuUsage; }
    double memoryPercent() const { return m_memTotal > 0 ? 100.0 * m_memUsed / m_memTotal : 0.0; }
    double netIn() const { return m_netIn; }
    double netOut() const { return m_netOut; }
    int gpuUsage() const { return m_gpuUsage; }
    int batteryPercent() const { return m_batteryPresent ? m_batteryPercent : -1; }
    bool batteryCharging() const { return m_batteryCharging; }

    Q_INVOKABLE QString formatBytes(double bytes) const { return metrics::formatBytes(bytes); }
    Q_INVOKABLE QString formatRate(double bytesPerSecond) const { return metrics::formatRate(bytesPerSecond); }
    Q_INVOKABLE QString formatDuration(qint64 seconds) const { return metrics::formatDuration(seconds); }

signals:
    void updated();
    void intervalChanged();
    void detailedChanged();
    void processSortChanged();

private:
    static constexpr int kHistory = 90;
    static constexpr int kTopProcesses = 7;

    void tick();
    void sampleCpu();
    void sampleMemory();
    void sampleNetwork(qint64 elapsedMs);
    void sampleGpu();
    void sampleBattery();
    void sampleProcesses();
    void sampleMisc();
    void rebuildProcessList();

    std::shared_ptr<IconCache> m_icons;
    QTimer m_timer;
    QElapsedTimer m_clock;
    int m_interval = 2000;
    bool m_detailed = false;
    int m_processSort = 0;   // 0 = CPU, 1 = memory
    quint64 m_tickCount = 0;

    probe::CpuSnapshot m_previousCpu;
    bool m_hasPreviousCpu = false;
    metrics::RateMeter m_inMeter;
    metrics::RateMeter m_outMeter;
    probe::NetCounters m_netStart;
    bool m_hasNetStart = false;
    probe::ProcessSampler m_processSampler;
    QList<probe::ProcessSample> m_lastProcesses;

    metrics::RingBuffer<double> m_cpuHistory { kHistory };
    metrics::RingBuffer<double> m_memHistory { kHistory };
    metrics::RingBuffer<double> m_netInHistory { kHistory };
    metrics::RingBuffer<double> m_netOutHistory { kHistory };
    metrics::RingBuffer<double> m_gpuHistory { kHistory };

    double m_cpuUsage = 0, m_cpuUser = 0, m_cpuSystem = 0;
    QVariantList m_cpuHistoryList, m_coreUsage;
    QStringList m_coreKinds;
    QString m_cpuModel, m_loadAverage;

    double m_memTotal = 0, m_memUsed = 0, m_memApp = 0, m_memWired = 0;
    double m_memCompressed = 0, m_memCached = 0, m_swapUsed = 0;
    int m_memPressure = 1;
    QVariantList m_memHistoryList;

    double m_netIn = 0, m_netOut = 0, m_netTotalIn = 0, m_netTotalOut = 0;
    QVariantList m_netInHistoryList, m_netOutHistoryList;
    QString m_netInterface, m_netAddress;

    int m_gpuUsage = -1;
    QVariantList m_gpuHistoryList;

    bool m_batteryPresent = false, m_batteryCharging = false, m_batteryOnAC = false;
    int m_batteryPercent = -1, m_batteryMinutes = -1, m_batteryCycles = -1, m_batteryHealth = -1;
    double m_batteryTemperature = -1000;
    int m_adapterWatts = 0;

    double m_diskTotal = 0, m_diskFree = 0;
    int m_thermalState = 0;
    qint64 m_uptime = 0;
    QVariantList m_processes;
};
