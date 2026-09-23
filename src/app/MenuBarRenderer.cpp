#include "MenuBarRenderer.h"

#include "Metrics.h"

#include <QFontMetricsF>
#include <QGuiApplication>
#include <QList>
#include <QPainter>
#include <QPainterPath>
#include <QtMath>

#include <algorithm>

namespace {

constexpr qreal kHeight = 22.0;
constexpr qreal kGap = 9.0;
constexpr qreal kPadding = 2.0;

struct Block {
    enum Kind { Stat, Network } kind = Stat;
    QString top;      // label (Stat) or upload (Network)
    QString bottom;   // value (Stat) or download (Network)
    qreal width = 0;
};

QFont baseFont()
{
    QFont f = QGuiApplication::font();
    f.setHintingPreference(QFont::PreferNoHinting);
    // Tabular digits: numbers don't make the item jitter every second.
    f.setFeature(QFont::Tag("tnum"), 1);
    return f;
}

QFont labelFont()
{
    QFont f = baseFont();
    f.setPixelSize(8);
    f.setWeight(QFont::Bold);
    f.setLetterSpacing(QFont::AbsoluteSpacing, 0.4);
    return f;
}

QFont valueFont()
{
    QFont f = baseFont();
    f.setPixelSize(11);
    f.setWeight(QFont::DemiBold);
    return f;
}

QFont networkFont()
{
    QFont f = baseFont();
    f.setPixelSize(9);
    f.setWeight(QFont::DemiBold);
    return f;
}

QString percent(double v)
{
    return QString::number(qBound(0, qRound(v), 100)) + QLatin1Char('%');
}

void drawLogo(QPainter& p, const QRectF& r)
{
    // A heartbeat line — the app's glyph when no metric is enabled.
    QPainterPath path;
    const qreal y = r.center().y();
    path.moveTo(r.left(), y);
    path.lineTo(r.left() + r.width() * 0.28, y);
    path.lineTo(r.left() + r.width() * 0.40, r.top() + 3);
    path.lineTo(r.left() + r.width() * 0.58, r.bottom() - 3);
    path.lineTo(r.left() + r.width() * 0.70, y);
    path.lineTo(r.right(), y);
    QPen pen(Qt::black, 1.7);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    p.drawPath(path);
}

} // namespace

QImage renderMenuBar(const MenuBarValues& v, const MenuBarOptions& o, qreal dpr)
{
    const QFont label = labelFont();
    const QFont value = valueFont();
    const QFont net = networkFont();
    const QFontMetricsF labelFm(label);
    const QFontMetricsF valueFm(value);
    const QFontMetricsF netFm(net);

    // Widths are measured on the widest possible text so the item keeps a
    // constant size.
    const qreal statWidth = std::max(labelFm.horizontalAdvance(QStringLiteral("CPU")),
                                     valueFm.horizontalAdvance(QStringLiteral("100%")));
    const qreal netWidth = netFm.horizontalAdvance(QStringLiteral("↓ 999.9K"));

    QList<Block> blocks;
    if (o.cpu)
        blocks.push_back({ Block::Stat, QStringLiteral("CPU"), percent(v.cpu), statWidth });
    if (o.gpu && v.gpu >= 0)
        blocks.push_back({ Block::Stat, QStringLiteral("GPU"), percent(v.gpu), statWidth });
    if (o.memory)
        blocks.push_back({ Block::Stat, QStringLiteral("RAM"), percent(v.memory), statWidth });
    if (o.network) {
        blocks.push_back({ Block::Network,
                           QStringLiteral("↑ ") + metrics::formatRateCompact(v.netOut),
                           QStringLiteral("↓ ") + metrics::formatRateCompact(v.netIn),
                           netWidth });
    }
    if (o.battery && v.battery >= 0) {
        blocks.push_back({ Block::Stat, v.charging ? QStringLiteral("BAT ⚡") : QStringLiteral("BAT"),
                           percent(v.battery), statWidth });
    }

    qreal width = kPadding * 2;
    if (blocks.isEmpty()) {
        width = 20;
    } else {
        for (const Block& b : blocks)
            width += b.width;
        width += kGap * (blocks.size() - 1);
    }

    QImage image(QSize(qCeil(width * dpr), qCeil(kHeight * dpr)), QImage::Format_ARGB32_Premultiplied);
    image.setDevicePixelRatio(dpr);
    image.fill(Qt::transparent);

    QPainter p(&image);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);

    if (blocks.isEmpty()) {
        drawLogo(p, QRectF(2, 4, 16, 14));
        p.end();
        return image;
    }

    p.setPen(Qt::black);
    qreal x = kPadding;
    for (const Block& b : blocks) {
        if (b.kind == Block::Stat) {
            p.setFont(label);
            p.drawText(QRectF(x, 0.5, b.width, 9), Qt::AlignHCenter | Qt::AlignVCenter, b.top);
            p.setFont(value);
            p.drawText(QRectF(x, 8.5, b.width, 13), Qt::AlignHCenter | Qt::AlignVCenter, b.bottom);
        } else {
            p.setFont(net);
            p.drawText(QRectF(x, 1, b.width, 10), Qt::AlignLeft | Qt::AlignVCenter, b.top);
            p.drawText(QRectF(x, 11, b.width, 10), Qt::AlignLeft | Qt::AlignVCenter, b.bottom);
        }
        x += b.width + kGap;
    }
    p.end();
    return image;
}
