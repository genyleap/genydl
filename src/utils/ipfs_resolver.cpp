module;
#include <QByteArray>
#include <QString>
#include <QStringList>
#include <QtGlobal>

module genydl.utils.ipfs_resolver;

namespace genydl::ipfs {

namespace {

// ---- multibase / multihash primitives -----------------------------------

const char kBase58Alphabet[] =
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

// RFC 4648 base32, lower-case, no padding (multibase prefix 'b').
const char kBase32Alphabet[] = "abcdefghijklmnopqrstuvwxyz234567";

//! Decode a base58btc string into bytes. Returns empty on invalid input.
QByteArray base58Decode(const QString& input)
{
    if (input.isEmpty()) return {};
    QByteArray bytes; // big-endian base-256 accumulator
    for (const QChar qc : input) {
        const char c = qc.toLatin1();
        const char* pos = nullptr;
        for (const char* p = kBase58Alphabet; *p; ++p) {
            if (*p == c) { pos = p; break; }
        }
        if (!pos) return {};
        int carry = static_cast<int>(pos - kBase58Alphabet);
        for (int i = bytes.size() - 1; i >= 0; --i) {
            carry += 58 * static_cast<unsigned char>(bytes[i]);
            bytes[i] = static_cast<char>(carry & 0xFF);
            carry >>= 8;
        }
        while (carry > 0) {
            bytes.prepend(static_cast<char>(carry & 0xFF));
            carry >>= 8;
        }
    }
    // Preserve leading '1's as leading zero bytes.
    for (const QChar qc : input) {
        if (qc != QLatin1Char('1')) break;
        bytes.prepend('\0');
    }
    return bytes;
}

//! Decode a lower-case RFC4648 base32 (no padding) string. Empty on failure.
QByteArray base32Decode(const QString& input)
{
    QByteArray out;
    quint32 buffer = 0;
    int bits = 0;
    for (const QChar qc : input) {
        const char c = qc.toLatin1();
        const char* pos = nullptr;
        for (const char* p = kBase32Alphabet; *p; ++p) {
            if (*p == c) { pos = p; break; }
        }
        if (!pos) return {};
        buffer = (buffer << 5) | static_cast<quint32>(pos - kBase32Alphabet);
        bits += 5;
        if (bits >= 8) {
            bits -= 8;
            out.append(static_cast<char>((buffer >> bits) & 0xFF));
        }
    }
    return out;
}

//! Read an unsigned LEB128 varint at offset; advances offset. ok=false on error.
quint64 readVarint(const QByteArray& data, int& offset, bool& ok)
{
    quint64 value = 0;
    int shift = 0;
    ok = false;
    while (offset < data.size()) {
        const quint8 byte = static_cast<quint8>(data[offset++]);
        value |= static_cast<quint64>(byte & 0x7F) << shift;
        if ((byte & 0x80) == 0) { ok = true; return value; }
        shift += 7;
        if (shift > 63) return 0;
    }
    return 0;
}

//! Decode the multibase prefix + payload portion of a CIDv1 string.
QByteArray multibaseDecode(const QString& cidText)
{
    if (cidText.isEmpty()) return {};
    const QChar prefix = cidText.at(0);
    const QString payload = cidText.mid(1);
    switch (prefix.toLatin1()) {
        case 'b': return base32Decode(payload);          // base32 lower
        case 'z': return base58Decode(payload);          // base58btc
        default:  return {};
    }
}

} // namespace

Cid parseCid(const QString& cidTextRaw)
{
    Cid cid;
    const QString cidText = cidTextRaw.trimmed();
    if (cidText.isEmpty()) return cid;

    // CIDv0: base58btc of (0x12 0x20 <32-byte sha2-256>). Always starts "Qm".
    if (cidText.startsWith(QLatin1String("Qm"))) {
        const QByteArray raw = base58Decode(cidText);
        if (raw.size() == 34
            && static_cast<quint8>(raw[0]) == HashSha2_256
            && static_cast<quint8>(raw[1]) == 0x20) {
            cid.valid = true;
            cid.version = 0;
            cid.codec = CodecDagPb;
            cid.hashType = HashSha2_256;
            cid.digest = raw.mid(2);
            cid.text = cidText;
        }
        return cid;
    }

    // CIDv1: multibase prefix + (version, codec, multihash).
    const QByteArray raw = multibaseDecode(cidText);
    if (raw.isEmpty()) return cid;

    int off = 0;
    bool ok = false;
    const quint64 version = readVarint(raw, off, ok);
    if (!ok || version != 1) return cid;
    const quint64 codec = readVarint(raw, off, ok);
    if (!ok) return cid;
    const quint64 hashType = readVarint(raw, off, ok);
    if (!ok) return cid;
    const quint64 digestLen = readVarint(raw, off, ok);
    if (!ok) return cid;
    if (digestLen == 0 || off + static_cast<int>(digestLen) != raw.size()) return cid;

    cid.valid = true;
    cid.version = 1;
    cid.codec = codec;
    cid.hashType = hashType;
    cid.digest = raw.mid(off, static_cast<int>(digestLen));
    cid.text = cidText;
    return cid;
}

Target parse(const QString& input)
{
    Target target;
    QString s = input.trimmed();
    if (s.isEmpty()) return target;

    // Strip an ipfs:// scheme.
    if (s.startsWith(QLatin1String("ipfs://"), Qt::CaseInsensitive)) {
        s = s.mid(7);
    } else {
        // Gateway-style path: take everything after the last "/ipfs/".
        const int marker = s.lastIndexOf(QLatin1String("/ipfs/"), -1, Qt::CaseInsensitive);
        if (marker >= 0) {
            s = s.mid(marker + 6);
        }
    }

    // Drop query/fragment before splitting CID from sub-path.
    const int q = s.indexOf(QLatin1Char('?'));
    if (q >= 0) s = s.left(q);
    const int h = s.indexOf(QLatin1Char('#'));
    if (h >= 0) s = s.left(h);

    QString cidText = s;
    QString subPath;
    const int slash = s.indexOf(QLatin1Char('/'));
    if (slash >= 0) {
        cidText = s.left(slash);
        subPath = s.mid(slash + 1);
        while (subPath.endsWith(QLatin1Char('/'))) subPath.chop(1);
    }

    const Cid cid = parseCid(cidText);
    if (!cid.valid) return target;

    target.valid = true;
    target.cid = cid;
    target.cidText = cidText;
    target.subPath = subPath;
    return target;
}

bool looksLikeIpfs(const QString& input)
{
    const QString s = input.trimmed();
    if (s.isEmpty()) return false;
    if (s.startsWith(QLatin1String("ipfs://"), Qt::CaseInsensitive)) return true;
    if (s.contains(QLatin1String("/ipfs/"), Qt::CaseInsensitive)) return true;
    // Bare CID: only treat a single token (no spaces) as a candidate.
    if (s.contains(QLatin1Char(' '))) return false;
    return parse(s).valid;
}

QStringList defaultGateways()
{
    return {
        QStringLiteral("https://ipfs.io"),
        QStringLiteral("https://dweb.link"),
        QStringLiteral("https://cloudflare-ipfs.com"),
        QStringLiteral("https://gateway.pinata.cloud"),
        QStringLiteral("https://w3s.link"),
    };
}

QString localGateway()
{
    return QStringLiteral("http://127.0.0.1:8080");
}

QString buildGatewayUrl(const QString& gatewayBase, const QString& cidText, const QString& subPath)
{
    QString base = gatewayBase;
    while (base.endsWith(QLatin1Char('/'))) base.chop(1);
    QString url = base + QStringLiteral("/ipfs/") + cidText;
    if (!subPath.isEmpty()) {
        url += QLatin1Char('/');
        url += subPath;
    }
    return url;
}

bool isSha256Verifiable(const Cid& cid)
{
    return cid.valid
        && cid.codec == CodecRaw
        && cid.hashType == HashSha2_256
        && cid.digest.size() == 32;
}

QString sha256Hex(const Cid& cid)
{
    if (!isSha256Verifiable(cid)) return {};
    return QString::fromLatin1(cid.digest.toHex());
}

QString suggestedFileName(const Target& target)
{
    if (!target.subPath.isEmpty()) {
        const int slash = target.subPath.lastIndexOf(QLatin1Char('/'));
        const QString last = slash >= 0 ? target.subPath.mid(slash + 1) : target.subPath;
        if (!last.isEmpty()) return last;
    }
    return target.cidText;
}

} // namespace genydl::ipfs
