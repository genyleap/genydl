/*!
    \file        FontSystem.qml
    \brief       Provides the FontSystem core QML definition for GENYDL.
    \details     This file contains shared FontSystem values and behavior used across the GENYDL QML user interface.

    \author      Kambiz Asadzadeh <https://github.com/thecompez>
    \copyright   Copyright (c) 2026 Genyleap. All rights reserved.
    \license     https://github.com/genyleap/genydl/blob/main/LICENSE.md
*/

pragma Singleton
import QtQuick

Item {
    property alias getAwesomeBrand: fontAwesomeBrand
    property alias getAwesomeRegular: fontAwesomeRegular
    property alias getAwesomeLight: fontAwesomeRegular
    property alias getAwesomeThin: fontAwesomeRegular
    property alias getAwesomeSolid: fontAwesomeSolid

    property alias getContentFont: contentFontRegular
    property alias getTitleBoldFont: contentFontBold
    property alias getContentFontRegular: contentFontRegular
    property alias getContentFontMedium: contentFontMedium
    property alias getContentFontSemiBold: contentFontSemiBold
    property alias getContentFontBold: contentFontBold
    property alias getContentFontThin: contentFontThin

    property alias getFontSize: fontSize

    QtObject {
        id: fontSize

        readonly property int h1: 32
        readonly property int h2: 24
        readonly property double h3: 18.72
        readonly property int h4: 16
        readonly property double h5: 13.28
        readonly property double h6: 10.72

        readonly property int content: 14
    }

    FontLoader {
        id: fontAwesomeBrand
        source: "qrc:/resources/fonts/Font Awesome 7 Brands-Regular-400.otf"
    }

    FontLoader {
        id: fontAwesomeRegular
        source: "qrc:/resources/fonts/Font Awesome 7 Free-Regular-400.otf"
    }

    FontLoader {
        id: fontAwesomeSolid
        source: "qrc:/resources/fonts/Font Awesome 7 Free-Solid-900.otf"
    }

    FontLoader {
        id: contentFontThin
        source: "qrc:/resources/fonts/Inter-Thin.ttf"
    }

    FontLoader {
        id: contentFontRegular
        source: "qrc:/resources/fonts/Inter-Regular.ttf"
    }

    FontLoader {
        id: contentFontMedium
        source: "qrc:/resources/fonts/Inter-Medium.ttf"
    }

    FontLoader {
        id: contentFontSemiBold
        source: "qrc:/resources/fonts/Inter-SemiBold.ttf"
    }

    FontLoader {
        id: contentFontBold
        source: "qrc:/resources/fonts/Inter-Bold.ttf"
    }
}