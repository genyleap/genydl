module;
#include <algorithm>
#include <memory>
#include <vector>
#include <deque>
#include <unordered_map>
#include <unordered_set>
#include <QByteArray>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QTimer>

#ifdef GENYDL_USE_LIBTORRENT
// All libtorrent headers live here in the global fragment so they never
// pollute the module interface.
#include <libtorrent/session.hpp>
#include <libtorrent/session_params.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/error_code.hpp>
#include <libtorrent/download_priority.hpp>
namespace lt = libtorrent;
#endif

module genydl.services.torrent_session;

// ---------------------------------------------------------------------------
// PIMPL
// ---------------------------------------------------------------------------

#ifdef GENYDL_USE_LIBTORRENT

struct TorrentSessionPrivate {
    std::unique_ptr<lt::session> session;
    std::unordered_map<qint64, lt::torrent_handle> handles;
    // IDs awaiting their add_torrent_alert, in insertion order. Each
    // async_add_torrent() produces exactly one add_torrent_alert delivered in
    // submission order, so a FIFO maps alerts back to the right ID reliably.
    std::deque<qint64> pendingIds;
    std::unordered_set<qint64> filesEmitted; //!< ids whose file list was already emitted
    qint64 nextId = 1;
    qint64 totalDownloadSpeed = 0;
    qint64 totalUploadSpeed  = 0;

    TorrentSessionPrivate()
    {
        lt::settings_pack settings;
        // alert_category_t is a strong bitflag; its conversion to int is
        // explicit, so cast the OR'd mask before handing it to set_int().
        // status -> add_torrent/state_update/torrent_finished/metadata alerts;
        // file_progress -> per-file progress. (There is no "progress" category
        // in libtorrent 2.0 — it's split into file_/piece_/block_progress.)
        settings.set_int(lt::settings_pack::alert_mask,
            static_cast<int>(
                lt::alert_category::error       |
                lt::alert_category::status      |
                lt::alert_category::file_progress));
        settings.set_bool(lt::settings_pack::enable_dht,  true);
        settings.set_bool(lt::settings_pack::enable_lsd,  true);
        settings.set_bool(lt::settings_pack::enable_upnp, true);
        settings.set_bool(lt::settings_pack::enable_natpmp, true);
        session = std::make_unique<lt::session>(std::move(settings));
    }

    qint64 findId(const lt::torrent_handle& h) const
    {
        for (const auto& [id, handle] : handles) {
            if (handle == h) return id;
        }
        return -1;
    }

    static QString stateToString(lt::torrent_status::state_t s)
    {
        switch (s) {
        case lt::torrent_status::checking_files:       return QStringLiteral("Checking");
        case lt::torrent_status::downloading_metadata: return QStringLiteral("Metadata");
        case lt::torrent_status::downloading:          return QStringLiteral("Downloading");
        case lt::torrent_status::finished:             return QStringLiteral("Done");
        case lt::torrent_status::seeding:              return QStringLiteral("Seeding");
        case lt::torrent_status::checking_resume_data: return QStringLiteral("Checking");
        default:                                       return QStringLiteral("Queued");
        }
    }
};

#else // !GENYDL_USE_LIBTORRENT

struct TorrentSessionPrivate {};

#endif // GENYDL_USE_LIBTORRENT

// ---------------------------------------------------------------------------
// TorrentSession
// ---------------------------------------------------------------------------

TorrentSession::TorrentSession(QObject* parent)
    : QObject(parent)
    , d(new TorrentSessionPrivate())
{
#ifdef GENYDL_USE_LIBTORRENT
    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(500);
    connect(m_pollTimer, &QTimer::timeout, this, &TorrentSession::pollAlerts);
    m_pollTimer->start();
#endif
}

TorrentSession::~TorrentSession()
{
#ifdef GENYDL_USE_LIBTORRENT
    if (m_pollTimer) m_pollTimer->stop();
    // session destructor joins the libtorrent threads gracefully
#endif
    delete d;
}

bool TorrentSession::isAvailable() const
{
#ifdef GENYDL_USE_LIBTORRENT
    return d && d->session != nullptr;
#else
    return false;
#endif
}

qint64 TorrentSession::totalDownloadSpeed() const
{
#ifdef GENYDL_USE_LIBTORRENT
    return d ? d->totalDownloadSpeed : 0;
#else
    return 0;
#endif
}

qint64 TorrentSession::totalUploadSpeed() const
{
#ifdef GENYDL_USE_LIBTORRENT
    return d ? d->totalUploadSpeed : 0;
#else
    return 0;
#endif
}

qint64 TorrentSession::addMagnet(const QString& magnetUri, const QString& savePath)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return -1;

    lt::error_code ec;
    lt::add_torrent_params p = lt::parse_magnet_uri(magnetUri.toStdString(), ec);
    if (ec) {
        qWarning() << "TorrentSession: invalid magnet URI:" << ec.message().c_str();
        return -1;
    }
    p.save_path = savePath.toStdString();
    p.flags |= lt::torrent_flags::auto_managed;

    const qint64 id = d->nextId++;
    // The actual handle is filled in pollAlerts() via add_torrent_alert,
    // matched back to this id through the pendingIds FIFO.
    d->handles[id] = lt::torrent_handle{}; // placeholder until alert arrives
    d->pendingIds.push_back(id);
    d->session->async_add_torrent(std::move(p));
    return id;
#else
    Q_UNUSED(magnetUri); Q_UNUSED(savePath);
    return -1;
#endif
}

qint64 TorrentSession::addTorrentFile(const QString& torrentFilePath, const QString& savePath)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return -1;

    lt::error_code ec;
    auto ti = std::make_shared<lt::torrent_info>(torrentFilePath.toStdString(), ec);
    if (ec) {
        qWarning() << "TorrentSession: cannot read torrent file:" << ec.message().c_str();
        return -1;
    }
    lt::add_torrent_params p;
    p.ti = std::move(ti);
    p.save_path = savePath.toStdString();
    p.flags |= lt::torrent_flags::auto_managed;

    const qint64 id = d->nextId++;
    d->handles[id] = lt::torrent_handle{};
    d->pendingIds.push_back(id);
    d->session->async_add_torrent(std::move(p));
    return id;
#else
    Q_UNUSED(torrentFilePath); Q_UNUSED(savePath);
    return -1;
#endif
}

void TorrentSession::pauseTorrent(qint64 id)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d) return;
    auto it = d->handles.find(id);
    if (it != d->handles.end() && it->second.is_valid())
        it->second.pause();
#else
    Q_UNUSED(id);
#endif
}

void TorrentSession::resumeTorrent(qint64 id)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d) return;
    auto it = d->handles.find(id);
    if (it != d->handles.end() && it->second.is_valid())
        it->second.resume();
#else
    Q_UNUSED(id);
#endif
}

void TorrentSession::removeTorrent(qint64 id, bool deleteFiles)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d) return;
    auto it = d->handles.find(id);
    if (it != d->handles.end()) {
        if (it->second.is_valid()) {
            lt::remove_flags_t flags{};
            if (deleteFiles) flags |= lt::session::delete_files;
            d->session->remove_torrent(it->second, flags);
        }
        d->handles.erase(it);
    }
    d->filesEmitted.erase(id);
    // Drop from the pending FIFO if the handle never materialized.
    d->pendingIds.erase(std::remove(d->pendingIds.begin(), d->pendingIds.end(), id),
                        d->pendingIds.end());
#else
    Q_UNUSED(id); Q_UNUSED(deleteFiles);
#endif
}

void TorrentSession::setGlobalMaxDownloadSpeed(qint64 bytesPerSec)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::download_rate_limit, static_cast<int>(bytesPerSec));
    d->session->apply_settings(std::move(sp));
#else
    Q_UNUSED(bytesPerSec);
#endif
}

void TorrentSession::setGlobalMaxUploadSpeed(qint64 bytesPerSec)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::upload_rate_limit, static_cast<int>(bytesPerSec));
    d->session->apply_settings(std::move(sp));
#else
    Q_UNUSED(bytesPerSec);
#endif
}

void TorrentSession::setSeedRatioLimit(double ratio)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return;
    lt::settings_pack sp;
    // share_ratio_limit is expressed as ratio * 100 (200 == 2.0).
    // 0 disables the limit (seed indefinitely).
    sp.set_int(lt::settings_pack::share_ratio_limit,
               ratio > 0.0 ? static_cast<int>(ratio * 100.0) : 0);
    d->session->apply_settings(std::move(sp));
#else
    Q_UNUSED(ratio);
#endif
}

void TorrentSession::setSeedTimeLimit(int minutes)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return;
    lt::settings_pack sp;
    sp.set_int(lt::settings_pack::seed_time_limit, minutes > 0 ? minutes * 60 : 0);
    d->session->apply_settings(std::move(sp));
#else
    Q_UNUSED(minutes);
#endif
}

void TorrentSession::setFileEnabled(qint64 id, int fileIndex, bool enabled)
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d) return;
    auto it = d->handles.find(id);
    if (it != d->handles.end() && it->second.is_valid()) {
        it->second.file_priority(lt::file_index_t(fileIndex),
                                 enabled ? lt::default_priority : lt::dont_download);
    }
#else
    Q_UNUSED(id); Q_UNUSED(fileIndex); Q_UNUSED(enabled);
#endif
}

void TorrentSession::pollAlerts()
{
#ifdef GENYDL_USE_LIBTORRENT
    if (!d || !d->session) return;

    // Request a fresh snapshot of all torrent statuses.
    d->session->post_torrent_updates();

    std::vector<lt::alert*> alerts;
    d->session->pop_alerts(&alerts);

    qint64 newTotalDl = 0;
    qint64 newTotalUl = 0;

    // Emit the file list once per torrent, as soon as metadata is available.
    // .torrent files have it immediately; magnets get it after the swarm fetch.
    auto emitFilesIfReady = [this](qint64 id, const lt::torrent_handle& h) {
        if (id < 0 || d->filesEmitted.count(id)) return;
        std::shared_ptr<const lt::torrent_info> ti = h.torrent_file();
        if (!ti) return;
        const QString name = QString::fromStdString(ti->name());
        QStringList files;
        const lt::file_storage& fs = ti->files();
        // file_path() returns std::string; file_name() returns string_view.
        for (lt::file_index_t const i : fs.file_range())
            files << QString::fromStdString(fs.file_path(i));
        d->filesEmitted.insert(id);
        emit torrentMetadataReceived(id, name, files);
    };

    for (lt::alert* a : alerts) {

        // --- Torrent added ---
        // add_torrent_alerts arrive in submission order, so the front of the
        // pendingIds FIFO is always the id for this alert.
        if (auto* ta = lt::alert_cast<lt::add_torrent_alert>(a)) {
            if (d->pendingIds.empty()) continue; // was removed before completing
            const qint64 pendingId = d->pendingIds.front();
            d->pendingIds.pop_front();

            if (ta->error) {
                d->handles.erase(pendingId);
                emit torrentError(pendingId, QString::fromStdString(ta->error.message()));
                continue;
            }
            d->handles[pendingId] = ta->handle;
            const QString name     = QString::fromStdString(ta->handle.status().name);
            const QString savePath = QString::fromStdString(ta->handle.status().save_path);
            emit torrentAdded(pendingId, name, savePath);
            emitFilesIfReady(pendingId, ta->handle); // .torrent files already have metadata
            continue;
        }

        // --- Bulk state snapshot ---
        if (auto* su = lt::alert_cast<lt::state_update_alert>(a)) {
            for (const lt::torrent_status& st : su->status) {
                const qint64 id = d->findId(st.handle);
                if (id < 0) continue;

                newTotalDl += st.download_rate;
                newTotalUl += st.upload_rate;

                const qint64 total     = st.total_wanted;
                const qint64 done      = st.total_wanted_done;
                const qint64 uploaded  = st.all_time_upload;
                const qint64 dlRate    = st.download_rate;
                const qint64 ulRate    = st.upload_rate;
                const int    seeders   = st.num_seeds;
                const int    leechers  = st.num_peers - st.num_seeds;
                const int    eta       = (dlRate > 0 && total > done)
                                         ? static_cast<int>((total - done) / dlRate)
                                         : -1;
                const QString state    = d->stateToString(st.state);

                emit torrentProgress(id, done, uploaded, total, dlRate, ulRate,
                                     eta, seeders, qMax(0, leechers), state);

                // Metadata may arrive without a dedicated alert (e.g. resumed
                // torrents); make sure the file list is published.
                emitFilesIfReady(id, st.handle);

                // Per-piece completion bitmap for the piece-map UI.
                const int numPieces = st.pieces.size();
                if (numPieces > 0) {
                    QByteArray bits(numPieces, char(0));
                    for (int i = 0; i < numPieces; ++i)
                        bits[i] = st.pieces[lt::piece_index_t(i)] ? char(1) : char(0);
                    emit torrentPieces(id, bits);
                }
            }
            continue;
        }

        // --- Torrent finished ---
        if (auto* tf = lt::alert_cast<lt::torrent_finished_alert>(a)) {
            const qint64 id = d->findId(tf->handle);
            if (id >= 0) {
                const QString savePath = QString::fromStdString(
                    tf->handle.status().save_path);
                emit torrentFinished(id, savePath);
            }
            continue;
        }

        // --- Torrent error ---
        if (auto* te = lt::alert_cast<lt::torrent_error_alert>(a)) {
            const qint64 id = d->findId(te->handle);
            if (id >= 0)
                emit torrentError(id, QString::fromStdString(te->error.message()));
            continue;
        }

        // --- Metadata received (magnet) ---
        if (auto* mr = lt::alert_cast<lt::metadata_received_alert>(a)) {
            emitFilesIfReady(d->findId(mr->handle), mr->handle);
            continue;
        }

        // --- Torrent removed ---
        if (auto* trm = lt::alert_cast<lt::torrent_removed_alert>(a)) {
            // Handle was already erased in removeTorrent(); emit signal for cleanup.
            Q_UNUSED(trm);
            continue;
        }
    }

    // Update aggregate speeds
    if (newTotalDl != d->totalDownloadSpeed || newTotalUl != d->totalUploadSpeed) {
        d->totalDownloadSpeed = newTotalDl;
        d->totalUploadSpeed   = newTotalUl;
        emit speedChanged();
    }
#endif
}
