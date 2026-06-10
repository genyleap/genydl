/*!
 * @file        gateway_service.cpp
 * @brief       Implementation of the IPFS gateway registry and health monitor.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       08 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QDateTime>
#include <QElapsedTimer>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSet>
#include <QSettings>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <algorithm>
#include <climits>

module genydl.services.gateway_service;

namespace {

//! Probe deadline; gateways that do not respond in time are rated Down.
constexpr int kProbeTimeoutMs = 8000;

//! Re-sweep interval (ms). Five minutes keeps health fresh without churn.
constexpr int kSweepIntervalMs = 5 * 60 * 1000;

//! Settings key holding the serialized user policy.
const QString kSettingsKey = QStringLiteral("ipfs/gatewayPolicy");

} // namespace

QString GatewayService::probeCid()
{
    // CIDv0 of the canonical empty UnixFS directory: universally pinned and
    // resolvable on every conformant gateway, so a 200/2xx means "reachable".
    return QStringLiteral("QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn");
}

QString GatewayService::normalizeBase(const QString& url)
{
    QString s = url.trimmed();
    if (s.isEmpty()) return {};
    if (!s.contains(QStringLiteral("://"))) {
        s.prepend(QStringLiteral("https://"));
    }
    while (s.endsWith(QLatin1Char('/'))) s.chop(1);
    // Tolerate users pasting ".../ipfs" or ".../ipfs/" as the base.
    if (s.endsWith(QStringLiteral("/ipfs"), Qt::CaseInsensitive)) {
        s.chop(5);
    }
    while (s.endsWith(QLatin1Char('/'))) s.chop(1);
    return s;
}

QVector<GatewayService::Gateway> GatewayService::builtinGateways()
{
    QVector<Gateway> list;
    const auto add = [&](const QString& url, bool local, bool preferred) {
        Gateway g;
        g.url = normalizeBase(url);
        g.host = QUrl(g.url).host();
        g.builtin = true;
        g.local = local;
        g.preferred = preferred;
        g.enabled = true;
        list.append(g);
    };
    // The local node is listed first and preferred: when present it is both the
    // fastest and the most trustworthy path. It simply probes Down when absent.
    add(QStringLiteral("http://127.0.0.1:8080"), /*local*/ true, /*preferred*/ true);
    add(QStringLiteral("https://ipfs.io"), false, false);
    add(QStringLiteral("https://dweb.link"), false, false);
    add(QStringLiteral("https://cloudflare-ipfs.com"), false, false);
    add(QStringLiteral("https://gateway.pinata.cloud"), false, false);
    add(QStringLiteral("https://w3s.link"), false, false);
    return list;
}

GatewayService::GatewayService(QObject* parent)
    : QObject(parent)
{
    m_gateways = builtinGateways();
    load();

    m_healthTimer.setInterval(kSweepIntervalMs);
    connect(&m_healthTimer, &QTimer::timeout, this, &GatewayService::checkHealthNow);
    m_healthTimer.start();

    // Kick off an initial sweep shortly after startup so the UI and the first
    // download benefit from real health data without blocking construction.
    QTimer::singleShot(1500, this, &GatewayService::checkHealthNow);
}

QVariantMap GatewayService::makeMap(const Gateway& g) const
{
    QVariantMap m;
    m.insert(QStringLiteral("url"), g.url);
    m.insert(QStringLiteral("host"), g.host.isEmpty() ? g.url : g.host);
    m.insert(QStringLiteral("builtin"), g.builtin);
    m.insert(QStringLiteral("local"), g.local);
    m.insert(QStringLiteral("enabled"), g.enabled);
    m.insert(QStringLiteral("preferred"), g.preferred);
    m.insert(QStringLiteral("responseMs"), g.responseMs);
    m.insert(QStringLiteral("successCount"), g.successCount);
    m.insert(QStringLiteral("failCount"), g.failCount);
    m.insert(QStringLiteral("lastCheckedMs"), g.lastCheckedMs);

    QString status;
    QString kind; // maps to UI status colors (success/warning/danger/muted)
    switch (g.health) {
        case Health::Healthy:  status = QStringLiteral("Healthy");  kind = QStringLiteral("success"); break;
        case Health::Degraded: status = QStringLiteral("Slow");     kind = QStringLiteral("warning"); break;
        case Health::Down:     status = QStringLiteral("Down");     kind = QStringLiteral("danger");  break;
        case Health::Unknown:
        default:               status = QStringLiteral("Unknown");  kind = QStringLiteral("muted");   break;
    }
    m.insert(QStringLiteral("status"), status);
    m.insert(QStringLiteral("statusKind"), kind);
    m.insert(QStringLiteral("health"), static_cast<int>(g.health));
    return m;
}

QVariantList GatewayService::gateways() const
{
    QVariantList out;
    out.reserve(m_gateways.size());
    for (const Gateway& g : m_gateways) out.append(makeMap(g));
    return out;
}

int GatewayService::enabledCount() const
{
    int n = 0;
    for (const Gateway& g : m_gateways) if (g.enabled) ++n;
    return n;
}

int GatewayService::healthyCount() const
{
    int n = 0;
    for (const Gateway& g : m_gateways)
        if (g.enabled && g.health == Health::Healthy) ++n;
    return n;
}

bool GatewayService::localNodeAvailable() const
{
    for (const Gateway& g : m_gateways)
        if (g.local && g.enabled && g.health == Health::Healthy) return true;
    return false;
}

QString GatewayService::hostForUrl(const QString& fullUrl) const
{
    const QString host = QUrl(fullUrl).host();
    return host.isEmpty() ? fullUrl : host;
}

void GatewayService::addCustomGateway(const QString& url)
{
    const QString base = normalizeBase(url);
    if (base.isEmpty()) return;
    for (const Gateway& g : m_gateways) {
        if (g.url.compare(base, Qt::CaseInsensitive) == 0) return; // dedupe
    }
    Gateway g;
    g.url = base;
    g.host = QUrl(base).host();
    g.builtin = false;
    g.enabled = true;
    m_gateways.append(g);
    save();
    emit gatewaysChanged();
    probe(m_gateways.size() - 1);
}

void GatewayService::removeGateway(int index)
{
    if (index < 0 || index >= m_gateways.size()) return;
    if (m_gateways[index].builtin) return; // built-ins are disabled, not removed
    m_gateways.remove(index);
    save();
    emit gatewaysChanged();
}

void GatewayService::setGatewayEnabled(int index, bool enabled)
{
    if (index < 0 || index >= m_gateways.size()) return;
    if (m_gateways[index].enabled == enabled) return;
    m_gateways[index].enabled = enabled;
    save();
    emit gatewaysChanged();
    if (enabled) probe(index);
}

void GatewayService::setGatewayPreferred(int index, bool preferred)
{
    if (index < 0 || index >= m_gateways.size()) return;
    if (m_gateways[index].preferred == preferred) return;
    m_gateways[index].preferred = preferred;
    save();
    emit gatewaysChanged();
}

void GatewayService::moveGatewayUp(int index)
{
    if (index <= 0 || index >= m_gateways.size()) return;
    m_gateways.swapItemsAt(index, index - 1);
    save();
    emit gatewaysChanged();
}

void GatewayService::moveGatewayDown(int index)
{
    if (index < 0 || index >= m_gateways.size() - 1) return;
    m_gateways.swapItemsAt(index, index + 1);
    save();
    emit gatewaysChanged();
}

void GatewayService::resetToDefaults()
{
    m_gateways = builtinGateways();
    save();
    emit gatewaysChanged();
    checkHealthNow();
}

void GatewayService::checkHealthNow()
{
    for (int i = 0; i < m_gateways.size(); ++i) {
        if (m_gateways[i].enabled) probe(i);
    }
}

void GatewayService::probe(int index)
{
    if (index < 0 || index >= m_gateways.size()) return;
    const Gateway& g = m_gateways[index];
    const QString url = g.url + QStringLiteral("/ipfs/") + probeCid();

    QNetworkRequest req{QUrl(url)};
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("genydl/1.0 (gateway-probe)"));
    req.setTransferTimeout(kProbeTimeoutMs);

    auto* timer = new QElapsedTimer;
    timer->start();
    // A HEAD is cheapest; gateways that reject HEAD still report reachability.
    QNetworkReply* reply = m_nam.head(req);

    const bool wasIdle = (m_inflight == 0);
    ++m_inflight;
    if (wasIdle) emit checkingChanged();

    // Capture the gateway URL (not the index) so reordering mid-sweep is safe.
    const QString gwUrl = g.url;
    connect(reply, &QNetworkReply::finished, this, [this, reply, timer, gwUrl]() {
        const int ms = static_cast<int>(timer->elapsed());
        delete timer;
        const bool ok = (reply->error() == QNetworkReply::NoError)
                        || (reply->error() == QNetworkReply::ContentOperationNotPermittedError); // HEAD refused but reachable
        reply->deleteLater();

        // Resolve the current index by URL (the pool may have changed).
        int idx = -1;
        for (int i = 0; i < m_gateways.size(); ++i) {
            if (m_gateways[i].url == gwUrl) { idx = i; break; }
        }
        if (idx >= 0) applyProbeResult(idx, ok, ms);

        if (m_inflight > 0) --m_inflight;
        if (m_inflight == 0) emit checkingChanged();
    });
}

void GatewayService::applyProbeResult(int index, bool ok, int responseMs)
{
    if (index < 0 || index >= m_gateways.size()) return;
    Gateway& g = m_gateways[index];
    g.lastCheckedMs = QDateTime::currentMSecsSinceEpoch();
    if (ok) {
        g.responseMs = responseMs;
        g.health = (responseMs > m_slowThresholdMs) ? Health::Degraded : Health::Healthy;
        ++g.successCount;
    } else {
        g.responseMs = -1;
        g.health = Health::Down;
        ++g.failCount;
    }
    emit gatewaysChanged();
}

QStringList GatewayService::orderedGatewayBases() const
{
    QVector<int> idx;
    for (int i = 0; i < m_gateways.size(); ++i)
        if (m_gateways[i].enabled) idx.append(i);

    // Rank so a proven-healthy gateway outranks an untested one, and an untested
    // one outranks a known-down one (Unknown's raw enum value of 0 would be
    // misleading otherwise).
    const auto rank = [](Health h) -> int {
        switch (h) {
            case Health::Healthy:  return 0;
            case Health::Degraded: return 1;
            case Health::Unknown:  return 2;
            case Health::Down:     return 3;
        }
        return 2;
    };
    std::stable_sort(idx.begin(), idx.end(), [&](int a, int b) {
        const Gateway& ga = m_gateways[a];
        const Gateway& gb = m_gateways[b];
        if (ga.preferred != gb.preferred) return ga.preferred;
        const int ra = rank(ga.health);
        const int rb = rank(gb.health);
        if (ra != rb) return ra < rb;
        if (ga.responseMs != gb.responseMs) {
            const int ta = ga.responseMs < 0 ? INT_MAX : ga.responseMs;
            const int tb = gb.responseMs < 0 ? INT_MAX : gb.responseMs;
            if (ta != tb) return ta < tb;
        }
        return false; // keep manual order
    });

    QStringList out;
    out.reserve(idx.size());
    for (int i : idx) out.append(m_gateways[i].url);
    return out;
}

void GatewayService::save() const
{
    QJsonArray arr;
    for (const Gateway& g : m_gateways) {
        QJsonObject o;
        o.insert(QStringLiteral("url"), g.url);
        o.insert(QStringLiteral("builtin"), g.builtin);
        o.insert(QStringLiteral("local"), g.local);
        o.insert(QStringLiteral("enabled"), g.enabled);
        o.insert(QStringLiteral("preferred"), g.preferred);
        arr.append(o);
    }
    QSettings settings;
    settings.setValue(kSettingsKey,
                      QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
}

void GatewayService::load()
{
    QSettings settings;
    const QString raw = settings.value(kSettingsKey).toString();
    if (raw.isEmpty()) return;
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (!doc.isArray()) return;
    const QJsonArray arr = doc.array();

    // Reconstruct the pool from saved order/policy, then ensure all built-ins
    // are still present (in case the default list grew between versions).
    QVector<Gateway> rebuilt;
    const QVector<Gateway> builtins = builtinGateways();
    QHash<QString, Gateway> builtinByUrl;
    for (const Gateway& b : builtins) builtinByUrl.insert(b.url, b);

    QSet<QString> seen;
    for (const QJsonValue& v : arr) {
        const QJsonObject o = v.toObject();
        const QString url = normalizeBase(o.value(QStringLiteral("url")).toString());
        if (url.isEmpty() || seen.contains(url)) continue;
        seen.insert(url);

        Gateway g;
        g.url = url;
        g.host = QUrl(url).host();
        if (builtinByUrl.contains(url)) {
            g = builtinByUrl.value(url); // keep builtin/local flags authoritative
        } else {
            g.builtin = o.value(QStringLiteral("builtin")).toBool(false);
            g.local = o.value(QStringLiteral("local")).toBool(false);
        }
        g.enabled = o.value(QStringLiteral("enabled")).toBool(true);
        g.preferred = o.value(QStringLiteral("preferred")).toBool(false);
        rebuilt.append(g);
    }
    // Append any built-ins not present in the saved set.
    for (const Gateway& b : builtins) {
        if (!seen.contains(b.url)) rebuilt.append(b);
    }
    if (!rebuilt.isEmpty()) m_gateways = rebuilt;
}
