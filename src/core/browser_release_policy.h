#pragma once

#include <QString>

// Release-time availability policy; native messaging transport, browser
// descriptors, host manifest generators and extension protocol stay generic.
// To ship a new tested browser later, enable it here and provide its verified
// store/extension ID and platform compatibility tests.
namespace genydl::browser {
inline bool availableInRelease(const QString& code)
{
    return code == QStringLiteral("firefox")
        || code == QStringLiteral("chrome")
        || code == QStringLiteral("opera");
}
}
