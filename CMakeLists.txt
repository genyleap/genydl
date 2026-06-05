# Copyright (C) 2026 Genyleap LLC.
# SPDX-License-Identifier: LicenseRef-Geny-Commercial OR MIT

cmake_minimum_required(VERSION 3.28)

# -----------------------------------------------------------------------------
# TONDAR CMakeLists
# - Cross-platform build with Qt 6.8+
# - C++23 + C++20 modules
# - Packaging via CPack:
#     Windows: NSIS + ZIP
#     macOS:   DragNDrop DMG
#     Linux:   TGZ
# - Layout matches GenyConnect:
#     Windows: package root
#     macOS:   .app at DMG root
#     Linux:   bin/
# -----------------------------------------------------------------------------

# -------------------------
# Project Definition
# -------------------------
set(PROJECT_NAME "Tondar")
set(PROJECT_REAL_NAME "Tondar")
set(APP_NAME "${PROJECT_REAL_NAME}")

set(PROJECT_VERSION_MAJOR 1)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 32)
set(PROJECT_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

# -------------------------
# Target OS / Arch
# -------------------------
set(TONDAR_TARGET_BUILD_ARCH "" CACHE STRING "Override target arch for output build/package (arm64|x86_64)")

# Must be defined before project() on macOS.
set(TONDAR_MACOS_DEPLOYMENT_TARGET "15.1" CACHE STRING "Minimum macOS version")

if(APPLE)
    if(NOT TONDAR_TARGET_BUILD_ARCH)
        set(TONDAR_TARGET_BUILD_ARCH "arm64" CACHE STRING "Override target arch for output build/package (arm64|x86_64)" FORCE)
    endif()

    set(CMAKE_OSX_ARCHITECTURES "${TONDAR_TARGET_BUILD_ARCH}" CACHE STRING "Build architecture" FORCE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${TONDAR_MACOS_DEPLOYMENT_TARGET}" CACHE STRING "Minimum macOS version" FORCE)
endif()

project(${PROJECT_NAME} VERSION ${PROJECT_VERSION} LANGUAGES CXX)

if(POLICY CMP0155)
    cmake_policy(SET CMP0155 NEW)
endif()

# -------------------------
# Detect Windows generator architecture
# -------------------------
if(WIN32 AND NOT TONDAR_TARGET_BUILD_ARCH)
    if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64$")
        set(TONDAR_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected Windows target arch" FORCE)
    elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$|^[Ww]in64$|^[Aa][Mm][Dd]64$")
        set(TONDAR_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected Windows target arch" FORCE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|arm64|aarch64")
        set(TONDAR_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected Windows target arch" FORCE)
    else()
        set(TONDAR_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected Windows target arch" FORCE)
    endif()
elseif(NOT TONDAR_TARGET_BUILD_ARCH)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|arm64|aarch64")
        set(TONDAR_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected target arch" FORCE)
    else()
        set(TONDAR_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected target arch" FORCE)
    endif()
endif()

if(WIN32 AND CMAKE_GENERATOR MATCHES "Visual Studio" AND NOT CMAKE_GENERATOR_PLATFORM)
    message(WARNING
        "Visual Studio generator platform is empty. "
        "Use -A x64 or -A ARM64 to avoid wrong Windows architecture/package detection."
    )
endif()

message(STATUS "CMake generator: ${CMAKE_GENERATOR}")
message(STATUS "CMake generator platform: ${CMAKE_GENERATOR_PLATFORM}")
message(STATUS "CMake system processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "TONDAR target build arch: ${TONDAR_TARGET_BUILD_ARCH}")

# Release/RelWithDebInfo generator-expression.
set(TONDAR_IS_RELEASE "$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>>")

# -------------------------
# Options
# -------------------------
option(TONDAR_USE_MODULES "Enable C++20 modules" ON)
option(TONDAR_LLVM_AUTO_SCAN "Auto-detect LLVM/clang for modules" ON)
option(TONDAR_QT_AUTO_SCAN "Auto-detect Qt installation prefix" ON)
option(TONDAR_BUILD_TESTS "Build backend tests" ON)

option(TONDAR_MACOS_POSTBUILD_DEPLOY "Run macdeployqt on the build .app in POST_BUILD" ON)
option(TONDAR_MACOS_CODESIGN "Codesign the .app after macdeployqt" ON)

set(TONDAR_CODESIGN_IDENTITY "-" CACHE STRING
    "macOS codesign identity. Use '-' for ad-hoc signing, or 'Developer ID Application: ...' for release."
)

set(TONDAR_CODESIGN_ENTITLEMENTS "" CACHE FILEPATH
    "Optional entitlements plist path for codesign."
)

option(TONDAR_MACDEPLOYQT_ALWAYS_OVERWRITE "Pass -always-overwrite to macdeployqt" OFF)
option(TONDAR_MACDEPLOYQT_NO_STRIP "Pass -no-strip to macdeployqt" OFF)

option(TONDAR_WINDOWS_INSTALL_DEPLOY
    "Run windeployqt during install() so CPack includes Qt/QML dependencies" ON
)

option(TONDAR_WINDEPLOYQT_COMPILER_RUNTIME
    "Pass --compiler-runtime to windeployqt" ON
)

option(TONDAR_WINDEPLOYQT_TRANSLATIONS
    "Include Qt translations via windeployqt" OFF
)

option(TONDAR_LINUX_INSTALL_DEPLOY
    "Run Qt Linux deployment during install() so CPack TGZ includes Qt/QML dependencies" ON
)

option(TONDAR_LINUX_DEPLOY_TRANSLATIONS
    "Include Qt translations in Linux deployment package" OFF
)

option(TONDAR_BUNDLE_DOCS
    "Install README and LICENSE at package root and NSIS wizard" ON
)

set(TONDAR_TARGET_OS "" CACHE STRING "Override target OS for output naming (macos|linux|windows)")
set(TONDAR_TARGET_ARCH "${TONDAR_TARGET_BUILD_ARCH}" CACHE STRING "Override target arch for output naming (arm64|x86_64)" FORCE)
set(TONDAR_OUTPUT_NAME "" CACHE STRING "Optional explicit output name")

# -------------------------
# Normalize OS / Arch
# -------------------------
if(TONDAR_TARGET_OS AND NOT TONDAR_TARGET_OS STREQUAL "")
    string(TOLOWER "${TONDAR_TARGET_OS}" TONDAR_OS)
else()
    if(APPLE)
        set(TONDAR_OS "macos")
    elseif(WIN32)
        set(TONDAR_OS "windows")
    else()
        set(TONDAR_OS "linux")
    endif()
endif()

set(TONDAR_ARCH_RAW "")

if(TONDAR_TARGET_ARCH AND NOT TONDAR_TARGET_ARCH STREQUAL "")
    set(TONDAR_ARCH_RAW "${TONDAR_TARGET_ARCH}")
elseif(APPLE AND CMAKE_OSX_ARCHITECTURES)
    list(GET CMAKE_OSX_ARCHITECTURES 0 TONDAR_ARCH_RAW)
elseif(DEFINED CMAKE_SYSTEM_PROCESSOR AND CMAKE_SYSTEM_PROCESSOR)
    set(TONDAR_ARCH_RAW "${CMAKE_SYSTEM_PROCESSOR}")
else()
    set(TONDAR_ARCH_RAW "x86_64")
endif()

string(TOLOWER "${TONDAR_ARCH_RAW}" TONDAR_ARCH)

if(TONDAR_ARCH MATCHES "^(arm64|aarch64|arm64-v8a)$")
    set(TONDAR_ARCH "arm64")
elseif(TONDAR_ARCH MATCHES "^(x86_64|amd64|x64|64)$")
    set(TONDAR_ARCH "x86_64")
endif()

if(TONDAR_OUTPUT_NAME AND NOT TONDAR_OUTPUT_NAME STREQUAL "")
    set(TONDAR_FINAL_OUTPUT_NAME "${TONDAR_OUTPUT_NAME}")
else()
    set(TONDAR_FINAL_OUTPUT_NAME "${APP_NAME}")
endif()

message(STATUS "TONDAR build: OS='${TONDAR_OS}' ARCH='${TONDAR_ARCH}'")
message(STATUS "TONDAR output name: ${TONDAR_FINAL_OUTPUT_NAME}")

# -------------------------
# Final packages folder
# -------------------------
set(TONDAR_FINAL_ROOT "${CMAKE_BINARY_DIR}/final")
set(TONDAR_FINAL_DIR "${TONDAR_FINAL_ROOT}/${TONDAR_OS}-${TONDAR_ARCH}")
file(MAKE_DIRECTORY "${TONDAR_FINAL_DIR}")
message(STATUS "TONDAR final output folder: ${TONDAR_FINAL_DIR}")

# -------------------------
# Metadata
# -------------------------
set(TONDAR_VENDOR "Genyleap")
set(TONDAR_PACKAGE_CONTACT "info@genyleap.com")
set(TONDAR_PACKAGE_SUMMARY "TONDAR Internet Download Manager")
set(TONDAR_COPYRIGHT "Copyright 2026 by Genyleap LLC")
set(TONDAR_BUNDLE_IDENTIFIER "com.genyleap.tondar")

set(TONDAR_MACOS_ICON_FILE "Tondar.icns")
set(TONDAR_MACOS_ICON_ICNS "${CMAKE_CURRENT_SOURCE_DIR}/Tondar.icns")
set(TONDAR_WINDOWS_ICON_ICO "${CMAKE_CURRENT_SOURCE_DIR}/Tondar.ico")
set(TONDAR_LINUX_ICON_PNG "${CMAKE_CURRENT_SOURCE_DIR}/Tondar.png")

set(TONDAR_MACOS_INFO_PLIST_IN "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/Info.plist.in")
set(TONDAR_MACOS_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/generated/Info.plist")

set(TONDAR_WINDOWS_RC_IN "${CMAKE_CURRENT_SOURCE_DIR}/properties/Windows/app.rc.in")
set(TONDAR_WINDOWS_RC "${CMAKE_CURRENT_BINARY_DIR}/generated/tondar_app.rc")

set(TONDAR_RC_FILE_VERSION "${PROJECT_VERSION_MAJOR},${PROJECT_VERSION_MINOR},${PROJECT_VERSION_PATCH},0")
set(TONDAR_RC_PRODUCT_VERSION "${PROJECT_VERSION_MAJOR},${PROJECT_VERSION_MINOR},${PROJECT_VERSION_PATCH},0")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated")

if(EXISTS "${TONDAR_MACOS_INFO_PLIST_IN}")
    configure_file("${TONDAR_MACOS_INFO_PLIST_IN}" "${TONDAR_MACOS_INFO_PLIST}" @ONLY)
endif()

if(WIN32 AND EXISTS "${TONDAR_WINDOWS_RC_IN}")
    file(TO_CMAKE_PATH "${TONDAR_WINDOWS_ICON_ICO}" TONDAR_WINDOWS_ICON_ICO_RC)
    configure_file("${TONDAR_WINDOWS_RC_IN}" "${TONDAR_WINDOWS_RC}" @ONLY)
endif()

# -------------------------
# macOS SDK for Homebrew LLVM
# -------------------------
if(APPLE)
    execute_process(
        COMMAND xcrun --sdk macosx --show-sdk-path
        OUTPUT_VARIABLE TONDAR_MACOS_SDK
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(TONDAR_MACOS_SDK)
        set(CMAKE_OSX_SYSROOT "${TONDAR_MACOS_SDK}" CACHE PATH "macOS SDK" FORCE)
    endif()
endif()

# -------------------------
# Compiler / module checks
# -------------------------
set(TONDAR_LLVM_HINTS "")

if(TONDAR_LLVM_AUTO_SCAN)
    if(DEFINED ENV{LLVM_ROOT})
        list(APPEND TONDAR_LLVM_HINTS "$ENV{LLVM_ROOT}/bin")
    endif()

    if(DEFINED ENV{LLVM_HOME})
        list(APPEND TONDAR_LLVM_HINTS "$ENV{LLVM_HOME}/bin")
    endif()

    if(DEFINED ENV{LLVM_DIR})
        list(APPEND TONDAR_LLVM_HINTS "$ENV{LLVM_DIR}/bin")
    endif()

    find_program(TONDAR_BREW brew HINTS /opt/homebrew/bin /usr/local/bin)

    if(TONDAR_BREW)
        execute_process(
            COMMAND "${TONDAR_BREW}" --prefix llvm
            OUTPUT_VARIABLE TONDAR_BREW_LLVM_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(TONDAR_BREW_LLVM_PREFIX)
            list(APPEND TONDAR_LLVM_HINTS "${TONDAR_BREW_LLVM_PREFIX}/bin")
        endif()
    endif()
endif()

find_program(TONDAR_CLANG NAMES clang HINTS ${TONDAR_LLVM_HINTS})
find_program(TONDAR_CLANGXX NAMES clang++ clang-cl HINTS ${TONDAR_LLVM_HINTS})
find_program(TONDAR_CLANG_SCAN_DEPS NAMES clang-scan-deps HINTS ${TONDAR_LLVM_HINTS})

if(NOT TONDAR_CLANG_SCAN_DEPS AND CMAKE_CXX_COMPILER)
    get_filename_component(TONDAR_CXX_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)

    if(TONDAR_CXX_DIR)
        find_program(TONDAR_CLANG_SCAN_DEPS
            NAMES clang-scan-deps
            HINTS "${TONDAR_CXX_DIR}"
        )
    endif()
endif()

set(TONDAR_CLANGXX_IS_APPLE_PATH FALSE)

if(TONDAR_CLANGXX MATCHES "^/usr/bin/clang\\+\\+$" OR
   TONDAR_CLANGXX MATCHES "XcodeDefault\\.xctoolchain")
    set(TONDAR_CLANGXX_IS_APPLE_PATH TRUE)
endif()

if(TONDAR_CLANG_SCAN_DEPS AND NOT DEFINED CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS)
    set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS
        "${TONDAR_CLANG_SCAN_DEPS}"
        CACHE FILEPATH "clang-scan-deps for C++20 modules"
    )
endif()

# -------------------------
# Standard compile flags
# -------------------------
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(MSVC)
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    add_compile_options(/Zc:__cplusplus /permissive-)
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

if(NOT "cppm" IN_LIST CMAKE_AUTOMOC_EXTENSIONS)
    list(APPEND CMAKE_AUTOMOC_EXTENSIONS "cppm")
endif()

if(TONDAR_USE_MODULES)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        if(TONDAR_CLANGXX AND TONDAR_CLANG_SCAN_DEPS AND NOT TONDAR_CLANGXX_IS_APPLE_PATH)
            message(FATAL_ERROR
                "AppleClang is active in this build directory. Delete build directory and reconfigure with LLVM clang:\n"
                "  -DCMAKE_C_COMPILER=${TONDAR_CLANG}\n"
                "  -DCMAKE_CXX_COMPILER=${TONDAR_CLANGXX}\n"
                "  -DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${TONDAR_CLANG_SCAN_DEPS}\n"
                "or set -DTONDAR_USE_MODULES=OFF."
            )
        else()
            message(FATAL_ERROR
                "AppleClang does not provide stable module scanning here. "
                "Install LLVM clang or set -DTONDAR_USE_MODULES=OFF."
            )
        endif()
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        message(FATAL_ERROR
            "GCC is not supported for C++ modules here. "
            "Use Clang/MSVC or disable modules."
        )
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND NOT CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS)
        message(FATAL_ERROR
            "C++ modules require clang-scan-deps. "
            "Install LLVM or set CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS."
        )
    endif()
else()
    message(FATAL_ERROR
        "TONDAR_USE_MODULES=OFF is not supported in this source tree because backend sources import project modules. "
        "Build with TONDAR_USE_MODULES=ON and a compiler that supports module dependency scanning."
    )
endif()

# -------------------------
# Qt discovery helpers
# -------------------------
if(Qt6_DIR AND NOT EXISTS "${Qt6_DIR}/Qt6Config.cmake")
    message(STATUS "Ignoring invalid Qt6_DIR='${Qt6_DIR}' because Qt6Config.cmake was not found.")
    unset(Qt6_DIR CACHE)
    set(Qt6_DIR "")
endif()

if(DEFINED ENV{QTDIR})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{QTDIR}")
endif()

if(DEFINED ENV{QT_DIR})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{QT_DIR}")
endif()

if(DEFINED ENV{Qt6_ROOT})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{Qt6_ROOT}")
endif()

if(DEFINED ENV{QT_ROOT})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{QT_ROOT}")
endif()

if(DEFINED ENV{CMAKE_PREFIX_PATH})
    list(APPEND CMAKE_PREFIX_PATH "$ENV{CMAKE_PREFIX_PATH}")
endif()

if(TONDAR_QT_AUTO_SCAN AND NOT Qt6_DIR)
    set(tondar_qt_candidates "")

    set(tondar_home "${CMAKE_USER_HOME_DIRECTORY}")

    if(NOT tondar_home AND DEFINED ENV{HOME})
        set(tondar_home "$ENV{HOME}")
    endif()

    if(APPLE)
        file(GLOB tondar_qt_candidates
            "${tondar_home}/Qt/*/macos"
            "${tondar_home}/Qt/*/clang_64"
            "/opt/Qt/*/macos"
            "/usr/local/Qt/*/macos"
        )
    elseif(WIN32)
        if(TONDAR_TARGET_BUILD_ARCH STREQUAL "arm64")
            file(GLOB tondar_qt_candidates
                "C:/Qt/*/msvc*_arm64"
                "C:/Qt/*/msvc*arm64"
                "C:/Qt/*/msvc*_64"
                "C:/Qt/*/mingw*_64"
                "C:/Qt/*/clang_64"
            )
        else()
            file(GLOB tondar_qt_candidates
                "C:/Qt/*/msvc*_64"
                "C:/Qt/*/mingw*_64"
                "C:/Qt/*/clang_64"
                "C:/Qt/*/msvc*_arm64"
                "C:/Qt/*/msvc*arm64"
            )
        endif()
    else()
        file(GLOB tondar_qt_candidates
            "${tondar_home}/Qt/*/gcc_64"
            "${tondar_home}/Qt/*/linux_gcc_64"
            "${tondar_home}/Qt/*/clang_64"
            "/opt/Qt/*/gcc_64"
            "/opt/Qt/*/clang_64"
        )
    endif()

    foreach(tondar_qt_prefix IN LISTS tondar_qt_candidates)
        if(EXISTS "${tondar_qt_prefix}/lib/cmake/Qt6/Qt6Config.cmake")
            list(APPEND CMAKE_PREFIX_PATH "${tondar_qt_prefix}")

            if(NOT Qt6_DIR)
                set(Qt6_DIR "${tondar_qt_prefix}/lib/cmake/Qt6" CACHE PATH "Qt6 config directory" FORCE)
            endif()
        endif()
    endforeach()
endif()

list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)

if(CMAKE_PREFIX_PATH)
    set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" CACHE STRING "Qt search prefixes" FORCE)
endif()

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core
    Quick
    QuickControls2
    Network
    Concurrent
    Gui
    Widgets
)

qt_standard_project_setup(REQUIRES 6.8)

message(STATUS "Qt6_DIR: ${Qt6_DIR}")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

# -------------------------
# macOS RPATH
# -------------------------
if(APPLE)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
    set(CMAKE_BUILD_RPATH "@executable_path/../Frameworks")
    set(CMAKE_BUILD_WITH_INSTALL_RPATH OFF)
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH OFF)
endif()

# -------------------------
# Helpers
# -------------------------
function(tondar_filter_existing out_var)
    set(filtered_files "")

    foreach(relative_file IN LISTS ARGN)
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${relative_file}")
            list(APPEND filtered_files "${relative_file}")
        else()
            message(STATUS "Skipping missing file: ${relative_file}")
        endif()
    endforeach()

    set(${out_var} "${filtered_files}" PARENT_SCOPE)
endfunction()

# -------------------------
# Sources / targets
# -------------------------
set(TONDAR_MODULE_IFS
    src/core/appcontroller.cppm
    src/core/downloadertask.cppm
    src/core/downloadmanager.cppm
    src/core/downloadmodel.cppm
    src/utils/download_utils.cppm
    src/utils/category_utils.cppm
    src/utils/version_utils.cppm
    src/services/power_monitor.cppm
    src/services/github_release_service.cppm
    src/services/update_client.cppm
)

set(TONDAR_IMPL_SOURCES
    src/core/appcontroller.cpp
    src/core/downloadertask.cpp
    src/core/downloadmanager.cpp
    src/core/downloadmodel.cpp
    src/utils/download_utils.cpp
    src/utils/category_utils.cpp
    src/utils/version_utils.cpp
    src/services/power_monitor.cpp
    src/services/github_release_service.cpp
    src/services/update_client.cpp
)

qt_add_executable(${APP_NAME}
    WIN32
    MACOSX_BUNDLE
    src/core/main.cpp
)

set_target_properties(${APP_NAME} PROPERTIES OUTPUT_NAME "${TONDAR_FINAL_OUTPUT_NAME}")

set_target_properties(${APP_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

qt_add_executable(TondarUpdaterHelper
    src/updaterhelper/main.cpp
)

target_link_libraries(TondarUpdaterHelper PRIVATE Qt6::Core)

set_target_properties(TondarUpdaterHelper PROPERTIES
    OUTPUT_NAME "TondarUpdaterHelper"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(WIN32 AND MSVC)
    target_link_options(TondarUpdaterHelper
        PRIVATE "/MANIFESTUAC:level='requireAdministrator' uiAccess='false'"
    )
endif()

if(APPLE)
    add_dependencies(${APP_NAME} TondarUpdaterHelper)
    set_target_properties(TondarUpdaterHelper PROPERTIES MACOSX_BUNDLE FALSE)

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:${APP_NAME}>/Contents/MacOS"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:TondarUpdaterHelper>"
                "$<TARGET_BUNDLE_DIR:${APP_NAME}>/Contents/MacOS/TondarUpdaterHelper"
        COMMENT "Copy updater helper into app bundle"
        VERBATIM
    )
else()
    add_dependencies(${APP_NAME} TondarUpdaterHelper)

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:TondarUpdaterHelper>"
                "$<TARGET_FILE_DIR:${APP_NAME}>/$<TARGET_FILE_NAME:TondarUpdaterHelper>"
        COMMENT "Copy updater helper beside app executable"
        VERBATIM
    )
endif()

# -------------------------
# QML files
# -------------------------
set(qml_core
    ui/Core/FontSystem.qml
    ui/Core/AppGlobals.qml
    ui/Core/Colors.qml
    ui/Core/Metrics.qml
    ui/Core/Typography.qml
    ui/Core/Theme.qml
    ui/Core/Animations.qml
    ui/Core/Elevation.qml
    ui/Core/Shadow.qml
)

set(qml_controls
    ui/Controls/Avatar.qml
    ui/Controls/AlphaGlass.qml
    ui/Controls/Card.qml
    ui/Controls/HorizontalLine.qml
    ui/Controls/HorizontalSpacer.qml
    ui/Controls/VerticalLine.qml
    ui/Controls/VerticalSpacer.qml
    ui/Controls/Text.qml
    ui/Controls/Button.qml
    ui/Controls/ActionButton.qml
    ui/Controls/IconButton.qml
    ui/Controls/MenuButton.qml
    ui/Controls/PillButton.qml
    ui/Controls/Label.qml
    ui/Controls/TextField.qml
    ui/Controls/TextArea.qml
    ui/Controls/ComboBox.qml
    ui/Controls/CheckBox.qml
    ui/Controls/Dialog.qml
    ui/Controls/SpinBox.qml
    ui/Controls/ProgressBar.qml
    ui/Controls/AppMenuBar.qml
    ui/Controls/AppMenuBarItem.qml
    ui/Controls/AppMenu.qml
    ui/Controls/AppMenuItem.qml
    ui/Controls/AppMenuSeparator.qml
    ui/Controls/AppMenuTrigger.qml
    ui/Controls/CommandActionButton.qml
    ui/Controls/CommandAddUrlButton.qml
    ui/Controls/GitHubReleaseAssetPicker.qml
    ui/Controls/SidebarTreeItem.qml
    ui/Controls/LayoutButton.qml
    ui/Controls/Switch.qml
    ui/Controls/MiniButton.qml
    ui/Controls/TabBar.qml
    ui/Controls/ToolTip.qml
    ui/Controls/TabBarButton.qml
    ui/Controls/TabButton.qml
    ui/Controls/TabButtonMini.qml
    ui/Controls/Menu.qml
    ui/Controls/MenuItem.qml
    ui/Controls/MenuSeparator.qml
    ui/Controls/BlurPopupSurface.qml
    ui/Controls/FootMenu.qml
    ui/Controls/FootButton.qml
    ui/Controls/GroupBox.qml
    ui/Controls/Image.qml
    ui/Controls/DownloadDelegate.qml
    ui/Controls/DownloadListView.qml
    ui/Controls/DownloadDetailsDialog.qml
    ui/Controls/DownloadDetailsWindow.qml
    ui/Controls/AddDownloadDialog.qml
)

set(qml_layout
    ui/Layout/Footer.qml
    ui/Layout/Header.qml
    ui/Layout/MoreLink.qml
    ui/Layout/Setting.qml
)

set(qml_main ui/Main.qml)

set(qml_files
    ${qml_main}
    ${qml_core}
    ${qml_controls}
    ${qml_layout}
)

tondar_filter_existing(qml_files_existing ${qml_files})

# -------------------------
# QML singletons
# -------------------------
set(qml_singletons
    ui/Core/AppGlobals.qml
    ui/Core/Metrics.qml
    ui/Core/Typography.qml
    ui/Core/Theme.qml
    ui/Core/Animations.qml
    ui/Core/FontSystem.qml
    ui/Core/Colors.qml
)

tondar_filter_existing(qml_singletons_existing ${qml_singletons})

set_source_files_properties(${qml_singletons_existing}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

# -------------------------
# Resources
# -------------------------
set(qml_resource_files
    Tondar.png

    resources/fonts/Inter-Thin.ttf
    resources/fonts/Inter-ExtraLight.ttf
    resources/fonts/Inter-Light.ttf
    resources/fonts/Inter-Regular.ttf
    resources/fonts/Inter-Medium.ttf
    resources/fonts/Inter_24pt-Medium.ttf
    resources/fonts/Inter-SemiBold.ttf
    resources/fonts/Inter-Bold.ttf
    resources/fonts/Inter-ExtraBold.ttf
    resources/fonts/Inter-Black.ttf

    "resources/fonts/Font Awesome 7 Brands-Regular-400.otf"
    "resources/fonts/Font Awesome 7 Free-Regular-400.otf"
    "resources/fonts/Font Awesome 7 Free-Solid-900.otf"

    resources/image/avatar.svg
)

tondar_filter_existing(qml_resource_files_existing ${qml_resource_files})

qt_add_resources(${APP_NAME} TondarAssets
    PREFIX /
    FILES
        ${qml_resource_files_existing}
)

set(qml_module_resources
    ui/Core/qmldir
    ui/Controls/qmldir
    ui/Layout/qmldir
    ui/Dashboard/qmldir
)

tondar_filter_existing(qml_module_resources_existing ${qml_module_resources})

qt_add_qml_module(${APP_NAME}
    URI Tondar
    VERSION 1.0
    QML_FILES
        ${qml_files_existing}
        ui/utils.js
    RESOURCES
        ${qml_module_resources_existing}
    SOURCES
        ${TONDAR_IMPL_SOURCES}
)

target_sources(${APP_NAME}
    PUBLIC
        FILE_SET CXX_MODULES
        TYPE CXX_MODULES
        BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
        FILES ${TONDAR_MODULE_IFS}
)

set_property(TARGET ${APP_NAME} PROPERTY CXX_SCAN_FOR_MODULES ON)

# -------------------------
# Platform bundle metadata
# -------------------------
if(APPLE)
    set_target_properties(${APP_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_GUI_IDENTIFIER "${TONDAR_BUNDLE_IDENTIFIER}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_ICON_FILE "${TONDAR_MACOS_ICON_FILE}"
    )

    if(EXISTS "${TONDAR_MACOS_INFO_PLIST}")
        set_target_properties(${APP_NAME} PROPERTIES
            MACOSX_BUNDLE_INFO_PLIST "${TONDAR_MACOS_INFO_PLIST}"
        )
    endif()

    if(EXISTS "${TONDAR_MACOS_ICON_ICNS}")
        set_source_files_properties("${TONDAR_MACOS_ICON_ICNS}"
            PROPERTIES MACOSX_PACKAGE_LOCATION "Resources"
        )

        target_sources(${APP_NAME} PRIVATE "${TONDAR_MACOS_ICON_ICNS}")
    endif()
elseif(WIN32)
    set_target_properties(${APP_NAME} PROPERTIES
        WIN32_EXECUTABLE TRUE
    )

    if(EXISTS "${TONDAR_WINDOWS_RC}")
        target_sources(${APP_NAME} PRIVATE "${TONDAR_WINDOWS_RC}")
    endif()
endif()

# -------------------------
# Link / definitions
# -------------------------
target_link_libraries(${APP_NAME}
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Network
        Qt6::Concurrent
        Qt6::Gui
        Qt6::Widgets
    )

target_compile_definitions(${APP_NAME} PRIVATE APP_VERSION="${PROJECT_VERSION}")

target_include_directories(${APP_NAME}
    PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

# -------------------------
# Tests
# -------------------------
if(TONDAR_BUILD_TESTS)
    enable_testing()

    find_package(Qt6 6.8 REQUIRED COMPONENTS Core Test Gui Network Concurrent Widgets)

    qt_add_executable(tondar_backend_tests
        tests/backend_tests.cpp
    )

    target_sources(tondar_backend_tests
        PUBLIC
            FILE_SET CXX_MODULES
            TYPE CXX_MODULES
            BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
            FILES ${TONDAR_MODULE_IFS}
    )

    set_property(TARGET tondar_backend_tests PROPERTY CXX_SCAN_FOR_MODULES ON)

    target_sources(tondar_backend_tests PRIVATE ${TONDAR_IMPL_SOURCES})

    target_link_libraries(tondar_backend_tests
        PRIVATE
            Qt6::Core
            Qt6::Test
            Qt6::Network
            Qt6::Concurrent
            Qt6::Gui
            Qt6::Widgets
    )

    target_include_directories(tondar_backend_tests
        PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )

    add_test(NAME tondar_backend_tests COMMAND tondar_backend_tests)
endif()

# -----------------------------------------------------------------------------
# macOS: POST_BUILD macdeployqt + codesign
# -----------------------------------------------------------------------------
if(APPLE AND TONDAR_MACOS_POSTBUILD_DEPLOY)
    find_program(TONDAR_MACDEPLOYQT_EXECUTABLE
        NAMES macdeployqt
        HINTS
            "$ENV{QTDIR}/bin"
            "${Qt6_DIR}/../../../bin"
            "${CMAKE_USER_HOME_DIRECTORY}/Qt/*/macos/bin"
            "$ENV{QT_DIR}/bin"
            "$ENV{Qt6_ROOT}/bin"
            "$ENV{QT_ROOT}/bin"
    )

    find_program(TONDAR_CODESIGN_EXECUTABLE NAMES codesign)

    if(NOT TONDAR_MACDEPLOYQT_EXECUTABLE)
        message(FATAL_ERROR "macdeployqt not found. Set QTDIR or ensure Qt bin is in PATH.")
    endif()

    if(NOT TONDAR_CODESIGN_EXECUTABLE AND TONDAR_MACOS_CODESIGN)
        message(FATAL_ERROR "codesign not found.")
    endif()

    set(tondar_bundle_dir "$<TARGET_BUNDLE_DIR:${APP_NAME}>")
    set(tondar_bundle_macos "${tondar_bundle_dir}/Contents/MacOS")

    set(tondar_macdeployqt_args "")

    if(TONDAR_MACDEPLOYQT_ALWAYS_OVERWRITE)
        list(APPEND tondar_macdeployqt_args "-always-overwrite")
    endif()

    if(TONDAR_MACDEPLOYQT_NO_STRIP)
        list(APPEND tondar_macdeployqt_args "-no-strip")
    endif()

    if(TONDAR_CODESIGN_IDENTITY STREQUAL "-")
        set(tondar_codesign_common
            "--force"
            "--deep"
            "--sign" "${TONDAR_CODESIGN_IDENTITY}"
        )
    else()
        set(tondar_codesign_common
            "--force"
            "--deep"
            "--options" "runtime"
            "--timestamp"
            "--sign" "${TONDAR_CODESIGN_IDENTITY}"
        )
    endif()

    set(tondar_codesign_ent "")

    if(TONDAR_CODESIGN_ENTITLEMENTS AND EXISTS "${TONDAR_CODESIGN_ENTITLEMENTS}")
        set(tondar_codesign_ent "--entitlements" "${TONDAR_CODESIGN_ENTITLEMENTS}")
    endif()

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND $<${TONDAR_IS_RELEASE}:${CMAKE_COMMAND}> -E make_directory "${tondar_bundle_macos}"

        COMMAND $<${TONDAR_IS_RELEASE}:${CMAKE_COMMAND}> -E copy_if_different
                "$<TARGET_FILE:TondarUpdaterHelper>"
                "${tondar_bundle_macos}/TondarUpdaterHelper"

        COMMAND $<${TONDAR_IS_RELEASE}:${CMAKE_COMMAND}> -E echo "Running macdeployqt on Tondar bundle..."

        COMMAND $<${TONDAR_IS_RELEASE}:${TONDAR_MACDEPLOYQT_EXECUTABLE}>
                "${tondar_bundle_dir}"
                -verbose=3
                -qmldir=${CMAKE_CURRENT_SOURCE_DIR}
                -executable=${tondar_bundle_macos}/TondarUpdaterHelper
                ${tondar_macdeployqt_args}

        COMMAND $<${TONDAR_IS_RELEASE}:${CMAKE_COMMAND}> -E echo "Codesigning after macdeployqt..."

        COMMAND $<$<AND:${TONDAR_IS_RELEASE},$<BOOL:${TONDAR_MACOS_CODESIGN}>>:${TONDAR_CODESIGN_EXECUTABLE}>
                ${tondar_codesign_common} ${tondar_codesign_ent}
                "${tondar_bundle_dir}"

        COMMAND $<$<AND:${TONDAR_IS_RELEASE},$<BOOL:${TONDAR_MACOS_CODESIGN}>>:${TONDAR_CODESIGN_EXECUTABLE}>
                --verify --deep --strict --verbose=2
                "${tondar_bundle_dir}"

        COMMENT "macOS deploy: copy helper, macdeployqt, then codesign"
        VERBATIM
    )
endif()

# -----------------------------------------------------------------------------
# Install rules
# -----------------------------------------------------------------------------
if(WIN32 AND MSVC)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ".")
    set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)
    set(CMAKE_INSTALL_DEBUG_LIBRARIES FALSE)

    include(InstallRequiredSystemLibraries)

    message(STATUS "MSVC runtime libraries from InstallRequiredSystemLibraries:")
    foreach(tondar_runtime_lib IN LISTS CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        message(STATUS "  ${tondar_runtime_lib}")
    endforeach()

    if(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        install(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}
            CONFIGURATIONS Release RelWithDebInfo
            DESTINATION "."
        )
    endif()

    set(TONDAR_MSVC_REDIST_ARCH "")
    if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64$")
        set(TONDAR_MSVC_REDIST_ARCH "arm64")
    elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$|^[Ww]in64$|^[Aa][Mm][Dd]64$")
        set(TONDAR_MSVC_REDIST_ARCH "x64")
    elseif(TONDAR_TARGET_BUILD_ARCH STREQUAL "arm64")
        set(TONDAR_MSVC_REDIST_ARCH "arm64")
    else()
        set(TONDAR_MSVC_REDIST_ARCH "x64")
    endif()

    set(TONDAR_MSVC_REDIST_DLLS "")

    if(DEFINED ENV{VCToolsRedistDir} AND NOT "$ENV{VCToolsRedistDir}" STREQUAL "")
        file(TO_CMAKE_PATH "$ENV{VCToolsRedistDir}" TONDAR_VC_REDIST_DIR)

        file(GLOB TONDAR_MSVC_CRT_DLLS
            "${TONDAR_VC_REDIST_DIR}/${TONDAR_MSVC_REDIST_ARCH}/Microsoft.VC*.CRT/*.dll"
        )

        file(GLOB TONDAR_MSVC_OPENMP_DLLS
            "${TONDAR_VC_REDIST_DIR}/${TONDAR_MSVC_REDIST_ARCH}/Microsoft.VC*.OpenMP/*.dll"
        )

        list(APPEND TONDAR_MSVC_REDIST_DLLS
            ${TONDAR_MSVC_CRT_DLLS}
            ${TONDAR_MSVC_OPENMP_DLLS}
        )
    endif()

    if(NOT TONDAR_MSVC_REDIST_DLLS AND DEFINED ENV{VCINSTALLDIR} AND NOT "$ENV{VCINSTALLDIR}" STREQUAL "")
        file(TO_CMAKE_PATH "$ENV{VCINSTALLDIR}" TONDAR_VC_INSTALL_DIR)

        file(GLOB_RECURSE TONDAR_MSVC_CRT_DLLS
            "${TONDAR_VC_INSTALL_DIR}/Redist/MSVC/*/${TONDAR_MSVC_REDIST_ARCH}/Microsoft.VC*.CRT/*.dll"
        )

        file(GLOB_RECURSE TONDAR_MSVC_OPENMP_DLLS
            "${TONDAR_VC_INSTALL_DIR}/Redist/MSVC/*/${TONDAR_MSVC_REDIST_ARCH}/Microsoft.VC*.OpenMP/*.dll"
        )

        list(APPEND TONDAR_MSVC_REDIST_DLLS
            ${TONDAR_MSVC_CRT_DLLS}
            ${TONDAR_MSVC_OPENMP_DLLS}
        )
    endif()

    list(REMOVE_DUPLICATES TONDAR_MSVC_REDIST_DLLS)

    message(STATUS "TONDAR MSVC redist arch: ${TONDAR_MSVC_REDIST_ARCH}")
    message(STATUS "TONDAR explicit MSVC redist DLLs:")
    foreach(tondar_redist_dll IN LISTS TONDAR_MSVC_REDIST_DLLS)
        message(STATUS "  ${tondar_redist_dll}")
    endforeach()

    if(TONDAR_MSVC_REDIST_DLLS)
        install(FILES ${TONDAR_MSVC_REDIST_DLLS}
            CONFIGURATIONS Release RelWithDebInfo
            DESTINATION "."
        )
    else()
        message(WARNING
            "No explicit MSVC redist DLLs found. "
            "Run CMake from a Visual Studio Developer shell or make sure VCToolsRedistDir is available."
        )
    endif()
endif()

include(GNUInstallDirs)

# Windows: root layout.
# macOS: bundle root layout.
# Linux: bin layout, exactly like GenyConnect.
if(WIN32)
    set(TONDAR_RUNTIME_DEST ".")
else()
    set(TONDAR_RUNTIME_DEST "${CMAKE_INSTALL_BINDIR}")
endif()

install(TARGETS ${APP_NAME}
    CONFIGURATIONS Release RelWithDebInfo
    BUNDLE DESTINATION .
    RUNTIME DESTINATION "${TONDAR_RUNTIME_DEST}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)

if(APPLE)
    install(TARGETS TondarUpdaterHelper
        CONFIGURATIONS Release RelWithDebInfo
        RUNTIME DESTINATION "${TONDAR_FINAL_OUTPUT_NAME}.app/Contents/MacOS"
    )
else()
    install(TARGETS TondarUpdaterHelper
        CONFIGURATIONS Release RelWithDebInfo
        RUNTIME DESTINATION "${TONDAR_RUNTIME_DEST}"
    )
endif()

if(UNIX AND NOT APPLE)
    if(EXISTS "${TONDAR_LINUX_ICON_PNG}")
        install(FILES "${TONDAR_LINUX_ICON_PNG}"
            DESTINATION "share/icons/hicolor/512x512/apps"
            RENAME "tondar.png"
        )
    endif()
endif()

# -----------------------------------------------------------------------------
# Linux deploy
# -----------------------------------------------------------------------------
if(UNIX AND NOT APPLE AND TONDAR_LINUX_INSTALL_DEPLOY)
    set(tondar_linux_deploy_args "")

    if(NOT TONDAR_LINUX_DEPLOY_TRANSLATIONS)
        list(APPEND tondar_linux_deploy_args NO_TRANSLATIONS)
    endif()

    qt_generate_deploy_qml_app_script(
        TARGET ${APP_NAME}
        OUTPUT_SCRIPT TONDAR_LINUX_DEPLOY_SCRIPT
        NO_UNSUPPORTED_PLATFORM_ERROR
        ${tondar_linux_deploy_args}
    )

    install(SCRIPT ${TONDAR_LINUX_DEPLOY_SCRIPT})
endif()

# -----------------------------------------------------------------------------
# Windows deploy
# -----------------------------------------------------------------------------
if(WIN32 AND TONDAR_WINDOWS_INSTALL_DEPLOY)
    find_program(TONDAR_WINDEPLOYQT_EXECUTABLE
        NAMES windeployqt
        HINTS
            "$ENV{QTDIR}/bin"
            "${Qt6_DIR}/../../../bin"
            "C:/Qt/*/*/bin"
            "$ENV{QT_DIR}/bin"
            "$ENV{Qt6_ROOT}/bin"
            "$ENV{QT_ROOT}/bin"
    )

    if(NOT TONDAR_WINDEPLOYQT_EXECUTABLE)
        message(FATAL_ERROR "windeployqt not found. Set QTDIR or make sure Qt bin is in PATH.")
    endif()

    install(CODE
        "message(STATUS \"[deploy] Running windeployqt for Tondar (install tree, root layout)\")\n
         set(_root \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}\")\n
         file(TO_CMAKE_PATH \"\${_root}\" _root)\n
         set(_exe \"\${_root}/${TONDAR_FINAL_OUTPUT_NAME}.exe\")\n
         if(NOT EXISTS \"\${_exe}\")\n
           message(FATAL_ERROR \"[deploy] Installed exe not found: \${_exe}\")\n
         endif()\n
         set(_args \"\${_exe}\" \"--qmldir\" \"${CMAKE_CURRENT_SOURCE_DIR}\" \"--dir\" \"\${_root}\" \"--verbose\" \"2\" \"--release\")\n
         if(${TONDAR_WINDEPLOYQT_COMPILER_RUNTIME})\n
           list(APPEND _args \"--compiler-runtime\")\n
         endif()\n
         if(${TONDAR_WINDEPLOYQT_TRANSLATIONS})\n
           list(APPEND _args \"--translations\")\n
         else()\n
           list(APPEND _args \"--no-translations\")\n
         endif()\n
         execute_process(\n
           COMMAND \"${TONDAR_WINDEPLOYQT_EXECUTABLE}\" \${_args}\n
           RESULT_VARIABLE _res\n
           OUTPUT_VARIABLE _out\n
           ERROR_VARIABLE _err\n
         )\n
         if(NOT _res EQUAL 0)\n
           message(FATAL_ERROR \"[deploy] windeployqt failed code=\${_res}\\n\${_out}\\n\${_err}\")\n
         endif()\n
         message(STATUS \"[deploy] windeployqt done. Output dir: \${_root}\")\n"
    )
endif()

# -----------------------------------------------------------------------------
# README + LICENSE
# -----------------------------------------------------------------------------
set(CPACK_MONOLITHIC_INSTALL ON)

set(TONDAR_DOC_README_SRC "")
set(TONDAR_DOC_LICENSE_SRC "")

if(TONDAR_BUNDLE_DOCS)
    foreach(tondar_doc_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/README.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/README.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/README"
    )
        if(EXISTS "${tondar_doc_candidate}")
            set(TONDAR_DOC_README_SRC "${tondar_doc_candidate}")
            break()
        endif()
    endforeach()

    foreach(tondar_doc_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/COPYING"
    )
        if(EXISTS "${tondar_doc_candidate}")
            set(TONDAR_DOC_LICENSE_SRC "${tondar_doc_candidate}")
            break()
        endif()
    endforeach()

    if(TONDAR_DOC_README_SRC)
        set(TONDAR_DOC_README_TXT "${CMAKE_BINARY_DIR}/NSIS_README.txt")
        configure_file("${TONDAR_DOC_README_SRC}" "${TONDAR_DOC_README_TXT}" COPYONLY)
        install(FILES "${TONDAR_DOC_README_TXT}" DESTINATION "." RENAME "README.txt")
    else()
        message(WARNING "No README file found to bundle.")
    endif()

    if(TONDAR_DOC_LICENSE_SRC)
        set(TONDAR_DOC_LICENSE_TXT "${CMAKE_BINARY_DIR}/NSIS_LICENSE.txt")
        configure_file("${TONDAR_DOC_LICENSE_SRC}" "${TONDAR_DOC_LICENSE_TXT}" COPYONLY)
        install(FILES "${TONDAR_DOC_LICENSE_TXT}" DESTINATION "." RENAME "LICENSE.txt")
    else()
        message(WARNING "No LICENSE file found to bundle.")
    endif()
endif()

# -----------------------------------------------------------------------------
# CPack / Installer Packaging
# -----------------------------------------------------------------------------
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VENDOR "${TONDAR_VENDOR}")
set(CPACK_PACKAGE_CONTACT "${TONDAR_PACKAGE_CONTACT}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${TONDAR_PACKAGE_SUMMARY}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")

set(CPACK_OUTPUT_FILE_PREFIX "${TONDAR_FINAL_DIR}")
set(CPACK_PACKAGE_FILE_NAME "${PROJECT_NAME}-${PROJECT_VERSION}-${TONDAR_OS}-${TONDAR_ARCH}")
set(CPACK_PACKAGING_INSTALL_PREFIX "/")

if(WIN32)
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_NSIS_DISPLAY_NAME "${APP_NAME}")
    set(CPACK_NSIS_PACKAGE_NAME "${APP_NAME}")
    set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "${APP_NAME}")

    set(TONDAR_EXE_NAME "${TONDAR_FINAL_OUTPUT_NAME}.exe")

    set(CPACK_NSIS_MENU_LINKS
        "${TONDAR_EXE_NAME}" "${APP_NAME}"
    )

    set(CPACK_NSIS_CREATE_ICONS_EXTRA
        "CreateShortCut \\\"$DESKTOP\\\\${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\${TONDAR_EXE_NAME}\\\"\n"
        "CreateDirectory \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\"\n"
        "CreateShortCut \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\${TONDAR_EXE_NAME}\\\"\n"
        "CreateShortCut \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\Uninstall ${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\Uninstall.exe\\\"\n"
    )

    set(CPACK_NSIS_DELETE_ICONS_EXTRA
        "Delete \\\"$DESKTOP\\\\${APP_NAME}.lnk\\\"\n"
        "Delete \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\${APP_NAME}.lnk\\\"\n"
        "Delete \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\Uninstall ${APP_NAME}.lnk\\\"\n"
        "RMDir \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\"\n"
    )

    if(EXISTS "${CMAKE_BINARY_DIR}/NSIS_LICENSE.txt")
        set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_BINARY_DIR}/NSIS_LICENSE.txt")
    endif()

    if(EXISTS "${CMAKE_BINARY_DIR}/NSIS_README.txt")
        set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS
            "ExecShell \\\"open\\\" \\\"$INSTDIR\\\\README.txt\\\""
        )
    endif()

elseif(APPLE)
    set(CPACK_GENERATOR "DragNDrop")

    set(TONDAR_DMG_BACKGROUND_IMAGE "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/background.png")
    set(TONDAR_DMG_DS_STORE_SETUP_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/dmg-setup.scpt")

    set(CPACK_DMG_VOLUME_NAME "${APP_NAME} ${PROJECT_VERSION}")
    set(CPACK_DMG_FORMAT "UDZO")

    if(EXISTS "${TONDAR_DMG_BACKGROUND_IMAGE}")
        set(CPACK_DMG_BACKGROUND_IMAGE "${TONDAR_DMG_BACKGROUND_IMAGE}")
    endif()

    if(EXISTS "${TONDAR_DMG_DS_STORE_SETUP_SCRIPT}")
        set(CPACK_DMG_DS_STORE_SETUP_SCRIPT "${TONDAR_DMG_DS_STORE_SETUP_SCRIPT}")
    endif()

else()
    set(CPACK_GENERATOR "TGZ")
endif()

include(CPack)

message(STATUS "Build dir: ${CMAKE_BINARY_DIR}")
message(STATUS "Packages dir: ${TONDAR_FINAL_DIR}")
message(STATUS "Packaging: run cpack. For multi-config generators use: cpack -C Release")
