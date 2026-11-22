#pragma once

#include <QObject>
#include <QUrl>
#include <QLocalServer>
#include <QLocalSocket>
#include <QPointer>
#include <functional>

// Desktop entry point for browser-originated links. Transport is restricted to
// the current user, and callers never control destination filesystem paths.
class BrowserActivation final : public QObject
{
    Q_OBJECT
public:
    using DownloadHandler = std::function<bool(const QUrl&, const QString&)>;
    explicit BrowserActivation(DownloadHandler handler, QObject* parent = nullptr);

    // Returns false when an already running instance accepted the activation.
    bool start(const QStringList& arguments);
    static QString socketName();
    bool submitUrl(const QString& value);
    // Resolves a browser handoff only after the user accepts/cancels the GUI dialog.
    Q_INVOKABLE void finishPrompt(bool accepted);
    static QUrl parseDownloadUrl(const QString& raw);
    static bool isSafeHttpUrl(const QUrl& url);
    // Browser-provided filenames are hints; discard all directory components.
    static QString safeFilename(const QString& raw);

signals:
    void promptRequested(const QString& url, const QString& filename);
    // Browser disconnected or timed out before making a decision.
    void promptAborted();

protected:
    bool eventFilter(QObject* object, QEvent* event) override;

private:
    bool deliverToRunningInstance(const QStringList& arguments);
    bool deliver(const QString& url, const QString& filename = {});
    void onConnection();

    DownloadHandler m_downloadHandler;
    QLocalServer m_server;
    QPointer<QLocalSocket> m_pendingPromptSocket;
};
