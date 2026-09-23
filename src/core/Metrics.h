#pragma once

#include <QString>
#include <QVariantList>

#include <cstdint>
#include <deque>

// Platform-independent math and formatting. Everything here is covered by
// tests/tst_metrics.cpp.
namespace metrics {

// Fixed-size history for sparklines. Oldest values drop off the front.
template <typename T>
class RingBuffer {
public:
    explicit RingBuffer(int capacity = 120) : m_capacity(capacity > 0 ? capacity : 1) {}

    void push(T value)
    {
        m_data.push_back(value);
        while (static_cast<int>(m_data.size()) > m_capacity)
            m_data.pop_front();
    }

    void clear() { m_data.clear(); }
    int size() const { return static_cast<int>(m_data.size()); }
    int capacity() const { return m_capacity; }
    bool isEmpty() const { return m_data.empty(); }
    T last() const { return m_data.empty() ? T{} : m_data.back(); }
    const std::deque<T>& data() const { return m_data; }

    QVariantList toVariantList() const
    {
        QVariantList out;
        out.reserve(size());
        for (const T& v : m_data)
            out.push_back(QVariant::fromValue(v));
        return out;
    }

private:
    int m_capacity;
    std::deque<T> m_data;
};

// Raw scheduler ticks of one CPU core (or the sum of all cores).
struct CpuTicks {
    uint64_t user = 0;
    uint64_t system = 0;
    uint64_t idle = 0;
    uint64_t nice = 0;

    uint64_t total() const { return user + system + idle + nice; }
    CpuTicks& operator+=(const CpuTicks& o)
    {
        user += o.user;
        system += o.system;
        idle += o.idle;
        nice += o.nice;
        return *this;
    }
};

// Busy share between two snapshots, 0..1.
struct CpuLoad {
    double user = 0.0;     // user + nice
    double system = 0.0;
    double total() const { return user + system; }
};

// Returns zero load if counters went backwards (wrap-around / reset).
CpuLoad loadBetween(const CpuTicks& previous, const CpuTicks& current);

// Turns a monotonically growing byte counter into bytes per second.
class RateMeter {
public:
    // First call only primes the meter and returns 0.
    double update(uint64_t counter, qint64 elapsedMs);
    void reset() { m_hasPrevious = false; }

private:
    bool m_hasPrevious = false;
    uint64_t m_previous = 0;
};

QString formatBytes(double bytes);             // "1.4 ГБ"
QString formatRate(double bytesPerSecond);     // "1.4 МБ/с"
QString formatRateCompact(double bytesPerSecond); // "1.4M" — for the menu bar
QString formatDuration(qint64 seconds);        // "3 д 4 ч", "5 ч 12 мин", "7 мин"

} // namespace metrics
