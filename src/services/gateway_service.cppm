/*!
 * @file        gateway_service.cppm
 * @brief       IPFS gateway registry, health monitoring, and priority ordering.
 * @details     The Smart Gateway System is the principal differentiator of
 *              GenyDL's decentralized download support over a plain browser.
 *
 *              Where a browser typically resolves IPFS content through a single
 *              hard-coded gateway, GatewayService maintains an ordered pool of
 *              gateways (built-in public gateways, an optional local node, and
 *              user-supplied custom gateways) and continuously tracks their
 *              health and response time. The download engine consumes
 *              orderedGatewayBases() so that every IPFS download automatically
 *              prefers the healthiest, fastest, user-preferred gateway and falls
 *              back through the remainder on error.
 *
 *              Responsibilities:
 *              - Registry: built-in + local-node + custom gateways
 *              - Per-gateway policy: enabled / preferred / ordering
 *              - Health monitoring: periodic reachability + response-time probes
 *              - Priority resolution for the download manager
 *              - Persistence of user policy across sessions
 *              - A QML-facing model for the settings UI
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       08 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QObject>
#include <QElapsedTimer>
#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QPointer>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#ifndef Q_MOC_RUN
#  include <QtCore/qtmochelpers.h>
export module genydl.services.gateway_service;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

/**
 * @brief Manages the pool of IPFS gateways and their health.
 *
 * Exposed to QML as the `gatewayService` context property. The settings UI
 * binds to the `gateways` property (a list of plain maps) and drives policy
 * through the invokable mutators; the download manager calls
 * orderedGatewayBases() at download time.
 */
GENYDL_MODULE_EXPORT class GatewayService : public QObject {
    Q_OBJECT

    //!< @brief Gateway pool as a list of display maps (for the settings UI).
    Q_PROPERTY(QVariantList gateways READ gateways NOTIFY gatewaysChanged)

    //!< @brief Number of gateways currently enabled.
    Q_PROPERTY(int enabledCount READ enabledCount NOTIFY gatewaysChanged)

    //!< @brief Number of enabled gateways currently rated healthy.
    Q_PROPERTY(int healthyCount READ healthyCount NOTIFY gatewaysChanged)

    //!< @brief Whether a health sweep is currently in progress.
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)

    //!< @brief Whether a reachable local IPFS node was detected.
    Q_PROPERTY(bool localNodeAvailable READ localNodeAvailable NOTIFY gatewaysChanged)

public:
    /**
     * @brief Health classification for a gateway.
     */
    enum class Health {
        Unknown = 0,   //!< Not yet probed.
        Healthy = 1,   //!< Reachable with acceptable latency.
        Degraded = 2,  //!< Reachable but slow.
        Down = 3       //!< Unreachable or error.
    };
    Q_ENUM(Health)

    /**
     * @brief Construct the gateway service and load persisted policy.
     * @param parent Optional QObject parent.
     */
    explicit GatewayService(QObject* parent = nullptr);

    // ---- QML-facing accessors ----

    //!< @brief Pool as display maps; see makeMap() for keys.
    QVariantList gateways() const;

    //!< @brief Count of enabled gateways.
    int enabledCount() const;

    //!< @brief Count of enabled + healthy gateways.
    int healthyCount() const;

    //!< @brief Whether a sweep is in flight.
    bool checking() const { return m_inflight > 0; }

    //!< @brief Whether the local node probed healthy.
    bool localNodeAvailable() const;

    // ---- QML-facing mutators ----

    /**
     * @brief Add a user-supplied custom gateway.
     * @param url Gateway base, e.g. "https://my.gateway" (trailing slash and a
     *            trailing "/ipfs" segment are tolerated and normalized away).
     */
    Q_INVOKABLE void addCustomGateway(const QString& url);

    /**
     * @brief Remove a custom gateway (built-in gateways cannot be removed).
     * @param index Row index in gateways().
     */
    Q_INVOKABLE void removeGateway(int index);

    /**
     * @brief Enable or disable a gateway for downloads and probing.
     */
    Q_INVOKABLE void setGatewayEnabled(int index, bool enabled);

    /**
     * @brief Mark a gateway as preferred; preferred gateways sort first.
     */
    Q_INVOKABLE void setGatewayPreferred(int index, bool preferred);

    /**
     * @brief Move a gateway up one position in the manual priority order.
     */
    Q_INVOKABLE void moveGatewayUp(int index);

    /**
     * @brief Move a gateway down one position in the manual priority order.
     */
    Q_INVOKABLE void moveGatewayDown(int index);

    /**
     * @brief Trigger an immediate health sweep of all enabled gateways.
     */
    Q_INVOKABLE void checkHealthNow();

    /**
     * @brief Restore the built-in gateway list and clear custom entries.
     */
    Q_INVOKABLE void resetToDefaults();

    /**
     * @brief Human-readable host label for a full gateway URL (for displaying
     *        which gateway actually served a download).
     * @param fullUrl A full gateway URL such as "https://ipfs.io/ipfs/<cid>".
     * @return The gateway host, e.g. "ipfs.io", or the input on failure.
     */
    Q_INVOKABLE QString hostForUrl(const QString& fullUrl) const;

    // ---- Download-manager facing ----

    /**
     * @brief Ordered list of enabled gateway base URLs for failover.
     *
     * Sort key: preferred first, then by health (healthy < degraded < unknown
     * < down), then by measured response time ascending, then by manual order.
     * @return Ordered gateway bases (no trailing slash). Empty if none enabled.
     */
    QStringList orderedGatewayBases() const;

signals:
    //!< @brief Emitted when the pool, policy, or health changes.
    void gatewaysChanged();

    //!< @brief Emitted when a sweep starts or finishes.
    void checkingChanged();

private:
    /**
     * @brief One gateway entry: identity, policy, and runtime health.
     */
    struct Gateway {
        QString url;                    //!< Base URL, no trailing slash.
        QString host;                   //!< Cached host for display.
        bool builtin = false;           //!< Shipped default (cannot be removed).
        bool local = false;             //!< Loopback / local node.
        bool enabled = true;            //!< Participates in downloads & probes.
        bool preferred = false;         //!< Sorts ahead of non-preferred peers.
        Health health = Health::Unknown;//!< Last probe classification.
        int responseMs = -1;            //!< Last probe round-trip (ms), -1 = none.
        qint64 lastCheckedMs = 0;       //!< Epoch ms of last probe.
        int successCount = 0;           //!< Lifetime successful probes.
        int failCount = 0;              //!< Lifetime failed probes.
    };

    //!< @brief Build the shipped default gateway list (publics + local node).
    static QVector<Gateway> builtinGateways();

    //!< @brief Convert a Gateway to a QML-friendly display map.
    QVariantMap makeMap(const Gateway& g) const;

    //!< @brief Normalize a user URL into a clean gateway base.
    static QString normalizeBase(const QString& url);

    //!< @brief Probe a single gateway by index.
    void probe(int index);

    //!< @brief Apply a probe result and emit change notifications.
    void applyProbeResult(int index, bool ok, int responseMs);

    //!< @brief Persist user policy (order, enabled, preferred, custom list).
    void save() const;

    //!< @brief Load persisted user policy and merge with built-ins.
    void load();

    QVector<Gateway> m_gateways;                 //!< The gateway pool, in priority order.
    QNetworkAccessManager m_nam;                 //!< Probe transport.
    QTimer m_healthTimer;                        //!< Periodic sweep timer.
    int m_inflight = 0;                          //!< Outstanding probe replies.
    int m_slowThresholdMs = 2500;                //!< Above this latency = Degraded.

    //!< @brief Well-known empty-directory CID used as a cheap probe target.
    static QString probeCid();
};

#include "gateway_service.moc"
