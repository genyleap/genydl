#pragma once

#include <QObject>
#include <QUrl>
#include <QLocalServer>
#include <functional>

// Desktop entry point for browser-originated links. Transport is restricted to
// the current user, and callers never control destination filesystem paths.
class BrowserActivation final : public QObject
{
public:
    using DownloadHandler = std::function<bool(const QUrl&)>;
    explicit BrowserActivation(DownloadHandler handler, QObject* parent = nullptr);

    // Returns false when an already running instance accepted the activation.
    bool start(const QStringList& arguments);
    static QString socketName();
    bool submitUrl(const QString& value);
    static QUrl parseDownloadUrl(const QString& raw);
    static bool isSafeHttpUrl(const QUrl& url);

protected:
    bool eventFilter(QObject* object, QEvent* event) override;

private:
    bool deliverToRunningInstance(const QStringList& arguments);
    bool deliver(const QString& url);
    void onConnection();

    DownloadHandler m_downloadHandler;
    QLocalServer m_server;
};
