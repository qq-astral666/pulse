#include "ProcessIcons.h"

#include "Probe.h"

#include <QMutexLocker>

namespace {
constexpr int kIconPixels = 64;
constexpr int kMaxCached = 256;
}

bool IconCache::ensure(int pid)
{
    {
        QMutexLocker lock(&m_mutex);
        if (m_images.contains(pid))
            return true;
        if (m_missing.contains(pid))
            return false;
    }

    const QImage icon = probe::appIconForPid(pid, kIconPixels);

    QMutexLocker lock(&m_mutex);
    if (m_images.size() > kMaxCached) {
        m_images.clear();
        m_missing.clear();
    }
    if (icon.isNull()) {
        m_missing.insert(pid);
        return false;
    }
    m_images.insert(pid, icon);
    return true;
}

QImage IconCache::get(int pid) const
{
    QMutexLocker lock(&m_mutex);
    return m_images.value(pid);
}

ProcessIconProvider::ProcessIconProvider(std::shared_ptr<IconCache> cache)
    : QQuickImageProvider(QQuickImageProvider::Image)
    , m_cache(std::move(cache))
{
}

QImage ProcessIconProvider::requestImage(const QString& id, QSize* size, const QSize& requestedSize)
{
    QImage image = m_cache->get(id.toInt());
    if (!image.isNull() && requestedSize.width() > 0 && requestedSize.height() > 0)
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    if (size)
        *size = image.size();
    return image;
}
