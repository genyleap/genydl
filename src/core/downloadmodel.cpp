module;
#include <algorithm>
#include <QAbstractTableModel>
#include <QByteArray>
#include <QFileInfo>
#include <QHash>
#include <QModelIndex>
#include <QString>
#include <QVariant>
#include <QVector>
#include <QtGlobal>

module genydl.core.downloadmodel;

// ---------------------------------------------------------------------------
// Item helpers – dispatch to whichever task type is active
// ---------------------------------------------------------------------------
namespace {

QString itemStateString(const DownloadItem& item)
{
    if (item.task)        return item.task->stateString();
    if (item.torrentTask) return item.torrentTask->stateString();
    return {};
}

int itemEta(const DownloadItem& item)
{
    if (item.task)        return item.task->eta();
    if (item.torrentTask) return item.torrentTask->eta();
    return -1;
}

qint64 itemSpeed(const DownloadItem& item)
{
    if (item.task)        return item.task->speed();
    if (item.torrentTask) return item.torrentTask->speed();
    return 0;
}

int itemSegments(const DownloadItem& item)
{
    if (item.task)        return item.task->effectiveSegments();
    if (item.torrentTask) return item.torrentTask->effectiveSegments();
    return 0;
}

QString itemUrl(const DownloadItem& item)
{
    if (item.task)        return item.task->url();
    if (item.torrentTask) return item.torrentTask->url();
    return {};
}

} // namespace

DownloadModel::DownloadModel(QObject *parent) : QAbstractTableModel(parent) {}

int DownloadModel::rowCount(const QModelIndex &parent) const {
    Q_UNUSED(parent)
    return m_downloads.size();
}

int DownloadModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return ColumnCount;
}

QVariant DownloadModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_downloads.size()) return {};
    const auto &item = m_downloads[index.row()];

    if (role == Qt::DisplayRole) {
        switch (index.column()) {
        case SelectColumn:
            return {};
        case NameColumn:
            return QFileInfo(item.fileName).fileName();
        case QueueColumn:
            return item.queueName;
        case SizeColumn:
            return item.total;
        case StatusColumn:
            return itemStateString(item);
        case EtaColumn:
            return itemEta(item);
        case SpeedColumn:
            return itemSpeed(item);
        case SegmentsColumn:
            return itemSegments(item);
        case CategoryColumn:
            return item.category;
        case ActionsColumn:
            return {};
        default:
            return {};
        }
    }

    switch (role) {
    case FileNameRole: return item.fileName;
    case ProgressRole: return item.total > 0 ? (double)item.received / item.total : (double)item.received;
    case FinishedRole: return item.finished;
    case TaskRole:     return QVariant::fromValue(item.anyTask());
    case StatusRole:   return itemStateString(item);
    case BytesReceivedRole: return item.received;
    case BytesTotalRole:    return item.total;
    case QueueRole:    return item.queueName;
    case CategoryRole: return item.category;
    }
    return {};
}

QVariant DownloadModel::headerData(int section, Qt::Orientation orientation, int role) const
{
    if (orientation != Qt::Horizontal || role != Qt::DisplayRole) {
        return QAbstractTableModel::headerData(section, orientation, role);
    }

    switch (section) {
    case SelectColumn: return QString();
    case NameColumn: return tr("Name");
    case QueueColumn: return tr("Queue");
    case SizeColumn: return tr("Size");
    case StatusColumn: return tr("Status");
    case EtaColumn: return tr("Time Left");
    case SpeedColumn: return tr("Speed");
    case SegmentsColumn: return tr("Seg");
    case CategoryColumn: return tr("Category");
    case ActionsColumn: return tr("Actions");
    default: return {};
    }
}

QHash<int, QByteArray> DownloadModel::roleNames() const {
    return {
        {FileNameRole, "fileName"},
        {ProgressRole, "progress"},
        {FinishedRole, "finished"},
        {TaskRole, "task"},
        {StatusRole, "status"},
        {BytesReceivedRole, "bytesReceived"},
        {BytesTotalRole, "bytesTotal"},
        {QueueRole, "queueName"},
        {CategoryRole, "category"}
    };
}

void DownloadModel::addDownload(DownloaderTask* task, const QString& queueName, const QString& category) {
    beginInsertRows(QModelIndex(), m_downloads.size(), m_downloads.size());
    DownloadItem item;
    item.fileName = task->fileName();
    item.queueName = queueName;
    item.category = category;
    item.task = task;
    m_downloads.append(item);
    endInsertRows();

    connect(task, &DownloaderTask::progress, this, &DownloadModel::onTaskProgress);
    connect(task, &DownloaderTask::finished, this, &DownloadModel::onTaskFinished);
    connect(task, &DownloaderTask::stateChanged, this, &DownloadModel::onTaskStateChanged);
}

void DownloadModel::updateMetadata(DownloaderTask* task, const QString& queueName, const QString& category) {
    if (!task) return;
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == task) {
            m_downloads[i].queueName = queueName;
            m_downloads[i].category = category;
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {QueueRole, CategoryRole});
            break;
        }
    }
}

void DownloadModel::seedProgress(DownloaderTask* task, qint64 bytesReceived, qint64 bytesTotal)
{
    if (!task) return;
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == task) {
            m_downloads[i].received = bytesReceived;
            m_downloads[i].total = bytesTotal;
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {ProgressRole, BytesReceivedRole, BytesTotalRole});
            break;
        }
    }
}

void DownloadModel::seedFinished(DownloaderTask* task, bool finished)
{
    if (!task) return;
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == task) {
            if (m_downloads[i].finished == finished) break;
            m_downloads[i].finished = finished;
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {FinishedRole});
            break;
        }
    }
}

void DownloadModel::updateFileName(DownloaderTask* task, const QString& fileName)
{
    if (!task) return;
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == task) {
            if (m_downloads[i].fileName == fileName) break;
            m_downloads[i].fileName = fileName;
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {FileNameRole});
            break;
        }
    }
}

void DownloadModel::sortBy(const QString& roleName, bool ascending)
{
    int role = FileNameRole;
    if (roleName == "fileName") role = FileNameRole;
    else if (roleName == "bytesTotal") role = BytesTotalRole;
    else if (roleName == "bytesReceived") role = BytesReceivedRole;
    else if (roleName == "queueName") role = QueueRole;
    else if (roleName == "category") role = CategoryRole;
    else if (roleName == "status") role = StatusRole;

    beginResetModel();
    std::stable_sort(m_downloads.begin(), m_downloads.end(), [role, ascending](const DownloadItem& a, const DownloadItem& b) {
        auto less = [ascending](const auto& lhs, const auto& rhs) {
            return ascending ? (lhs < rhs) : (lhs > rhs);
        };
        switch (role) {
        case FileNameRole:
            return less(a.fileName.toLower(), b.fileName.toLower());
        case BytesTotalRole:
            return less(a.total, b.total);
        case BytesReceivedRole:
            return less(a.received, b.received);
        case QueueRole:
            return less(a.queueName.toLower(), b.queueName.toLower());
        case CategoryRole:
            return less(a.category.toLower(), b.category.toLower());
        case StatusRole:
            return less(itemStateString(a).toLower(), itemStateString(b).toLower());
        default:
            return less(a.fileName.toLower(), b.fileName.toLower());
        }
    });
    endResetModel();
}

int DownloadModel::filteredCount(const QString& queueFilter,
                                 const QString& statusFilter,
                                 const QString& categoryFilter,
                                 const QString& searchText,
                                 const QString& sourceFilter) const
{
    const QString queueNeedle = queueFilter.trimmed();
    const QString statusNeedle = statusFilter.trimmed();
    const QString categoryNeedle = categoryFilter.trimmed();
    const QString query = searchText.trimmed().toLower();
    const QString sourceNeedle = sourceFilter.trimmed();

    // Classify a row's source family, matching the JS sourceTypeInfo() ids so
    // the C++ count and the per-row QML visibility stay consistent.
    auto sourcePasses = [&](const DownloadItem& item) {
        if (sourceNeedle.isEmpty() || sourceNeedle == QStringLiteral("All")) return true;
        QString id;
        if (item.isTorrent()) {
            id = QStringLiteral("torrent");
        } else {
            const QString net = item.task ? item.task->storageNetwork() : QString();
            if (net.isEmpty()) {
                id = QStringLiteral("http");
            } else {
                const QString up = net.toUpper();
                if (up == QStringLiteral("IPFS")) id = QStringLiteral("ipfs");
                else if (up == QStringLiteral("ARWEAVE")) id = QStringLiteral("arweave");
                else id = QStringLiteral("storage");
            }
        }
        if (sourceNeedle == QStringLiteral("Direct"))  return id == QStringLiteral("http");
        if (sourceNeedle == QStringLiteral("Torrent")) return id == QStringLiteral("torrent");
        if (sourceNeedle == QStringLiteral("IPFS"))    return id == QStringLiteral("ipfs");
        if (sourceNeedle == QStringLiteral("Arweave")) return id == QStringLiteral("arweave");
        if (sourceNeedle == QStringLiteral("Blockchain"))
            return id == QStringLiteral("ipfs") || id == QStringLiteral("arweave") || id == QStringLiteral("storage");
        return true;
    };

    auto statusPasses = [&](const QString& state) {
        if (statusNeedle.isEmpty() || statusNeedle == QStringLiteral("All")) return true;
        if (statusNeedle == QStringLiteral("Unfinished")) {
            return state != QStringLiteral("Done")
                && state != QStringLiteral("Canceled")
                && state != QStringLiteral("Error");
        }
        if (statusNeedle == QStringLiteral("History")) {
            return state == QStringLiteral("Done")
                || state == QStringLiteral("Canceled")
                || state == QStringLiteral("Error");
        }
        if (state.isEmpty()) return true;
        return state == statusNeedle;
    };

    int matches = 0;
    for (const DownloadItem& item : m_downloads) {
        const QString queueValue    = item.queueName;
        const QString categoryValue = item.category;
        const QString state = itemStateString(item);

        const bool passQueue = queueNeedle.isEmpty()
            || queueNeedle == QStringLiteral("All Queues")
            || queueValue.isEmpty()
            || queueValue == queueNeedle;
        if (!passQueue) continue;

        if (!statusPasses(state)) continue;

        const bool passCategory = categoryNeedle.isEmpty()
            || categoryNeedle == QStringLiteral("All")
            || categoryValue.isEmpty()
            || categoryValue == categoryNeedle;
        if (!passCategory) continue;

        if (!sourcePasses(item)) continue;

        if (!query.isEmpty()) {
            const QString fullName  = item.fileName.toLower();
            const QString baseName  = QFileInfo(item.fileName).fileName().toLower();
            const QString urlValue  = itemUrl(item).toLower();
            const bool passSearch   = fullName.contains(query)
                || baseName.contains(query)
                || (!urlValue.isEmpty() && urlValue.contains(query));
            if (!passSearch) continue;
        }

        ++matches;
    }
    return matches;
}

DownloaderTask* DownloadModel::taskAt(int index) const {
    if (index < 0 || index >= m_downloads.size()) return nullptr;
    return m_downloads[index].task;
}

TorrentTask* DownloadModel::torrentTaskAt(int index) const {
    if (index < 0 || index >= m_downloads.size()) return nullptr;
    return m_downloads[index].torrentTask;
}

int DownloadModel::indexOfTask(DownloaderTask* task) const
{
    if (!task) return -1;
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == task) return i;
    }
    return -1;
}

int DownloadModel::indexOfTorrentTask(TorrentTask* task) const
{
    if (!task) return -1;
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].torrentTask == task) return i;
    }
    return -1;
}

bool DownloadModel::isFinishedAt(int index) const {
    if (index < 0 || index >= m_downloads.size()) return false;
    return m_downloads[index].finished;
}

void DownloadModel::removeAt(int index) {
    if (index < 0 || index >= m_downloads.size()) return;
    beginRemoveRows(QModelIndex(), index, index);
    DownloadItem item = m_downloads.takeAt(index);
    endRemoveRows();
    if (item.task)        item.task->deleteLater();
    if (item.torrentTask) item.torrentTask->deleteLater();
}

void DownloadModel::addTorrentDownload(TorrentTask* task,
                                       const QString& queueName,
                                       const QString& category)
{
    beginInsertRows(QModelIndex(), m_downloads.size(), m_downloads.size());
    DownloadItem item;
    item.fileName    = task->fileName();
    item.queueName   = queueName;
    item.category    = category;
    item.torrentTask = task;
    m_downloads.append(item);
    endInsertRows();

    connect(task, &TorrentTask::progress,     this, &DownloadModel::onTorrentProgress);
    connect(task, &TorrentTask::finished,     this, &DownloadModel::onTorrentFinished);
    connect(task, &TorrentTask::stateChanged, this, &DownloadModel::onTorrentStateChanged);
    // Keep file name in sync after metadata arrives
    connect(task, &TorrentTask::fileNameChanged, this, [this, task]() {
        const int i = indexOfTorrentTask(task);
        if (i < 0) return;
        m_downloads[i].fileName = task->fileName();
        const QModelIndex left  = index(i, 0);
        const QModelIndex right = index(i, ColumnCount - 1);
        emit dataChanged(left, right, {FileNameRole});
    });
}

void DownloadModel::onTaskProgress(qint64 bytesReceived, qint64 bytesTotal) {
    auto* senderTask = qobject_cast<DownloaderTask*>(sender());
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == senderTask) {
            m_downloads[i].received = bytesReceived;
            m_downloads[i].total = bytesTotal;
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {ProgressRole, BytesReceivedRole, BytesTotalRole});
            break;
        }
    }
}

void DownloadModel::onTaskFinished(bool) {
    auto* senderTask = qobject_cast<DownloaderTask*>(sender());
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == senderTask) {
            m_downloads[i].finished = true;
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {FinishedRole, StatusRole});
            break;
        }
    }
}

void DownloadModel::onTaskStateChanged()
{
    auto* senderTask = qobject_cast<DownloaderTask*>(sender());
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].task == senderTask) {
            const QString state = senderTask ? senderTask->stateString() : QString();
            m_downloads[i].finished = (state == QStringLiteral("Done")
                                       || state == QStringLiteral("Canceled")
                                       || state == QStringLiteral("Error"));
            const QModelIndex left = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {StatusRole, FinishedRole});
            break;
        }
    }
}

// ---------------------------------------------------------------------------
// Torrent task slots
// ---------------------------------------------------------------------------

void DownloadModel::onTorrentProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    auto* senderTask = qobject_cast<TorrentTask*>(sender());
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].torrentTask == senderTask) {
            m_downloads[i].received = bytesReceived;
            m_downloads[i].total    = bytesTotal;
            const QModelIndex left  = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {ProgressRole, BytesReceivedRole, BytesTotalRole, SpeedColumn, EtaColumn});
            break;
        }
    }
}

void DownloadModel::onTorrentFinished(bool)
{
    auto* senderTask = qobject_cast<TorrentTask*>(sender());
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].torrentTask == senderTask) {
            m_downloads[i].finished = true;
            const QModelIndex left  = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {FinishedRole, StatusRole});
            break;
        }
    }
}

void DownloadModel::onTorrentStateChanged()
{
    auto* senderTask = qobject_cast<TorrentTask*>(sender());
    for (int i = 0; i < m_downloads.size(); ++i) {
        if (m_downloads[i].torrentTask == senderTask) {
            const QString state = senderTask ? senderTask->stateString() : QString();
            m_downloads[i].finished = (state == QStringLiteral("Done")
                                       || state == QStringLiteral("Canceled")
                                       || state == QStringLiteral("Error"));
            const QModelIndex left  = index(i, 0);
            const QModelIndex right = index(i, ColumnCount - 1);
            emit dataChanged(left, right, {StatusRole, FinishedRole});
            break;
        }
    }
}
