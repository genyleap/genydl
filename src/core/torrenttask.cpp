module;
#include <QDateTime>
#include <QDebug>
#include <QFileInfo>
#include <QVariant>

module genydl.core.torrenttask;

TorrentTask::TorrentTask(qint64 handleId,
                         TorrentSession* session,
                         const QString& source,
                         const QString& savePath,
                         QObject* parent)
    : QObject(parent)
    , m_handleId(handleId)
    , m_session(session)
    , m_source(source)
    , m_savePath(savePath)
{
    if (!m_session) return;

    connect(m_session, &TorrentSession::torrentAdded, this, &TorrentTask::onSessionAdded);
    connect(m_session, &TorrentSession::torrentProgress, this, &TorrentTask::onSessionProgress);
    connect(m_session, &TorrentSession::torrentFinished, this, &TorrentTask::onSessionFinished);
    connect(m_session, &TorrentSession::torrentError, this, &TorrentTask::onSessionError);
    connect(m_session, &TorrentSession::torrentMetadataReceived, this, &TorrentTask::onMetadataReceived);
    connect(m_session, &TorrentSession::torrentPieces, this, &TorrentTask::onSessionPieces);
}

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

QString TorrentTask::fileName() const
{
    if (!m_name.isEmpty())
        return m_savePath + QStringLiteral("/") + m_name;
    if (!m_savePath.isEmpty())
        return m_savePath;
    return m_source;
}

QString TorrentTask::url() const
{
    return m_source;
}

// ---------------------------------------------------------------------------
// State helpers
// ---------------------------------------------------------------------------

bool TorrentTask::isRunning() const
{
    return m_stateString == QStringLiteral("Downloading")
        || m_stateString == QStringLiteral("Metadata")
        || m_stateString == QStringLiteral("Seeding")
        || m_stateString == QStringLiteral("Checking");
}

bool TorrentTask::isIdle() const
{
    return m_stateString == QStringLiteral("Queued");
}

// ---------------------------------------------------------------------------
// Control
// ---------------------------------------------------------------------------

void TorrentTask::start()
{
    if (m_session) m_session->resumeTorrent(m_handleId);
    if (m_isPaused) {
        m_isPaused = false;
        m_pausedAt = 0;
        m_pauseReason.clear();
        emit pausedAtChanged();
        emit pauseReasonChanged();
    }
    m_stateString = QStringLiteral("Queued");
    emit stateChanged();
}

void TorrentTask::pause()
{
    if (m_session) m_session->pauseTorrent(m_handleId);
    m_isPaused = true;
    m_pausedAt = QDateTime::currentMSecsSinceEpoch();
    m_stateString = QStringLiteral("Paused");
    emit stateChanged();
    emit pausedAtChanged();
}

void TorrentTask::resume()
{
    if (m_session) m_session->resumeTorrent(m_handleId);
    m_isPaused = false;
    m_pausedAt = 0;
    m_pauseReason.clear();
    m_stateString = QStringLiteral("Queued");
    emit stateChanged();
    emit pausedAtChanged();
    emit pauseReasonChanged();
}

void TorrentTask::cancel()
{
    if (m_session) m_session->removeTorrent(m_handleId, false);
    m_stateString = QStringLiteral("Canceled");
    emit stateChanged();
    emit finished(false);
}

void TorrentTask::setMaxSpeed(qint64 v)
{
    if (m_maxSpeed == v) return;
    m_maxSpeed = v;
    emit maxSpeedChanged();
}

void TorrentTask::setPriority(int p)
{
    if (m_priority == p) return;
    m_priority = p;
    emit priorityChanged();
}

void TorrentTask::setFileEnabled(int fileIndex, bool enabled)
{
    if (m_session) m_session->setFileEnabled(m_handleId, fileIndex, enabled);
}

QVariantList TorrentTask::pieceMap(int buckets) const
{
    QVariantList out;
    const int n = m_pieces.size();
    if (buckets <= 0 || n <= 0) return out;
    out.reserve(buckets);
    for (int b = 0; b < buckets; ++b) {
        const int start = static_cast<int>(static_cast<qint64>(b) * n / buckets);
        int end = static_cast<int>(static_cast<qint64>(b + 1) * n / buckets);
        if (end <= start) end = start + 1;
        if (end > n) end = n;
        int done = 0;
        for (int i = start; i < end; ++i)
            if (m_pieces[i]) ++done;
        out.append(static_cast<double>(done) / static_cast<double>(end - start));
    }
    return out;
}

// ---------------------------------------------------------------------------
// Speed history
// ---------------------------------------------------------------------------

void TorrentTask::appendSpeedSample(qint64 bps)
{
    constexpr int kMaxSamples = 60;
    m_speedHistory.append(QVariant::fromValue(bps));
    while (m_speedHistory.size() > kMaxSamples)
        m_speedHistory.removeFirst();
    emit speedHistoryChanged();
}

// ---------------------------------------------------------------------------
// Session signal handlers
// ---------------------------------------------------------------------------

void TorrentTask::onSessionAdded(qint64 id, const QString& name, const QString& /*savePath*/)
{
    if (id != m_handleId) return;
    if (!name.isEmpty() && m_name.isEmpty()) {
        m_name = name;
        emit fileNameChanged();
    }
    m_stateString = QStringLiteral("Queued");
    emit stateChanged();
}

void TorrentTask::onSessionProgress(qint64 id,
                                    qint64 downloaded, qint64 uploaded, qint64 total,
                                    qint64 dlSpeed, qint64 ulSpeed,
                                    int eta,
                                    int seeders, int leechers,
                                    const QString& state)
{
    if (id != m_handleId) return;
    if (m_isPaused) return; // libtorrent can still emit; honour local pause

    bool changed = false;

    if (m_received != downloaded || m_total != total) {
        m_received = downloaded;
        m_total    = total;
        emit progress(downloaded, total);
        changed = true;
    }

    if (m_uploaded != uploaded) {
        m_uploaded = uploaded;
        emit uploadedChanged();
    }

    if (m_speed != dlSpeed) {
        if (dlSpeed > 0) m_lastSpeed = dlSpeed;
        m_speed = dlSpeed;
        appendSpeedSample(dlSpeed);
        emit speedChanged();
        emit lastSpeedChanged();
    }

    if (m_uploadSpeed != ulSpeed) {
        m_uploadSpeed = ulSpeed;
        emit uploadSpeedChanged();
    }

    if (m_eta != eta) {
        if (eta >= 0) m_lastEta = eta;
        m_eta = eta;
        emit etaChanged();
        emit lastEtaChanged();
        changed = true;
    }

    if (m_seeders != seeders || m_leechers != leechers) {
        m_seeders  = seeders;
        m_leechers = leechers;
        emit peersChanged();
    }

    if (m_stateString != state) {
        m_stateString = state;
        emit stateChanged();
        changed = true;
    }

    Q_UNUSED(changed);
}

void TorrentTask::onSessionFinished(qint64 id, const QString& /*savePath*/)
{
    if (id != m_handleId) return;
    m_finished    = true;
    m_stateString = QStringLiteral("Done");
    m_speed       = 0;
    m_eta         = -1;
    emit speedChanged();
    emit etaChanged();
    emit stateChanged();
    emit progress(m_total, m_total);
    emit finished(true);
}

void TorrentTask::onSessionError(qint64 id, const QString& message)
{
    if (id != m_handleId) return;
    qWarning() << "TorrentTask" << m_handleId << "error:" << message;
    m_stateString = QStringLiteral("Error");
    m_speed       = 0;
    emit speedChanged();
    emit stateChanged();
    emit finished(false);
}

void TorrentTask::onMetadataReceived(qint64 id, const QString& name, const QStringList& files)
{
    if (id != m_handleId) return;
    if (!name.isEmpty()) {
        m_name = name;
        emit fileNameChanged();
    }
    m_fileList = files;
    emit fileListChanged();
}

void TorrentTask::onSessionPieces(qint64 id, const QByteArray& pieces)
{
    if (id != m_handleId) return;
    if (m_pieces == pieces) return;
    m_pieces = pieces;
    emit piecesChanged();
}
