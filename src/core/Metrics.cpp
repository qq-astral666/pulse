#include "Metrics.h"

#include <QStringList>

#include <cmath>

namespace metrics {

CpuLoad loadBetween(const CpuTicks& previous, const CpuTicks& current)
{
    if (current.user < previous.user || current.system < previous.system
        || current.idle < previous.idle || current.nice < previous.nice)
        return {};

    const double user = double(current.user - previous.user);
    const double system = double(current.system - previous.system);
    const double idle = double(current.idle - previous.idle);
    const double nice = double(current.nice - previous.nice);
    const double total = user + system + idle + nice;
    if (total <= 0.0)
        return {};

    CpuLoad load;
    load.user = (user + nice) / total;
    load.system = system / total;
    return load;
}

double RateMeter::update(uint64_t counter, qint64 elapsedMs)
{
    if (!m_hasPrevious || counter < m_previous) {
        // First sample, or the counter was reset (interface re-created).
        m_previous = counter;
        m_hasPrevious = true;
        return 0.0;
    }
    const uint64_t delta = counter - m_previous;
    m_previous = counter;
    if (elapsedMs <= 0)
        return 0.0;
    return double(delta) * 1000.0 / double(elapsedMs);
}

namespace {

QString scaled(double value, const QStringList& units, double base, bool compact)
{
    int unit = 0;
    while (std::abs(value) >= base && unit < units.size() - 1) {
        value /= base;
        ++unit;
    }
    int decimals = 1;
    if (unit == 0 || std::abs(value) >= 100.0)
        decimals = 0;
    const QString number = QString::number(value, 'f', decimals);
    return compact ? number + units.at(unit) : number + QLatin1Char(' ') + units.at(unit);
}

} // namespace

QString formatBytes(double bytes)
{
    static const QStringList units = { QStringLiteral("Б"), QStringLiteral("КБ"), QStringLiteral("МБ"),
                                       QStringLiteral("ГБ"), QStringLiteral("ТБ") };
    return scaled(bytes, units, 1024.0, false);
}

QString formatRate(double bytesPerSecond)
{
    static const QStringList units = { QStringLiteral("Б/с"), QStringLiteral("КБ/с"), QStringLiteral("МБ/с"),
                                       QStringLiteral("ГБ/с") };
    return scaled(bytesPerSecond, units, 1024.0, false);
}

QString formatRateCompact(double bytesPerSecond)
{
    static const QStringList units = { QStringLiteral("B"), QStringLiteral("K"), QStringLiteral("M"),
                                       QStringLiteral("G") };
    return scaled(bytesPerSecond, units, 1024.0, true);
}

QString formatDuration(qint64 seconds)
{
    if (seconds < 0)
        seconds = 0;
    const qint64 days = seconds / 86400;
    const qint64 hours = (seconds % 86400) / 3600;
    const qint64 minutes = (seconds % 3600) / 60;
    if (days > 0)
        return QStringLiteral("%1 д %2 ч").arg(days).arg(hours);
    if (hours > 0)
        return QStringLiteral("%1 ч %2 мин").arg(hours).arg(minutes);
    return QStringLiteral("%1 мин").arg(minutes);
}

} // namespace metrics
