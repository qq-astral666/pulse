#pragma once

#include "MenuBarRenderer.h"
#include "Native.h"
#include "SystemMonitor.h"

#include <QObject>
#include <QRect>
#include <QVariantMap>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

#include <memory>

class IconCache;

// Owns the monitor and the status item, keeps settings, and is the single
// object the QML popup talks to.
class AppController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Created in main.cpp")

    Q_PROPERTY(SystemMonitor* monitor READ monitor CONSTANT)
    Q_PROPERTY(bool isMac READ isMac CONSTANT)
    Q_PROPERTY(QVariantMap bar READ bar NOTIFY settingsChanged)
    Q_PROPERTY(int intervalIndex READ intervalIndex WRITE setIntervalIndex NOTIFY settingsChanged)
    Q_PROPERTY(int themeMode READ themeMode WRITE setThemeMode NOTIFY settingsChanged)
    Q_PROPERTY(bool launchAtLogin READ launchAtLogin WRITE setLaunchAtLogin NOTIFY launchAtLoginChanged)

public:
    AppController(std::shared_ptr<IconCache> icons, QObject* parent = nullptr);
    ~AppController() override;

    void start();

    SystemMonitor* monitor() const { return m_monitor; }
    bool isMac() const;

    QVariantMap bar() const;
    Q_INVOKABLE void setBarItem(const QString& key, bool enabled);

    int intervalIndex() const { return m_intervalIndex; }
    void setIntervalIndex(int index);
    int themeMode() const { return m_themeMode; }
    void setThemeMode(int mode);
    bool launchAtLogin() const;
    void setLaunchAtLogin(bool enable);

    // Popup placement: where the status item is, and the screen around it.
    Q_INVOKABLE QRect anchorRect() const;
    Q_INVOKABLE QRect availableGeometryAt(int x, int y) const;
    Q_INVOKABLE void bringToFront(QWindow* window);

    Q_INVOKABLE void openActivityMonitor();
    Q_INVOKABLE void quit();

signals:
    void togglePopup();
    void showPopup();
    void toast(const QString& message);
    void settingsChanged();
    void launchAtLoginChanged();

private:
    void updateStatusItem();
    void loadSettings();

    SystemMonitor* m_monitor;
    native::StatusItem m_statusItem;
    MenuBarOptions m_bar;
    int m_intervalIndex = 0;
    int m_themeMode = 0;
};
