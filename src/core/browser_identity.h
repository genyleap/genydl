#pragma once

#include <QString>

namespace genydl::browser {
// Public identity of the signed Firefox add-on on Mozilla Add-ons.
inline QString firefoxExtensionId()
{
    return QStringLiteral("browser@genyleap.com");
}
}
