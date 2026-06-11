/*!
 * @file        torrenttask.cppm
 * @brief       BitTorrent download task wrapping a TorrentSession handle.
 * @details     TorrentTask exposes the same Qt signals and properties that
 *              DownloadModel and DownloadManager expect from DownloaderTask,
 *              so the existing UI layer works with both HTTP and torrent
 *              downloads without modification.
 *
 *              Additional torrent-specific properties (seeders, leechers,
 *              upload speed, file list) are also exposed for richer display.
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
#include <QVariantList>

#ifndef Q_MOC_RUN
#  include <QtCore/qtmochelpers.h>
export module genydl.core.torrenttask;
import genydl.services.torrent_session;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

/**
 * @brief Represents one BitTorrent download inside the download manager.
 *
 * Connects to TorrentSession signals and translates them into the same
 * Qt property / signal surface that DownloaderTask provides, enabling
 * seamless display in the existing DownloadModel / DownloadDelegate UI.
 */
GENYDL_MODULE_EXPORT class TorrentTask : public QObject {
    Q_OBJECT

    // ---- Properties shared with DownloaderTask (UI compat) ----

    //!< @brief Human-readable state string (same values as DownloaderTask).
    Q_PROPERTY(QString stateString READ stateString NOTIFY stateChanged)

    //!< @brief Current download speed in bytes/sec.
    Q_PROPERTY(qint64 speed READ speed NOTIFY speedChanged)

    //!< @brief Estimated time to completion in seconds (−1 if unknown).
    Q_PROPERTY(int eta READ eta NOTIFY etaChanged)

    //!< @brief Last non-zero speed (shown while task is paused/queued).
    Q_PROPERTY(qint64 lastSpeed READ lastSpeed NOTIFY lastSpeedChanged)

    //!< @brief Last non-negative ETA.
    Q_PROPERTY(int lastEta READ lastEta NOTIFY lastEtaChanged)

    //!< @brief Always 0 – torrents do not use HTTP segments.
    Q_PROPERTY(int effectiveSegments READ effectiveSegments CONSTANT)

    //!< @brief Max download speed cap in bytes/sec (0 = managed by session).
    Q_PROPERTY(qint64 maxSpeed READ maxSpeed WRITE setMaxSpeed NOTIFY maxSpeedChanged)

    //!< @brief Task scheduling priority.
    Q_PROPERTY(int priority READ priority WRITE setPriority NOTIFY priorityChanged)

    //!< @brief Always true – used by the UI to adapt the display.
    Q_PROPERTY(bool isTorrent READ isTorrent CONSTANT)

    //!< @brief Pause time in epoch milliseconds (0 if not paused).
    Q_PROPERTY(qint64 pausedAt READ pausedAt NOTIFY pausedAtChanged)

    //!< @brief Reason the task is paused, if any.
    Q_PROPERTY(QString pauseReason READ pauseReason NOTIFY pauseReasonChanged)

    //!< @brief Speed history samples (mirrors DownloaderTask::speedHistory).
    Q_PROPERTY(QVariantList speedHistory READ speedHistory NOTIFY speedHistoryChanged)

    // ---- Torrent-specific properties ----

    //!< @brief Number of seeds connected + in the swarm.
    Q_PROPERTY(int seeders READ seeders NOTIFY peersChanged)

    //!< @brief Number of leeching peers connected + in the swarm.
    Q_PROPERTY(int leechers READ leechers NOTIFY peersChanged)

    //!< @brief Upload speed in bytes/sec.
    Q_PROPERTY(qint64 uploadSpeed READ uploadSpeed NOTIFY uploadSpeedChanged)

    //!< @brief All-time uploaded bytes.
    Q_PROPERTY(qint64 uploadedBytes READ uploadedBytes NOTIFY uploadedChanged)

    //!< @brief Share ratio (uploaded / downloaded).
    Q_PROPERTY(double shareRatio READ shareRatio NOTIFY uploadedChanged)

    //!< @brief Files contained in this torrent.
    Q_PROPERTY(QStringList fileList READ fileList NOTIFY fileListChanged)

    //!< @brief Opaque session handle ID.
    Q_PROPERTY(qint64 handleId READ handleId CONSTANT)

public:
    /**
     * @brief Construct a new torrent task.
     * @param handleId   Opaque ID returned by TorrentSession::addMagnet / addTorrentFile.
     * @param session    Owning TorrentSession – must outlive this task.
     * @param source     Original magnet URI or .torrent file path.
     * @param savePath   Destination directory.
     * @param parent     Optional QObject parent.
     */
    explicit TorrentTask(qint64 handleId,
                         TorrentSession* session,
                         const QString& source,
                         const QString& savePath,
                         QObject* parent = nullptr);

    // ---- DownloaderTask-compatible interface ----

    //!< @brief Display name – torrent name or save path basename.
    Q_INVOKABLE QString fileName() const;

    //!< @brief Original source (magnet URI or .torrent path).
    Q_INVOKABLE QString url() const;

    //!< @brief Destination directory for this torrent.
    Q_INVOKABLE QString savePath() const { return m_savePath; }

    //!< @brief Human-readable state string.
    QString stateString()      const { return m_stateString; }

    //!< @brief Current download speed.
    qint64  speed()            const { return m_speed;  }

    //!< @brief Estimated seconds to completion.
    int     eta()              const { return m_eta;    }

    //!< @brief Last recorded speed.
    qint64  lastSpeed()        const { return m_lastSpeed; }

    //!< @brief Last recorded ETA.
    int     lastEta()          const { return m_lastEta;   }

    //!< @brief Always 0 – no HTTP segments.
    int     effectiveSegments() const { return 0; }

    //!< @brief Max speed cap.
    qint64  maxSpeed()         const { return m_maxSpeed; }

    //!< @brief Task priority.
    int     priority()         const { return m_priority; }

    //!< @brief Whether the task is actively downloading.
    bool    isRunning()        const;

    //!< @brief Whether the task is idle / queued.
    bool    isIdle()           const;

    //!< @brief Pause timestamp in epoch ms.
    qint64  pausedAt()         const { return m_pausedAt;    }

    //!< @brief Reason for being paused.
    QString pauseReason()      const { return m_pauseReason; }

    //!< @brief Speed history samples.
    QVariantList speedHistory() const { return m_speedHistory; }

    //!< @brief Always returns true.
    bool isTorrent() const { return true; }

    //!< @brief Session handle ID.
    qint64 handleId() const { return m_handleId; }

    // ---- Torrent-specific ----

    //!< @brief Seeds in swarm.
    int     seeders()          const { return m_seeders;     }

    //!< @brief Leechers in swarm.
    int     leechers()         const { return m_leechers;    }

    //!< @brief Upload speed.
    qint64  uploadSpeed()      const { return m_uploadSpeed; }

    //!< @brief All-time uploaded bytes.
    qint64  uploadedBytes()    const { return m_uploaded; }

    //!< @brief Share ratio (uploaded / downloaded), 0 when nothing downloaded yet.
    double  shareRatio()       const {
        return m_received > 0 ? static_cast<double>(m_uploaded) / static_cast<double>(m_received) : 0.0;
    }

    //!< @brief File list (populated after metadata is received).
    QStringList fileList()     const { return m_fileList;    }

    /**
     * @brief Enable or disable downloading of one file in a multi-file torrent.
     * @param fileIndex Index into fileList().
     * @param enabled   True to download, false to skip.
     */
    Q_INVOKABLE void setFileEnabled(int fileIndex, bool enabled);

    /**
     * @brief Downsample the per-piece completion bitmap into N buckets for a
     *        compact piece-map UI.
     * @param buckets Number of cells to produce.
     * @return List of doubles in [0,1] = fraction of pieces complete per cell.
     */
    Q_INVOKABLE QVariantList pieceMap(int buckets) const;

    //!< @brief Number of pieces currently known (0 before metadata).
    int pieceCount() const { return m_pieces.size(); }

    // ---- Control ----

    //!< @brief Start / resume the download.
    Q_INVOKABLE void start();

    //!< @brief Pause the download.
    Q_INVOKABLE void pause();

    //!< @brief Resume a paused download.
    Q_INVOKABLE void resume();

    //!< @brief Cancel and remove the download.
    Q_INVOKABLE void cancel();

    /**
     * @brief Apply a per-task download speed cap.
     * @param v Bytes/sec (0 = managed by session global limit).
     */
    void setMaxSpeed(qint64 v);

    /**
     * @brief Set task priority.
     * @param p Higher value = earlier scheduling.
     */
    void setPriority(int p);

signals:
    // ---- Signals shared with DownloaderTask ----

    //!< @brief Emitted on progress updates.
    void progress(qint64 received, qint64 total);

    //!< @brief Emitted on completion or fatal error.
    void finished(bool success);

    //!< @brief Emitted when the state string changes.
    void stateChanged();

    void speedChanged();
    void etaChanged();
    void lastSpeedChanged();
    void lastEtaChanged();
    void maxSpeedChanged();
    void priorityChanged();
    void pausedAtChanged();
    void pauseReasonChanged();
    void speedHistoryChanged();

    // ---- Torrent-specific signals ----

    void peersChanged();
    void uploadSpeedChanged();
    void uploadedChanged();
    void fileListChanged();
    void fileNameChanged();
    void piecesChanged();

private slots:
    void onSessionProgress(qint64 id, qint64 downloaded, qint64 uploaded, qint64 total,
                           qint64 dlSpeed, qint64 ulSpeed, int eta,
                           int seeders, int leechers, const QString& state);
    void onSessionPieces(qint64 id, const QByteArray& pieces);
    void onSessionFinished(qint64 id, const QString& savePath);
    void onSessionError(qint64 id, const QString& message);
    void onSessionAdded(qint64 id, const QString& name, const QString& savePath);
    void onMetadataReceived(qint64 id, const QString& name, const QStringList& files);

private:
    qint64          m_handleId;
    TorrentSession* m_session;
    QString         m_source;      // magnet URI or .torrent path
    QString         m_savePath;
    QString         m_name;
    QString         m_stateString  = QStringLiteral("Queued");
    qint64          m_speed        = 0;
    qint64          m_uploadSpeed  = 0;
    int             m_eta          = -1;
    qint64          m_lastSpeed    = 0;
    int             m_lastEta      = -1;
    qint64          m_received     = 0;
    qint64          m_uploaded     = 0;
    qint64          m_total        = 0;
    qint64          m_maxSpeed     = 0;
    int             m_priority     = 0;
    int             m_seeders      = 0;
    int             m_leechers     = 0;
    qint64          m_pausedAt     = 0;
    QString         m_pauseReason;
    QStringList     m_fileList;
    QByteArray      m_pieces;        // one byte per piece: 1 = complete
    QVariantList    m_speedHistory;
    bool            m_finished     = false;
    bool            m_isPaused     = false;

    void appendSpeedSample(qint64 bps);
};

#include "torrenttask.moc"
