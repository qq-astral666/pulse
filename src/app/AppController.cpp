#include "AppController.h"

#include "ProcessIcons.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QScreen>
#include <QSettings>
#include <QTimer>

#include <algorithm>

namespace {

const int kIntervals[] = { 1000, 2000, 5000 };

namespace keys {
const QString barCpu = QStringLiteral("bar/cpu");
const QString barMemory = QStringLiteral("bar/memory");
const QString barNetwork = QStringLiteral("bar/network");
const QString barGpu = QStringLiteral("bar/gpu");
const QString barBattery = QStringLiteral("bar/battery");
const QString interval = QStringLiteral("intervalIndex");
const QString theme = QStringLiteral("themeMode");
const QString firstRun = QStringLiteral("firstRunDone");
} // namespace keys

} // namespace

AppController::AppController(std::shared_ptr<IconCache> icons, QObject* parent)
    : QObject(parent)
    , m_monitor(new SystemMonitor(std::move(icons), this))
{
    loadSettings();
    m_monitor->setInterval(kIntervals[m_intervalIndex]);

    connect(m_monitor, &SystemMonitor::updated, this, &AppController::updateStatusItem);
    m_statusItem.setClickHandler([this] { emit togglePopup(); });
}

AppController::~AppController() = default;

void AppController::start()
{
    m_monitor->start();
    updateStatusItem();

    QSettings settings;
    if (!settings.value(keys::firstRun, false).toBool()) {
        settings.setValue(keys::firstRun, true);
        // Let the status item get its on-screen position first.
        QTimer::singleShot(600, this, [this] { emit showPopup(); });
    }
}

bool AppController::isMac() const
{
#ifdef Q_OS_MACOS
    return true;
#else
    return false;
#endif
}

// ------------------------------------------------------------- settings --

void AppController::loadSettings()
{
    QSettings s;
    m_bar.cpu = s.value(keys::barCpu, true).toBool();
    m_bar.memory = s.value(keys::barMemory, true).toBool();
    m_bar.network = s.value(keys::barNetwork, true).toBool();
    m_bar.gpu = s.value(keys::barGpu, false).toBool();
    m_bar.battery = s.value(keys::barBattery, false).toBool();
    m_intervalIndex = qBound(0, s.value(keys::interval, 1).toInt(), 2);
    m_themeMode = qBound(0, s.value(keys::theme, 0).toInt(), 2);
}

QVariantMap AppController::bar() const
{
    return {
        { QStringLiteral("cpu"), m_bar.cpu },
        { QStringLiteral("memory"), m_bar.memory },
        { QStringLiteral("network"), m_bar.network },
        { QStringLiteral("gpu"), m_bar.gpu },
        { QStringLiteral("battery"), m_bar.battery },
    };
}

void AppController::setBarItem(const QString& key, bool enabled)
{
    bool* target = nullptr;
    QString settingsKey;
    if (key == QLatin1String("cpu")) { target = &m_bar.cpu; settingsKey = keys::barCpu; }
    else if (key == QLatin1String("memory")) { target = &m_bar.memory; settingsKey = keys::barMemory; }
    else if (key == QLatin1String("network")) { target = &m_bar.network; settingsKey = keys::barNetwork; }
    else if (key == QLatin1String("gpu")) { target = &m_bar.gpu; settingsKey = keys::barGpu; }
    else if (key == QLatin1String("battery")) { target = &m_bar.battery; settingsKey = keys::barBattery; }
    if (!target || *target == enabled)
        return;
    *target = enabled;
    QSettings().setValue(settingsKey, enabled);
    updateStatusItem();
    emit settingsChanged();
}

void AppController::setIntervalIndex(int index)
{
    index = qBound(0, index, 2);
    if (index == m_intervalIndex)
        return;
    m_intervalIndex = index;
    m_monitor->setInterval(kIntervals[index]);
    QSettings().setValue(keys::interval, index);
    emit settingsChanged();
}

void AppController::setThemeMode(int mode)
{
    mode = qBound(0, mode, 2);
    if (mode == m_themeMode)
        return;
    m_themeMode = mode;
    QSettings().setValue(keys::theme, mode);
    emit settingsChanged();
}

bool AppController::launchAtLogin() const
{
    return native::launchAtLoginEnabled();
}

void AppController::setLaunchAtLogin(bool enable)
{
    QString error;
    const bool ok = native::setLaunchAtLogin(enable, &error);
    if (!error.isEmpty())
        emit toast(error);
    else if (ok)
        emit toast(enable ? QStringLiteral("Pulse будет запускаться при входе")
                          : QStringLiteral("Автозапуск выключен"));
    emit launchAtLoginChanged();
}

// ---------------------------------------------------------------- popup --

QRect AppController::anchorRect() const
{
    const QRect r = m_statusItem.geometry();
    if (r.isValid() && !r.isEmpty())
        return r;
    // Fallback: top-right corner of the primary screen.
    const QScreen* screen = QGuiApplication::primaryScreen();
    const QRect g = screen ? screen->geometry() : QRect(0, 0, 1440, 900);
    return QRect(g.right() - 140, g.top(), 40, 24);
}

QRect AppController::availableGeometryAt(int x, int y) const
{
    QScreen* screen = QGuiApplication::screenAt(QPoint(x, y));
    if (!screen)
        screen = QGuiApplication::primaryScreen();
    return screen ? screen->availableGeometry() : QRect(0, 24, 1440, 876);
}

void AppController::bringToFront(QWindow* window)
{
    native::bringToFront(window);
}

void AppController::openActivityMonitor()
{
    native::openActivityMonitor();
}

void AppController::quit()
{
    QCoreApplication::quit();
}

// ------------------------------------------------------------ status bar --

void AppController::updateStatusItem()
{
    MenuBarValues values;
    values.cpu = m_monitor->cpuUsage();
    values.memory = m_monitor->memoryPercent();
    values.netIn = m_monitor->netIn();
    values.netOut = m_monitor->netOut();
    values.gpu = m_monitor->gpuUsage();
    values.battery = m_monitor->batteryPercent();
    values.charging = m_monitor->batteryCharging();

    const QScreen* screen = QGuiApplication::primaryScreen();
    const qreal dpr = screen ? std::max<qreal>(2.0, screen->devicePixelRatio()) : 2.0;
    m_statusItem.setImage(renderMenuBar(values, m_bar, dpr));
    m_statusItem.setToolTip(QStringLiteral("Pulse — CPU %1% · RAM %2%")
                                .arg(qRound(values.cpu))
                                .arg(qRound(values.memory)));
}
