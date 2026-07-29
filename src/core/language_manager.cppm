/*!
 * @file language_manager.cppm
 * @brief Runtime language, locale, and layout-direction management.
 */

module;
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTranslator>
#include <QVariantList>

#ifndef Q_MOC_RUN
#  include <QtCore/qtmochelpers.h>
export module genydl.core.language_manager;
#endif

#ifdef Q_MOC_RUN
#define GENYDL_MODULE_EXPORT
#else
#define GENYDL_MODULE_EXPORT export
#endif

GENYDL_MODULE_EXPORT class LanguageManager final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentLanguage READ currentLanguage WRITE setLanguage NOTIFY currentLanguageChanged)
    Q_PROPERTY(QString currentLocale READ currentLocale NOTIFY currentLanguageChanged)
    Q_PROPERTY(bool rightToLeft READ rightToLeft NOTIFY currentLanguageChanged)
    Q_PROPERTY(QVariantList availableLanguages READ availableLanguages NOTIFY currentLanguageChanged)

public:
    explicit LanguageManager(QObject* parent = nullptr);
    ~LanguageManager() override;

    QString currentLanguage() const;
    QString currentLocale() const;
    bool rightToLeft() const;
    QVariantList availableLanguages() const;

    void setQmlEngine(QQmlEngine* engine);
    Q_INVOKABLE bool setLanguage(const QString& languageCode);
    Q_INVOKABLE QString nativeLanguageName(const QString& languageCode) const;
    Q_INVOKABLE QString statusLabel(const QString& status) const;
    Q_INVOKABLE QString categoryLabel(const QString& category) const;
    Q_INVOKABLE QString queueLabel(const QString& queue) const;
    Q_INVOKABLE QString pauseReasonLabel(const QString& reason) const;
    Q_INVOKABLE QString releaseStatusLabel(const QString& status) const;
    Q_INVOKABLE QString gatewayHealthLabel(int health) const;

signals:
    void currentLanguageChanged();
    void languageChangeFailed(const QString& languageCode);

private:
    QString normalizeLanguageCode(const QString& languageCode) const;
    QString resolveLocale(const QString& languageCode) const;
    bool applyLanguage(bool persist);

    QString m_currentLanguage;
    QString m_currentLocale;
    QQmlEngine* m_engine = nullptr;
    QTranslator* m_translator = nullptr;
};

#include "language_manager.moc"
