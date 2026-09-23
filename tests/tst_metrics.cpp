#include "Metrics.h"

#include <QtTest>

using namespace metrics;

class TestMetrics : public QObject {
    Q_OBJECT

private slots:
    void ringBufferKeepsNewest()
    {
        RingBuffer<double> rb(3);
        for (int i = 1; i <= 5; ++i)
            rb.push(i);
        QCOMPARE(rb.size(), 3);
        QCOMPARE(rb.data().front(), 3.0);
        QCOMPARE(rb.last(), 5.0);
        QCOMPARE(rb.toVariantList().size(), 3);
    }

    void cpuLoadSplitsUserAndSystem()
    {
        CpuTicks a { 100, 50, 850, 0 };
        CpuTicks b { 130, 60, 910, 0 };   // +30 user, +10 sys, +60 idle
        const CpuLoad l = loadBetween(a, b);
        QCOMPARE(qRound(l.user * 100), 30);
        QCOMPARE(qRound(l.system * 100), 10);
        QCOMPARE(qRound(l.total() * 100), 40);
    }

    void cpuLoadCountsNiceAsUser()
    {
        const CpuLoad l = loadBetween({ 0, 0, 0, 0 }, { 10, 0, 80, 10 });
        QCOMPARE(qRound(l.user * 100), 20);
    }

    void cpuLoadSurvivesWrapAround()
    {
        const CpuLoad l = loadBetween({ 1000, 1000, 1000, 0 }, { 5, 5, 5, 0 });
        QCOMPARE(l.total(), 0.0);
    }

    void rateMeterPrimesThenMeasures()
    {
        RateMeter m;
        QCOMPARE(m.update(1000, 1000), 0.0);
        QCOMPARE(m.update(3048, 1000), 2048.0);
        QCOMPARE(m.update(4072, 500), 2048.0);   // 1024 bytes in 0.5 s
    }

    void rateMeterHandlesCounterReset()
    {
        RateMeter m;
        m.update(5000, 1000);
        QCOMPARE(m.update(100, 1000), 0.0);
        QCOMPARE(m.update(1124, 1000), 1024.0);
    }

    void formatting()
    {
        QCOMPARE(formatBytes(512), QStringLiteral("512 Б"));
        QCOMPARE(formatBytes(1536), QStringLiteral("1.5 КБ"));
        QCOMPARE(formatBytes(16.0 * 1024 * 1024 * 1024), QStringLiteral("16.0 ГБ"));
        QCOMPARE(formatBytes(250.0 * 1024 * 1024), QStringLiteral("250 МБ"));
        QCOMPARE(formatRate(2.5 * 1024 * 1024), QStringLiteral("2.5 МБ/с"));
        QCOMPARE(formatRateCompact(900), QStringLiteral("900B"));
        QCOMPARE(formatRateCompact(1.2 * 1024 * 1024), QStringLiteral("1.2M"));
        QCOMPARE(formatDuration(59), QStringLiteral("0 мин"));
        QCOMPARE(formatDuration(3 * 3600 + 5 * 60), QStringLiteral("3 ч 5 мин"));
        QCOMPARE(formatDuration(2 * 86400 + 4 * 3600), QStringLiteral("2 д 4 ч"));
    }
};

QTEST_GUILESS_MAIN(TestMetrics)
#include "tst_metrics.moc"
