// macOS system probes. Compiled as Objective-C++ with ARC.

#include "Probe.h"

#import <AppKit/AppKit.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/ps/IOPowerSources.h>

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <net/if.h>
#include <net/route.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <sys/proc_info.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/time.h>

#include <algorithm>
#include <string>

namespace {

// mach_host_self() hands out a new send right on every call; cache it.
host_t hostPort()
{
    static const host_t host = mach_host_self();
    return host;
}

template <typename T>
T sysctlValue(const char* name, T fallback)
{
    T value {};
    size_t size = sizeof(value);
    return sysctlbyname(name, &value, &size, nullptr, 0) == 0 ? value : fallback;
}

QString sysctlString(const char* name)
{
    size_t size = 0;
    if (sysctlbyname(name, nullptr, &size, nullptr, 0) != 0 || size == 0)
        return {};
    std::string buffer(size, '\0');
    if (sysctlbyname(name, buffer.data(), &size, nullptr, 0) != 0)
        return {};
    return QString::fromUtf8(buffer.c_str());
}

// On Apple Silicon proc_pidinfo reports CPU time in Mach ticks, not ns.
double machTicksToNs()
{
    static const double scale = [] {
        mach_timebase_info_data_t tb {};
        mach_timebase_info(&tb);
        return tb.denom ? double(tb.numer) / double(tb.denom) : 1.0;
    }();
    return scale;
}

bool isPhysicalInterface(const char* name)
{
    return name && name[0] == 'e' && name[1] == 'n';
}

} // namespace

namespace probe {

bool readCpu(CpuSnapshot& out)
{
    natural_t cpuCount = 0;
    processor_info_array_t info = nullptr;
    mach_msg_type_number_t infoCount = 0;
    if (host_processor_info(hostPort(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) != KERN_SUCCESS)
        return false;

    const auto* load = reinterpret_cast<processor_cpu_load_info_t>(info);
    out.total = {};
    out.cores.assign(cpuCount, metrics::CpuTicks{});
    for (natural_t i = 0; i < cpuCount; ++i) {
        metrics::CpuTicks t;
        t.user = load[i].cpu_ticks[CPU_STATE_USER];
        t.system = load[i].cpu_ticks[CPU_STATE_SYSTEM];
        t.idle = load[i].cpu_ticks[CPU_STATE_IDLE];
        t.nice = load[i].cpu_ticks[CPU_STATE_NICE];
        out.cores[i] = t;
        out.total += t;
    }
    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(info), infoCount * sizeof(integer_t));
    return true;
}

CpuInfo cpuInfo()
{
    CpuInfo info;
    info.model = sysctlString("machdep.cpu.brand_string");
    info.logical = sysctlValue<int>("hw.logicalcpu", 0);
    // Apple Silicon: perflevel0 = performance, perflevel1 = efficiency.
    info.performanceCores = sysctlValue<int>("hw.perflevel0.logicalcpu", 0);
    info.efficiencyCores = sysctlValue<int>("hw.perflevel1.logicalcpu", 0);
    return info;
}

LoadAverage loadAverage()
{
    double values[3] = { 0, 0, 0 };
    if (getloadavg(values, 3) != 3)
        return {};
    return { values[0], values[1], values[2] };
}

bool readMemory(Memory& out)
{
    vm_statistics64_data_t vm {};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(hostPort(), HOST_VM_INFO64, reinterpret_cast<host_info64_t>(&vm), &count) != KERN_SUCCESS)
        return false;

    vm_size_t pageSize = 0;
    host_page_size(hostPort(), &pageSize);
    const uint64_t page = pageSize;

    const uint64_t internal = vm.internal_page_count;
    const uint64_t purgeable = vm.purgeable_count;

    out.total = sysctlValue<uint64_t>("hw.memsize", 0);
    out.wired = uint64_t(vm.wire_count) * page;
    out.compressed = uint64_t(vm.compressor_page_count) * page;
    out.app = (internal > purgeable ? internal - purgeable : 0) * page;
    out.cached = (uint64_t(vm.external_page_count) + purgeable) * page;
    out.free = uint64_t(vm.free_count) * page;

    xsw_usage swap {};
    size_t size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, nullptr, 0) == 0) {
        out.swapUsed = swap.xsu_used;
        out.swapTotal = swap.xsu_total;
    }
    out.pressure = sysctlValue<int>("kern.memorystatus_vm_pressure_level", 1);
    return true;
}

bool readNetwork(NetCounters& out)
{
    // NET_RT_IFLIST2 gives 64-bit counters; getifaddrs() only has 32-bit
    // ones that wrap every 4 GB.
    int mib[] = { CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0 };
    size_t length = 0;
    if (sysctl(mib, 6, nullptr, &length, nullptr, 0) != 0)
        return false;
    std::vector<char> buffer(length);
    if (sysctl(mib, 6, buffer.data(), &length, nullptr, 0) != 0)
        return false;

    out = {};
    char* cursor = buffer.data();
    char* const end = buffer.data() + length;
    while (cursor + sizeof(if_msghdr) <= end) {
        auto* header = reinterpret_cast<if_msghdr*>(cursor);
        if (header->ifm_msglen == 0)
            break;
        if (header->ifm_type == RTM_IFINFO2) {
            auto* info = reinterpret_cast<if_msghdr2*>(cursor);
            char name[IF_NAMESIZE] = {};
            if ((info->ifm_flags & IFF_UP) && !(info->ifm_flags & IFF_LOOPBACK)
                && if_indextoname(info->ifm_index, name) && isPhysicalInterface(name)) {
                out.bytesIn += info->ifm_data.ifi_ibytes;
                out.bytesOut += info->ifm_data.ifi_obytes;
            }
        }
        cursor += header->ifm_msglen;
    }
    return true;
}

NetInfo networkInfo()
{
    NetInfo result;
    ifaddrs* list = nullptr;
    if (getifaddrs(&list) != 0)
        return result;
    for (ifaddrs* it = list; it; it = it->ifa_next) {
        if (!it->ifa_addr || it->ifa_addr->sa_family != AF_INET)
            continue;
        if (!(it->ifa_flags & IFF_UP) || !(it->ifa_flags & IFF_RUNNING) || !isPhysicalInterface(it->ifa_name))
            continue;
        char address[INET_ADDRSTRLEN] = {};
        const auto* sin = reinterpret_cast<const sockaddr_in*>(it->ifa_addr);
        if (!inet_ntop(AF_INET, &sin->sin_addr, address, sizeof(address)))
            continue;
        result.interfaceName = QString::fromUtf8(it->ifa_name);
        result.ipv4 = QString::fromUtf8(address);
        if (qstrcmp(it->ifa_name, "en0") == 0)
            break;   // prefer the built-in interface
    }
    freeifaddrs(list);
    return result;
}

bool readBattery(Battery& out)
{
    out = {};

    CFTypeRef info = IOPSCopyPowerSourcesInfo();
    if (info) {
        CFArrayRef sources = IOPSCopyPowerSourcesList(info);
        if (sources) {
            for (CFIndex i = 0; i < CFArrayGetCount(sources); ++i) {
                CFDictionaryRef raw = IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(sources, i));
                if (!raw)
                    continue;
                NSDictionary* d = (__bridge NSDictionary*)raw;
                if (![d[@kIOPSTypeKey] isEqual:@kIOPSInternalBatteryType])
                    continue;

                out.present = true;
                const int current = [d[@kIOPSCurrentCapacityKey] intValue];
                const int maximum = [d[@kIOPSMaxCapacityKey] intValue];
                out.percent = maximum > 0 ? qRound(100.0 * current / maximum) : current;
                out.charging = [d[@kIOPSIsChargingKey] boolValue];
                out.onAC = [d[@kIOPSPowerSourceStateKey] isEqual:@kIOPSACPowerValue];
                const int minutes = out.charging ? [d[@kIOPSTimeToFullChargeKey] intValue]
                                                 : [d[@kIOPSTimeToEmptyKey] intValue];
                out.minutesLeft = minutes > 0 ? minutes : -1;
                break;
            }
            CFRelease(sources);
        }
        CFRelease(info);
    }
    if (!out.present)
        return false;

    // Details that IOPowerSources does not expose.
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"));
    if (service) {
        CFMutableDictionaryRef props = nullptr;
        if (IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
            NSDictionary* p = (__bridge_transfer NSDictionary*)props;
            NSNumber* cycles = p[@"CycleCount"];
            NSNumber* design = p[@"DesignCapacity"];
            NSNumber* rawMax = p[@"AppleRawMaxCapacity"] ?: p[@"NominalChargeCapacity"];
            NSNumber* temperature = p[@"Temperature"];
            if (cycles)
                out.cycleCount = cycles.intValue;
            if (design.intValue > 0 && rawMax.intValue > 0)
                out.healthPercent = qMin(100, qRound(100.0 * rawMax.intValue / design.intValue));
            if (temperature)
                out.temperatureC = temperature.doubleValue / 100.0;
        }
        IOObjectRelease(service);
    }

    CFDictionaryRef adapter = IOPSCopyExternalPowerAdapterDetails();
    if (adapter) {
        NSDictionary* a = (__bridge_transfer NSDictionary*)adapter;
        out.adapterWatts = [a[@kIOPSPowerAdapterWattsKey] intValue];
    }
    return true;
}

int gpuUtilization()
{
    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) != KERN_SUCCESS)
        return -1;

    int best = -1;
    io_object_t service = 0;
    while ((service = IOIteratorNext(iterator))) {
        // Fetch only this key: the full property dictionary is large.
        CFTypeRef stats = IORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
        if (stats) {
            id object = (__bridge_transfer id)stats;
            if ([object isKindOfClass:NSDictionary.class]) {
                NSDictionary* d = object;
                NSNumber* value = d[@"Device Utilization %"] ?: d[@"GPU Activity(%)"];
                if (value)
                    best = std::max(best, value.intValue);
            }
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    return best;
}

int thermalState()
{
    return static_cast<int>(NSProcessInfo.processInfo.thermalState);
}

qint64 uptimeSeconds()
{
    timeval boot {};
    size_t size = sizeof(boot);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if (sysctl(mib, 2, &boot, &size, nullptr, 0) != 0 || boot.tv_sec == 0)
        return 0;
    timeval now {};
    gettimeofday(&now, nullptr);
    return qint64(now.tv_sec - boot.tv_sec);
}

QList<ProcessSample> ProcessSampler::sample()
{
    const qint64 wallNs = m_clock.isValid() ? m_clock.nsecsElapsed() : 0;
    m_clock.start();

    int count = proc_listallpids(nullptr, 0);
    if (count <= 0)
        return {};
    std::vector<pid_t> pids(size_t(count) + 64);
    count = proc_listallpids(pids.data(), int(pids.size() * sizeof(pid_t)));
    if (count <= 0)
        return {};

    std::unordered_map<int, uint64_t> current;
    current.reserve(size_t(count));
    QList<ProcessSample> result;
    result.reserve(count);

    for (int i = 0; i < count && i < int(pids.size()); ++i) {
        const pid_t pid = pids[size_t(i)];
        if (pid <= 0)
            continue;

        proc_taskinfo task {};
        // Fails for processes of other users (root daemons) — that's fine.
        if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, int(sizeof(task))) != int(sizeof(task)))
            continue;

        const uint64_t cpuNs = uint64_t(double(task.pti_total_user + task.pti_total_system) * machTicksToNs());
        current[pid] = cpuNs;

        ProcessSample s;
        s.pid = pid;
        s.name = nameOf(pid);
        s.memoryBytes = task.pti_resident_size;

        rusage_info_v2 usage {};
        if (proc_pid_rusage(pid, RUSAGE_INFO_V2, reinterpret_cast<rusage_info_t*>(&usage)) == 0)
            s.memoryBytes = usage.ri_phys_footprint;

        const auto previous = m_previousCpuNs.find(pid);
        if (wallNs > 0 && previous != m_previousCpuNs.end() && cpuNs >= previous->second)
            s.cpuPercent = 100.0 * double(cpuNs - previous->second) / double(wallNs);

        result.push_back(s);
    }

    m_previousCpuNs.swap(current);
    if (m_names.size() > 4 * count)
        m_names.clear();   // drop names of long-gone pids
    return result;
}

QString ProcessSampler::nameOf(int pid)
{
    const auto cached = m_names.constFind(pid);
    if (cached != m_names.constEnd())
        return cached.value();

    char path[PROC_PIDPATHINFO_MAXSIZE] = {};
    QString name;
    if (proc_pidpath(pid, path, sizeof(path)) > 0) {
        name = QString::fromUtf8(path);
        name = name.mid(name.lastIndexOf(QLatin1Char('/')) + 1);
    } else {
        char shortName[64] = {};
        proc_name(pid, shortName, sizeof(shortName));
        name = QString::fromUtf8(shortName);
    }
    m_names.insert(pid, name);
    return name;
}

QString appDisplayName(int pid)
{
    NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    return app.localizedName ? QString::fromNSString(app.localizedName) : QString();
}

QImage appIconForPid(int pid, int pixels)
{
    @autoreleasepool {
        NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        NSImage* icon = app.icon;
        if (!icon)
            return {};

        NSBitmapImageRep* rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:nullptr
                          pixelsWide:pixels
                          pixelsHigh:pixels
                       bitsPerSample:8
                     samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                      colorSpaceName:NSCalibratedRGBColorSpace
                         bytesPerRow:0
                        bitsPerPixel:0];
        if (!rep)
            return {};
        rep.size = NSMakeSize(pixels, pixels);

        [NSGraphicsContext saveGraphicsState];
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [icon drawInRect:NSMakeRect(0, 0, pixels, pixels)
                fromRect:NSZeroRect
               operation:NSCompositingOperationCopy
                fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];

        NSData* png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (!png)
            return {};
        return QImage::fromData(QByteArray::fromNSData(png), "PNG");
    }
}

} // namespace probe
