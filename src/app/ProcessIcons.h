#pragma once

#include <QHash>
#include <QImage>
#include <QMutex>
#include <QQuickImageProvider>
#include <QSet>

#include <memory>

// App icons of running processes. Filled on the GUI thread (AppKit is not
// thread-safe), read by the QML image loader threads.
class IconCache {
public:
    // Loads the icon of `pid` if needed. Returns true if the pid has one.
    bool ensure(int pid);
    QImage get(int pid) const;

private:
    mutable QMutex m_mutex;
    QHash<int, QImage> m_images;
    QSet<int> m_missing;
};

// image://proc/<pid>
class ProcessIconProvider : public QQuickImageProvider {
public:
    explicit ProcessIconProvider(std::shared_ptr<IconCache> cache);
    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;

private:
    std::shared_ptr<IconCache> m_cache;
};
