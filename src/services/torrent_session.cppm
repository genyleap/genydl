/*!
 * @file        torrent_session.cppm
 * @brief       BitTorrent session manager built on libtorrent-rasterbar.
 * @details     Manages a single libtorrent session for the lifetime of the
 *              application. Provides an add/remove/control API using opaque
 *              qint64 handle IDs so libtorrent types never leak into the
 *              module interface (PIMPL pattern).
 *
 *              When GENYDL_USE_LIBTORRENT is not defined the class compiles
 *              as a stub: isAvailable() returns false and all operations
 *              are no-ops, so the rest of the codebase needs no ifdefs.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       07 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QObject>
#include <QByteArray>
#include <QString>
#include <QStringList>
#include <QTimer>

#ifndef Q_MOC_RUN
export module genydl.services.torrent_session;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

class TorrentSessionPrivate;

/**
 * @brief Application-wide BitTorrent session manager.
 *
 * Creates and owns a single libtorrent::session. Downloads are identified
 * by opaque qint64 IDs returned by addMagnet() / addTorrentFile().
 * Progress and state changes are delivered via Qt signals.
 */
GENYDL_MODULE_EXPORT class TorrentSession : public QObject {
    Q_OBJECT

    //!< @brief True when libtorrent was compiled in and the session started.
    Q_PROPERTY(bool available READ isAvailable CONSTANT)

    //!< @brief Aggregate download speed across all active torrents (bytes/sec).
    Q_PROPERTY(qint64 totalDownloadSpeed READ totalDownloadSpeed NOTIFY speedChanged)

    //!< @brief Aggregate upload speed across all active torrents (bytes/sec).
    Q_PROPERTY(qint64 totalUploadSpeed READ totalUploadSpeed NOTIFY speedChanged)

public:
    explicit TorrentSession(QObject* parent = nullptr);
    ~TorrentSession() override;

    //!< @brief Whether libtorrent is available and the session is running.
    bool isAvailable() const;

    //!< @brief Aggregate download speed in bytes/sec.
    qint64 totalDownloadSpeed() const;

    //!< @brief Aggregate upload speed in bytes/sec.
    qint64 totalUploadSpeed() const;

    /**
     * @brief Add a torrent from a magnet URI.
     * @param magnetUri  Full magnet link string.
     * @param savePath   Destination directory.
     * @return           Opaque handle ID, or -1 on failure.
     */
    Q_INVOKABLE qint64 addMagnet(const QString& magnetUri, const QString& savePath);

    /**
     * @brief Add a torrent from a .torrent file on disk.
     * @param torrentFilePath  Absolute path to the .torrent file.
     * @param savePath         Destination directory.
     * @return                 Opaque handle ID, or -1 on failure.
     */
    Q_INVOKABLE qint64 addTorrentFile(const QString& torrentFilePath, const QString& savePath);

    /**
     * @brief Pause a torrent.
     * @param id  Handle ID returned by addMagnet() / addTorrentFile().
     */
    Q_INVOKABLE void pauseTorrent(qint64 id);

    /**
     * @brief Resume a paused torrent.
     * @param id  Handle ID.
     */
    Q_INVOKABLE void resumeTorrent(qint64 id);

    /**
     * @brief Remove a torrent from the session.
     * @param id           Handle ID.
     * @param deleteFiles  If true also delete downloaded data from disk.
     */
    Q_INVOKABLE void removeTorrent(qint64 id, bool deleteFiles = false);

    /**
     * @brief Set the global session download speed cap.
     * @param bytesPerSec  0 = unlimited.
     */
    Q_INVOKABLE void setGlobalMaxDownloadSpeed(qint64 bytesPerSec);

    /**
     * @brief Set the global session upload speed cap.
     * @param bytesPerSec  0 = unlimited.
     */
    Q_INVOKABLE void setGlobalMaxUploadSpeed(qint64 bytesPerSec);

    /**
     * @brief Set the global seed-ratio limit applied to auto-managed torrents.
     * @param ratio  Upload/download ratio at which seeding stops (0 = unlimited).
     */
    Q_INVOKABLE void setSeedRatioLimit(double ratio);

    /**
     * @brief Set the global seed-time limit applied to auto-managed torrents.
     * @param minutes  Minutes to keep seeding after completion (0 = unlimited).
     */
    Q_INVOKABLE void setSeedTimeLimit(int minutes);

    /**
     * @brief Enable or disable downloading of one file within a torrent.
     * @param id         Handle ID.
     * @param fileIndex  Index into the torrent's file list.
     * @param enabled    True to download, false to skip (priority 0).
     */
    Q_INVOKABLE void setFileEnabled(qint64 id, int fileIndex, bool enabled);

signals:
    /**
     * @brief Emitted once after a torrent has been accepted by the session.
     * @param id        Handle ID.
     * @param name      Initial display name (may be empty for magnet until metadata).
     * @param savePath  Destination directory.
     */
    void torrentAdded(qint64 id, const QString& name, const QString& savePath);

    /**
     * @brief Periodic progress report for an active torrent.
     * @param id            Handle ID.
     * @param downloaded    Bytes downloaded so far.
     * @param uploaded      All-time bytes uploaded (for ratio display).
     * @param total         Total torrent size in bytes (0 if unknown).
     * @param downloadSpeed Current download speed in bytes/sec.
     * @param uploadSpeed   Current upload speed in bytes/sec.
     * @param eta           Estimated seconds to completion (−1 if unknown).
     * @param seeders       Number of seeds connected + in swarm.
     * @param leechers      Number of peers downloading + in swarm.
     * @param state         Human-readable state string.
     */
    void torrentProgress(qint64 id, qint64 downloaded, qint64 uploaded, qint64 total,
                         qint64 downloadSpeed, qint64 uploadSpeed, int eta,
                         int seeders, int leechers, const QString& state);

    /**
     * @brief Emitted when a torrent has finished downloading all pieces.
     * @param id        Handle ID.
     * @param savePath  Destination directory.
     */
    void torrentFinished(qint64 id, const QString& savePath);

    /**
     * @brief Emitted on a terminal torrent error.
     * @param id      Handle ID.
     * @param message Error description.
     */
    void torrentError(qint64 id, const QString& message);

    /**
     * @brief Emitted when torrent metadata (name + file list) becomes available.
     *        Fires for both .torrent files (immediately) and magnets (once
     *        metadata is fetched from peers).
     * @param id    Handle ID.
     * @param name  Torrent display name.
     * @param files List of files inside the torrent.
     */
    void torrentMetadataReceived(qint64 id, const QString& name, const QStringList& files);

    /**
     * @brief Periodic per-piece completion bitmap for a torrent.
     * @param id     Handle ID.
     * @param pieces One byte per piece: 1 = downloaded, 0 = missing.
     */
    void torrentPieces(qint64 id, const QByteArray& pieces);

    /**
     * @brief Emitted after a torrent has been fully removed from the session.
     * @param id  Handle ID.
     */
    void torrentRemoved(qint64 id);

    //!< @brief Emitted when aggregate speed values change.
    void speedChanged();

private slots:
    void pollAlerts();

private:
    TorrentSessionPrivate* d = nullptr;
    QTimer*                m_pollTimer = nullptr;
};

#include "torrent_session.moc"
