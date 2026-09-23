#include "AppController.h"
#include "ProcessIcons.h"

#include <QDebug>
#include <QDir>
#include <QGuiApplication>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QStandardPaths>

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Pulse"));
    QGuiApplication::setOrganizationName(QStringLiteral("Pulse"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("pulsebar.app"));
    QGuiApplication::setApplicationVersion(QStringLiteral(PROJECT_VERSION_STRING));
    QGuiApplication::setQuitOnLastWindowClosed(false);   // lives in the menu bar

    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);
    QLockFile instanceLock(dataDir + QStringLiteral("/instance.lock"));
    if (!instanceLock.tryLock(100)) {
        qWarning() << "Pulse is already running";
        return 0;
    }

    auto icons = std::make_shared<IconCache>();
    AppController controller(icons);

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("proc"), new ProcessIconProvider(icons));
    engine.setInitialProperties({ { QStringLiteral("controller"), QVariant::fromValue(&controller) } });
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Pulse", "Main");

    controller.start();
    return app.exec();
}
