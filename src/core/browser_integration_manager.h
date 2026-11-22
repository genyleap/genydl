#pragma once

#include <QObject>
#include <QVariantList>

// Explicit user-controlled native host setup. Host registration never
// installs an extension, changes browser policies, or grants site permissions.
class BrowserIntegrationManager final : public QObject
{
    Q_OBJECT
public:
    explicit BrowserIntegrationManager(QObject* parent = nullptr);

    // "Registered" means the manifest points to this GenyDL build, NOT that
    // the extension is installed or that browser permission was granted.
    Q_INVOKABLE QVariantList statuses() const;
    Q_INVOKABLE bool registerExtensionId(const QString& browser, const QString& id);
    Q_INVOKABLE void repairNativeHosts();
};
