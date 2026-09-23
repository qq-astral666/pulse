#include "SystemMonitor.h"

#include "ProcessIcons.h"

#include <QStorageInfo>
#include <QVariantMap>

#include <algorithm>

SystemMonitor::SystemMonitor(std::shared_ptr<IconCache> icons, QObject* parent)
    : QObject(parent)
    , m_icons(std::move(icons))
{
    const probe::CpuInfo info = probe::cpuInfo();
    m_cpuModel = info.model;
    // Apple Silicon enumerates efficiency cores first.
    for (int i = 0; i < info.logical; ++i) {
        if (info.efficiencyCores > 0)
            m_coreKinds << (i < info.efficiencyCores ? QStringLiteral("E") : QStringLiteral("P"));
        else
            m_coreKinds << QString();
    }

    m_timer.setInterval(m_interval);
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::tick);
}

void SystemMonitor::start()
{
    // Prime the delta-based counters so the first tick has real numbers.
    m_hasPreviousCpu = probe::readCpu(m_previousCpu);
    probe::NetCounters counters;
    if (probe::readNetwork(counters)) {
        m_netStart = counters;
        m_hasNetStart = true;
        m_inMeter.update(counters.bytesIn, 0);
        m_outMeter.update(counters.bytesOut, 0);
    }
    sampleMemory();
    sampleBattery();
    sampleGpu();
    m_clock.start();
    m_timer.start();
    emit updated();
}

void SystemMonitor::setInterval(int ms)
{
    ms = qBound(500, ms, 10000);
    if (ms == m_interval)
        return;
    m_interval = ms;
    m_timer.setInterval(ms);
    emit intervalChanged();
}

void SystemMonitor::setDetailed(bool detailed)
{
    if (detailed == m_detailed)
        return;
    m_detailed = detailed;
    emit detailedChanged();
    if (detailed) {
        // Popup just opened: fill everything right away instead of showing
        // empty cards until the next tick. Process CPU% needs two samples,
        // so the first one only primes the sampler.
        m_processSampler.sample();
        sampleBattery();
        sampleMisc();
        const probe::NetInfo net = probe::networkInfo();
        m_netInterface = net.interfaceName;
        m_netAddress = net.ipv4;
        emit updated();
    }
}

void SystemMonitor::setProcessSort(int sort)
{
    if (sort == m_processSort)
        return;
    m_processSort = sort;
    emit processSortChanged();
    rebuildProcessList();
    emit updated();
}

void SystemMonitor::tick()
{
    const qint64 elapsedMs = m_clock.restart();
    ++m_tickCount;

    sampleCpu();
    sampleMemory();
    sampleNetwork(elapsedMs);
    sampleGpu();

    if (m_detailed || m_tickCount % 15 == 0)
        sampleBattery();
    if (m_detailed) {
        sampleProcesses();
        sampleMisc();
        if (m_tickCount % 10 == 0) {
            const probe::NetInfo net = probe::networkInfo();
            m_netInterface = net.interfaceName;
            m_netAddress = net.ipv4;
        }
    }
    emit updated();
}

void SystemMonitor::sampleCpu()
{
    probe::CpuSnapshot snapshot;
    if (!probe::readCpu(snapshot))
        return;

    if (m_hasPreviousCpu) {
        const metrics::CpuLoad total = metrics::loadBetween(m_previousCpu.total, snapshot.total);
        m_cpuUser = total.user * 100.0;
        m_cpuSystem = total.system * 100.0;
        m_cpuUsage = std::min(100.0, m_cpuUser + m_cpuSystem);

        m_coreUsage.clear();
        const size_t cores = std::min(snapshot.cores.size(), m_previousCpu.cores.size());
        for (size_t i = 0; i < cores; ++i)
            m_coreUsage << metrics::loadBetween(m_previousCpu.cores[i], snapshot.cores[i]).total() * 100.0;
    }
    m_previousCpu = std::move(snapshot);
    m_hasPreviousCpu = true;

    m_cpuHistory.push(m_cpuUsage);
    m_cpuHistoryList = m_cpuHistory.toVariantList();
}

void SystemMonitor::sampleMemory()
{
    probe::Memory memory;
    if (!probe::readMemory(memory))
        return;
    m_memTotal = double(memory.total);
    m_memUsed = double(memory.used());
    m_memApp = double(memory.app);
    m_memWired = double(memory.wired);
    m_memCompressed = double(memory.compressed);
    m_memCached = double(memory.cached);
    m_swapUsed = double(memory.swapUsed);
    m_memPressure = memory.pressure;

    m_memHistory.push(m_memTotal > 0 ? 100.0 * m_memUsed / m_memTotal : 0.0);
    m_memHistoryList = m_memHistory.toVariantList();
}

void SystemMonitor::sampleNetwork(qint64 elapsedMs)
{
    probe::NetCounters counters;
    if (!probe::readNetwork(counters))
        return;
    if (!m_hasNetStart) {
        m_netStart = counters;
        m_hasNetStart = true;
    }
    m_netIn = m_inMeter.update(counters.bytesIn, elapsedMs);
    m_netOut = m_outMeter.update(counters.bytesOut, elapsedMs);
    m_netTotalIn = counters.bytesIn >= m_netStart.bytesIn ? double(counters.bytesIn - m_netStart.bytesIn) : 0.0;
    m_netTotalOut = counters.bytesOut >= m_netStart.bytesOut ? double(counters.bytesOut - m_netStart.bytesOut) : 0.0;

    m_netInHistory.push(m_netIn);
    m_netOutHistory.push(m_netOut);
    m_netInHistoryList = m_netInHistory.toVariantList();
    m_netOutHistoryList = m_netOutHistory.toVariantList();
}

void SystemMonitor::sampleGpu()
{
    m_gpuUsage = probe::gpuUtilization();
    if (m_gpuUsage >= 0) {
        m_gpuHistory.push(m_gpuUsage);
        m_gpuHistoryList = m_gpuHistory.toVariantList();
    }
}

void SystemMonitor::sampleBattery()
{
    probe::Battery battery;
    m_batteryPresent = probe::readBattery(battery);
    m_batteryPercent = battery.percent;
    m_batteryCharging = battery.charging;
    m_batteryOnAC = battery.onAC;
    m_batteryMinutes = battery.minutesLeft;
    m_batteryCycles = battery.cycleCount;
    m_batteryHealth = battery.healthPercent;
    m_batteryTemperature = battery.temperatureC;
    m_adapterWatts = battery.adapterWatts;
}

void SystemMonitor::sampleProcesses()
{
    m_lastProcesses = m_processSampler.sample();
    rebuildProcessList();
}

void SystemMonitor::rebuildProcessList()
{
    QList<probe::ProcessSample> sorted = m_lastProcesses;
    if (m_processSort == 1) {
        std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) {
            return a.memoryBytes > b.memoryBytes;
        });
    } else {
        std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) {
            return a.cpuPercent > b.cpuPercent;
        });
    }

    m_processes.clear();
    const int count = std::min<int>(kTopProcesses, int(sorted.size()));
    for (int i = 0; i < count; ++i) {
        const probe::ProcessSample& s = sorted.at(i);
        QString name = probe::appDisplayName(s.pid);
        if (name.isEmpty())
            name = s.name;
        QVariantMap row;
        row.insert(QStringLiteral("pid"), s.pid);
        row.insert(QStringLiteral("name"), name);
        row.insert(QStringLiteral("cpu"), s.cpuPercent);
        row.insert(QStringLiteral("memory"), double(s.memoryBytes));
        row.insert(QStringLiteral("hasIcon"), m_icons->ensure(s.pid));
        m_processes << row;
    }
}

void SystemMonitor::sampleMisc()
{
    // "/" is the sealed read-only system volume; user data lives here.
    QStorageInfo disk(QStringLiteral("/System/Volumes/Data"));
    if (!disk.isValid())
        disk = QStorageInfo::root();
    m_diskTotal = double(disk.bytesTotal());
    m_diskFree = double(disk.bytesAvailable());

    const probe::LoadAverage load = probe::loadAverage();
    m_loadAverage = QStringLiteral("%1 · %2 · %3")
                        .arg(load.one, 0, 'f', 2)
                        .arg(load.five, 0, 'f', 2)
                        .arg(load.fifteen, 0, 'f', 2);
    m_thermalState = probe::thermalState();
    m_uptime = probe::uptimeSeconds();
}
