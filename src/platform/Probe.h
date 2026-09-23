#pragma once

#include "Metrics.h"

#include <QElapsedTimer>
#include <QHash>
#include <QImage>
#include <QList>
#include <QString>

#include <cstdint>
#include <unordered_map>
#include <vector>

// Reads raw system counters. macOS implementation: Probe_mac.mm (Mach,
// sysctl, IOKit, libproc). Other platforms get zeros from Probe_stub.cpp.
namespace probe {

struct CpuSnapshot {
    metrics::CpuTicks total;
    std::vector<metrics::CpuTicks> cores;
};
bool readCpu(CpuSnapshot& out);

struct CpuInfo {
    QString model;          // "Apple M2"
    int logical = 0;
    int performanceCores = 0;
    int efficiencyCores = 0;
};
CpuInfo cpuInfo();

struct LoadAverage {
    double one = 0, five = 0, fifteen = 0;
};
LoadAverage loadAverage();

struct Memory {
    uint64_t total = 0;
    uint64_t app = 0;         // anonymous memory of processes
    uint64_t wired = 0;       // kernel, can't be paged out
    uint64_t compressed = 0;  // occupied by the compressor
    uint64_t cached = 0;      // file cache, reclaimable
    uint64_t free = 0;
    uint64_t swapUsed = 0;
    uint64_t swapTotal = 0;
    int pressure = 1;         // 1 normal, 2 warning, 4 critical
    // Same definition as "Memory Used" in Activity Monitor.
    uint64_t used() const { return app + wired + compressed; }
};
bool readMemory(Memory& out);

struct NetCounters {
    uint64_t bytesIn = 0;
    uint64_t bytesOut = 0;
};
// Only physical interfaces (en*): counting VPN tunnels too would double
// every byte that goes through them.
bool readNetwork(NetCounters& out);

struct NetInfo {
    QString interfaceName;
    QString ipv4;
};
NetInfo networkInfo();

struct Battery {
    bool present = false;
    int percent = -1;
    bool charging = false;
    bool onAC = false;
    int minutesLeft = -1;     // to empty, or to full while charging
    int cycleCount = -1;
    int healthPercent = -1;
    double temperatureC = -1000.0;
    int adapterWatts = 0;
};
bool readBattery(Battery& out);

int gpuUtilization();   // 0..100, -1 if unavailable
int thermalState();     // 0 nominal, 1 fair, 2 serious, 3 critical
qint64 uptimeSeconds();

struct ProcessSample {
    int pid = 0;
    QString name;
    double cpuPercent = 0.0;   // can exceed 100 for multi-threaded work
    uint64_t memoryBytes = 0;  // physical footprint, like Activity Monitor
};

// CPU% of a process is a delta, so the sampler keeps the previous CPU time
// of every pid between calls.
class ProcessSampler {
public:
    QList<ProcessSample> sample();

private:
    QString nameOf(int pid);

    QElapsedTimer m_clock;
    std::unordered_map<int, uint64_t> m_previousCpuNs;
    QHash<int, QString> m_names;
};

QString appDisplayName(int pid);          // "Google Chrome" or empty
QImage appIconForPid(int pid, int pixels); // null if pid is not an app

} // namespace probe
