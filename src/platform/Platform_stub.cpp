// Non-macOS fallback so the project still builds (and the core can be
// tested) elsewhere. Everything reads as zero / unavailable.

#include "Native.h"
#include "Probe.h"

namespace probe {

bool readCpu(CpuSnapshot&) { return false; }
CpuInfo cpuInfo() { return {}; }
LoadAverage loadAverage() { return {}; }
bool readMemory(Memory&) { return false; }
bool readNetwork(NetCounters&) { return false; }
NetInfo networkInfo() { return {}; }
bool readBattery(Battery& out)
{
    out = {};
    return false;
}
int gpuUtilization() { return -1; }
int thermalState() { return 0; }
qint64 uptimeSeconds() { return 0; }
QList<ProcessSample> ProcessSampler::sample() { return {}; }
QString ProcessSampler::nameOf(int) { return {}; }
QString appDisplayName(int) { return {}; }
QImage appIconForPid(int, int) { return {}; }

} // namespace probe

namespace native {

struct StatusItem::Impl {};
StatusItem::StatusItem() : d(std::make_unique<Impl>()) {}
StatusItem::~StatusItem() = default;
void StatusItem::setImage(const QImage&) {}
void StatusItem::setToolTip(const QString&) {}
void StatusItem::setClickHandler(std::function<void()>) {}
QRect StatusItem::geometry() const { return {}; }
void bringToFront(QWindow*) {}
bool launchAtLoginEnabled() { return false; }
bool setLaunchAtLogin(bool, QString* error)
{
    if (error)
        *error = QStringLiteral("Not supported on this platform");
    return false;
}
void openActivityMonitor() {}

} // namespace native
