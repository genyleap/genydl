#pragma once

#include <QObject>
#include <QUrl>
#include <QLocalServer>
#include <QLocalSocket>
#include <QPointer>
#include <QQueue>
#include <QSet>
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
    // Hold requests until QML has connected to promptRequested at startup.
    void setFrontendReady(bool ready);
    static QUrl parseDownloadUrl(const QString& raw);
    static bool isSafeHttpUrl(const QUrl& url);
    // Browser-provided filenames are hints; discard all directory components.
    static QString safeFilename(const QString& raw);
    Q_INVOKABLE QString sanitizeFilename(const QString& raw) const
    {
        return safeFilename(raw);
    }

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
    void activateNextPrompt();
    void expirePrompt(QLocalSocket* client);

    DownloadHandler m_downloadHandler;
    QLocalServer m_server;
    // A browser may pause multiple concurrent downloads. Review requests
    // sequentially without discarding any of them or overwriting the dialog.
    struct PendingPrompt {
        QPointer<QLocalSocket> client;
        QString url;
        QString filename;
        QString requestId;
        bool localRequest = false; // Safari Services / OS protocol (no native Port)
    };
    QPointer<QLocalSocket> m_pendingPromptSocket;
    QString m_activeRequestId;
    bool m_promptTransitioning = false;
    bool m_frontendReady = true;
    bool m_localPromptActive = false;
    void scheduleNextPrompt();
    QQueue<PendingPrompt> m_promptQueue;
    QSet<QString> m_outstandingRequestIds;
    QSet<QString> m_handledRequestIds;
    QQueue<QString> m_handledRequestOrder;
};
