module;
#include <QIcon>
#include <QString>

module genydl.ui.tray_icon_provider;

namespace genydl::ui {

QIcon createTrayIcon()
{
#if defined(Q_OS_MACOS)
    // macOS menu bar: use the monochrome template glyph and mark it as a mask so
    // AppKit tints it for the current light/dark appearance.
    QIcon icon(QStringLiteral(":/resources/icons/tray/GenyDLTemplate.png"));
    icon.setIsMask(true);
    return icon;
#else
    // Windows / Linux: colored tray icon.
    return QIcon(QStringLiteral(":/resources/icons/tray/GenyDL.png"));
#endif
}

} // namespace genydl::ui
