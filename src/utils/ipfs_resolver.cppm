/*!
 * @file        ipfs_resolver.cppm
 * @brief       IPFS input detection, CID parsing, and gateway URL building.
 * @details     Provides the helpers needed to turn an IPFS reference
 *              (an `ipfs://` URI, a `/ipfs/<cid>` path, or a bare CID) into a
 *              downloadable HTTP gateway URL, plus the metadata required to
 *              perform content-address verification.
 *
 *              IPFS content is fetched over ordinary HTTP gateways, so the
 *              existing DownloaderTask engine handles the transfer. This module
 *              only supplies:
 *              - detection of IPFS-shaped inputs,
 *              - decoding/validation of the CID (multibase + multihash),
 *              - an ordered list of gateway URLs for failover, and
 *              - the SHA-256 digest used to verify content-addressed data when
 *                the CID is a raw (single-block) sha2-256 block.
 *
 *              Full UnixFS DAG verification (CAR reassembly) is intentionally
 *              out of scope; for non-raw CIDs the digest is reported as
 *              unavailable rather than guessed.
 *
 * @author      <a href='https://github.com/thecompez'>Kambiz Asadzadeh</a>
 * @since       08 Jun 2026
 * @copyright   Copyright (c) 2026 Genyleap. All rights reserved.
 * @license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
 */

module;
#include <QByteArray>
#include <QString>
#include <QStringList>

#ifndef Q_MOC_RUN
export module genydl.utils.ipfs_resolver;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

GENYDL_MODULE_EXPORT namespace genydl::ipfs {

//!< @brief Multicodec id for raw (single-block) content.
inline constexpr quint64 CodecRaw = 0x55;
//!< @brief Multicodec id for dag-pb (UnixFS) content.
inline constexpr quint64 CodecDagPb = 0x70;
//!< @brief Multihash id for sha2-256.
inline constexpr quint64 HashSha2_256 = 0x12;

/**
 * @brief Decoded Content Identifier.
 *
 * `valid` is false when the input could not be decoded into a well-formed CID.
 */
struct Cid {
    bool valid = false;       //!< Whether decoding succeeded.
    int version = 0;          //!< CID version (0 or 1).
    quint64 codec = 0;        //!< Multicodec id (raw, dag-pb, ...).
    quint64 hashType = 0;     //!< Multihash function id (sha2-256, ...).
    QByteArray digest;        //!< Raw multihash digest bytes.
    QString text;             //!< Canonical CID string as supplied.
};

/**
 * @brief A parsed IPFS reference: a CID plus an optional sub-path.
 */
struct Target {
    bool valid = false;       //!< Whether the input is a usable IPFS reference.
    Cid cid;                  //!< Decoded CID.
    QString cidText;          //!< CID string.
    QString subPath;          //!< Path under the CID (no leading slash), may be empty.
};

/**
 * @brief Heuristically decide whether an input looks like an IPFS reference.
 * @param input Raw user input (URL, path, or bare CID).
 * @return True for `ipfs://...`, `.../ipfs/<cid>...`, or a bare valid CID.
 */
bool looksLikeIpfs(const QString& input);

/**
 * @brief Parse an IPFS reference into a CID and optional sub-path.
 * @param input Raw user input.
 * @return Parsed target; `valid` is false when the CID cannot be decoded.
 */
Target parse(const QString& input);

/**
 * @brief Decode and validate a CID string (CIDv0 base58btc or CIDv1 base32).
 * @param cidText CID string.
 * @return Decoded CID; `valid` is false on failure.
 */
Cid parseCid(const QString& cidText);

/**
 * @brief Ordered list of default public gateway base URLs (no trailing slash).
 */
QStringList defaultGateways();

/**
 * @brief Local IPFS node gateway base URL, probed first when reachable.
 */
QString localGateway();

/**
 * @brief Build a full gateway URL for a CID and optional sub-path.
 * @param gatewayBase Gateway base, e.g. "https://ipfs.io" (no trailing slash).
 * @param cidText CID string.
 * @param subPath Optional path under the CID.
 * @return e.g. "https://ipfs.io/ipfs/<cid>/<subPath>".
 */
QString buildGatewayUrl(const QString& gatewayBase, const QString& cidText, const QString& subPath);

/**
 * @brief Whether a CID's content can be byte-verified against its SHA-256 digest.
 * @param cid Decoded CID.
 * @return True only for raw-codec sha2-256 CIDs (single-block content).
 */
bool isSha256Verifiable(const Cid& cid);

/**
 * @brief Hex-encoded SHA-256 digest carried by a verifiable CID.
 * @param cid Decoded CID.
 * @return Lower-case hex digest, or empty when not verifiable.
 */
QString sha256Hex(const Cid& cid);

/**
 * @brief Suggest a display/output file name for an IPFS target.
 * @param target Parsed target.
 * @return Last path segment, or the CID when no sub-path is present.
 */
QString suggestedFileName(const Target& target);

} // namespace genydl::ipfs
