#pragma once

#include <QImage>

// What the status item shows. Drawn in black: the image is a template, so
// macOS tints it for light/dark menu bars and the selected state.
struct MenuBarValues {
    double cpu = 0;           // %
    double memory = 0;        // %
    double netIn = 0;         // bytes/s
    double netOut = 0;        // bytes/s
    int gpu = -1;             // %, -1 unknown
    int battery = -1;         // %, -1 no battery
    bool charging = false;
};

struct MenuBarOptions {
    bool cpu = true;
    bool memory = true;
    bool network = true;
    bool gpu = false;
    bool battery = false;
};

QImage renderMenuBar(const MenuBarValues& values, const MenuBarOptions& options, qreal devicePixelRatio);
