// Compiled as Objective-C++ with ARC.

#include "Native.h"

#include <QWindow>

#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>

@interface PulseStatusTarget : NSObject {
@public
    std::function<void()> handler;
}
- (void)clicked:(id)sender;
@end

@implementation PulseStatusTarget
- (void)clicked:(id)sender
{
    (void)sender;
    if (handler)
        handler();
}
@end

namespace native {

struct StatusItem::Impl {
    NSStatusItem* item = nil;
    PulseStatusTarget* target = nil;
};

StatusItem::StatusItem()
    : d(std::make_unique<Impl>())
{
    d->item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    d->target = [PulseStatusTarget new];
    NSStatusBarButton* button = d->item.button;
    button.target = d->target;
    button.action = @selector(clicked:);
    [button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
    button.imagePosition = NSImageOnly;
}

StatusItem::~StatusItem()
{
    if (d->item)
        [NSStatusBar.systemStatusBar removeStatusItem:d->item];
}

void StatusItem::setImage(const QImage& image)
{
    if (image.isNull())
        return;
    const QImage source = image.format() == QImage::Format_ARGB32_Premultiplied
        ? image
        : image.convertToFormat(QImage::Format_ARGB32_Premultiplied);
    CGImageRef cg = source.toCGImage();
    if (!cg)
        return;
    const qreal dpr = image.devicePixelRatio() > 0 ? image.devicePixelRatio() : 1.0;
    NSImage* ns = [[NSImage alloc] initWithCGImage:cg
                                              size:NSMakeSize(image.width() / dpr, image.height() / dpr)];
    CGImageRelease(cg);
    [ns setTemplate:YES];   // "template" is a C++ keyword, so no dot-syntax here
    d->item.button.image = ns;
}

void StatusItem::setToolTip(const QString& text)
{
    d->item.button.toolTip = text.toNSString();
}

void StatusItem::setClickHandler(std::function<void()> handler)
{
    d->target->handler = std::move(handler);
}

QRect StatusItem::geometry() const
{
    NSStatusBarButton* button = d->item.button;
    NSWindow* window = button.window;
    if (!window)
        return {};
    const NSRect r = [window convertRectToScreen:[button convertRect:button.bounds toView:nil]];
    // Cocoa: origin bottom-left of the primary screen. Qt: top-left.
    const CGFloat primaryHeight = NSScreen.screens.firstObject.frame.size.height;
    return QRect(qRound(r.origin.x), qRound(primaryHeight - r.origin.y - r.size.height),
                 qRound(r.size.width), qRound(r.size.height));
}

void bringToFront(QWindow* window)
{
    if (!window)
        return;
    NSView* view = (__bridge NSView*)reinterpret_cast<void*>(window->winId());
    NSWindow* nsWindow = view.window;
    if (!nsWindow)
        return;

    // Qt::Tool -> NSPanel, which hides whenever the app is inactive; a
    // menu-bar agent often is not activated on macOS 14+, so keep it visible.
    nsWindow.hidesOnDeactivate = NO;
    nsWindow.level = NSPopUpMenuWindowLevel;
    nsWindow.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
                                | NSWindowCollectionBehaviorFullScreenAuxiliary;
    nsWindow.hasShadow = NO;   // QML draws a softer one

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSApp activateIgnoringOtherApps:YES];
#pragma clang diagnostic pop
    if (@available(macOS 14.0, *))
        [NSApp activate];
    [nsWindow orderFrontRegardless];
    [nsWindow makeKeyAndOrderFront:nil];
}

bool launchAtLoginEnabled()
{
    if (@available(macOS 13.0, *)) {
        const SMAppServiceStatus status = SMAppService.mainAppService.status;
        return status == SMAppServiceStatusEnabled || status == SMAppServiceStatusRequiresApproval;
    }
    return false;
}

bool setLaunchAtLogin(bool enable, QString* error)
{
    if (@available(macOS 13.0, *)) {
        SMAppService* service = SMAppService.mainAppService;
        NSError* err = nil;
        const BOOL ok = enable ? [service registerAndReturnError:&err] : [service unregisterAndReturnError:&err];
        if (!ok) {
            if (error)
                *error = QString::fromNSString(err.localizedDescription ?: @"unknown error");
            return false;
        }
        if (enable && service.status == SMAppServiceStatusRequiresApproval) {
            [SMAppService openSystemSettingsLoginItems];
            if (error)
                *error = QStringLiteral("Подтверди Pulse в «Объектах входа»");
        }
        return true;
    }
    if (error)
        *error = QStringLiteral("Нужна macOS 13 или новее");
    return false;
}

void openActivityMonitor()
{
    NSURL* url = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.apple.ActivityMonitor"];
    if (url)
        [NSWorkspace.sharedWorkspace openApplicationAtURL:url
                                            configuration:[NSWorkspaceOpenConfiguration configuration]
                                        completionHandler:nil];
}

} // namespace native
