#pragma once

#include <QObject>
#include <QVariantList>

// Browser integration is controlled per browser by the user. Turning a
// browser on configures GenyDL's side of the link; only the browser can
// install/enable the extension and grant download-management permission.
class BrowserIntegrationManager final : public QObject
{
    Q_OBJECT
public:
    explicit BrowserIntegrationManager(QObject* parent = nullptr);

    Q_INVOKABLE QVariantList statuses() const;
    Q_INVOKABLE bool setEnabled(const QString& browser, bool enabled);
    Q_INVOKABLE bool openBrowserExtensions(const QString& browser) const;
    Q_INVOKABLE bool revealExtensionFiles(const QString& browser) const;
    Q_INVOKABLE bool openStoreListing(const QString& browser) const;
    Q_INVOKABLE void repairNativeHosts();
};
