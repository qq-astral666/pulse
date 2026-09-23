#pragma once

#include <QImage>
#include <QRect>
#include <QString>

#include <functional>
#include <memory>

class QWindow;

// Native macOS UI glue: the menu-bar status item, popup focus handling and
// login items. Native_mac.mm / Native_stub.cpp.
namespace native {

// NSStatusItem with a custom-drawn image. QSystemTrayIcon can only show a
// square icon, but we need a variable-width item with live numbers.
class StatusItem {
public:
    StatusItem();
    ~StatusItem();
    StatusItem(const StatusItem&) = delete;
    StatusItem& operator=(const StatusItem&) = delete;

    // `image` must carry its devicePixelRatio; drawn in black, used as a
    // template so macOS recolours it for light/dark menu bars.
    void setImage(const QImage& image);
    void setToolTip(const QString& text);
    void setClickHandler(std::function<void()> handler);

    // Geometry of the item in Qt global coordinates (empty if unknown).
    QRect geometry() const;

private:
    struct Impl;
    std::unique_ptr<Impl> d;
};

void bringToFront(QWindow* window);

bool launchAtLoginEnabled();
bool setLaunchAtLogin(bool enable, QString* error);

void openActivityMonitor();

} // namespace native
