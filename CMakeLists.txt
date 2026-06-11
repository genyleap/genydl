# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Genyleap Labs.

cmake_minimum_required(VERSION 3.28)

# -----------------------------------------------------------------------------
# GENYDL CMakeLists
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
set(PROJECT_NAME "GenyDL")
set(PROJECT_REAL_NAME "GenyDL")
set(APP_NAME "${PROJECT_REAL_NAME}")

set(PROJECT_VERSION_MAJOR 1)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 32)
set(PROJECT_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

# -------------------------
# Target OS / Arch
# -------------------------
set(GENYDL_TARGET_BUILD_ARCH "" CACHE STRING "Override target arch for output build/package (arm64|x86_64)")

# Must be defined before project() on macOS.
set(GENYDL_MACOS_DEPLOYMENT_TARGET "15.1" CACHE STRING "Minimum macOS version")

if(APPLE)
    if(NOT GENYDL_TARGET_BUILD_ARCH)
        set(GENYDL_TARGET_BUILD_ARCH "arm64" CACHE STRING "Override target arch for output build/package (arm64|x86_64)" FORCE)
    endif()

    set(CMAKE_OSX_ARCHITECTURES "${GENYDL_TARGET_BUILD_ARCH}" CACHE STRING "Build architecture" FORCE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${GENYDL_MACOS_DEPLOYMENT_TARGET}" CACHE STRING "Minimum macOS version" FORCE)
endif()

project(${PROJECT_NAME} VERSION ${PROJECT_VERSION} LANGUAGES CXX)

if(POLICY CMP0155)
    cmake_policy(SET CMP0155 NEW)
endif()

# -------------------------
# Detect Windows generator architecture
# -------------------------
if(WIN32 AND NOT GENYDL_TARGET_BUILD_ARCH)
    if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64$")
        set(GENYDL_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected Windows target arch" FORCE)
    elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$|^[Ww]in64$|^[Aa][Mm][Dd]64$")
        set(GENYDL_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected Windows target arch" FORCE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|arm64|aarch64")
        set(GENYDL_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected Windows target arch" FORCE)
    else()
        set(GENYDL_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected Windows target arch" FORCE)
    endif()
elseif(NOT GENYDL_TARGET_BUILD_ARCH)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|arm64|aarch64")
        set(GENYDL_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected target arch" FORCE)
    else()
        set(GENYDL_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected target arch" FORCE)
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
message(STATUS "GENYDL target build arch: ${GENYDL_TARGET_BUILD_ARCH}")

# Release/RelWithDebInfo generator-expression.
set(GENYDL_IS_RELEASE "$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>>")

# -------------------------
# Options
# -------------------------
option(GENYDL_USE_MODULES "Enable C++20 modules" ON)
option(GENYDL_LLVM_AUTO_SCAN "Auto-detect LLVM/clang for modules" ON)
option(GENYDL_QT_AUTO_SCAN "Auto-detect Qt installation prefix" ON)
option(GENYDL_BUILD_TESTS "Build backend tests" ON)

option(GENYDL_MACOS_POSTBUILD_DEPLOY "Run macdeployqt on the build .app in POST_BUILD" ON)
option(GENYDL_MACOS_CODESIGN "Codesign the .app after macdeployqt" ON)

set(GENYDL_CODESIGN_IDENTITY "-" CACHE STRING
    "macOS codesign identity. Use '-' for ad-hoc signing, or 'Developer ID Application: ...' for release."
)

set(GENYDL_CODESIGN_ENTITLEMENTS "" CACHE FILEPATH
    "Optional entitlements plist path for codesign."
)

option(GENYDL_MACDEPLOYQT_ALWAYS_OVERWRITE "Pass -always-overwrite to macdeployqt" OFF)
option(GENYDL_MACDEPLOYQT_NO_STRIP "Pass -no-strip to macdeployqt" OFF)

option(GENYDL_WINDOWS_INSTALL_DEPLOY
    "Run windeployqt during install() so CPack includes Qt/QML dependencies" ON
)

option(GENYDL_WINDEPLOYQT_COMPILER_RUNTIME
    "Pass --compiler-runtime to windeployqt" ON
)

option(GENYDL_WINDEPLOYQT_TRANSLATIONS
    "Include Qt translations via windeployqt" OFF
)

option(GENYDL_LINUX_INSTALL_DEPLOY
    "Run Qt Linux deployment during install() so CPack TGZ includes Qt/QML dependencies" ON
)

option(GENYDL_LINUX_DEPLOY_TRANSLATIONS
    "Include Qt translations in Linux deployment package" OFF
)

option(GENYDL_BUNDLE_DOCS
    "Install README and LICENSE at package root and NSIS wizard" ON
)

set(GENYDL_TARGET_OS "" CACHE STRING "Override target OS for output naming (macos|linux|windows)")
set(GENYDL_TARGET_ARCH "${GENYDL_TARGET_BUILD_ARCH}" CACHE STRING "Override target arch for output naming (arm64|x86_64)" FORCE)
set(GENYDL_OUTPUT_NAME "" CACHE STRING "Optional explicit output name")

# -------------------------
# Normalize OS / Arch
# -------------------------
if(GENYDL_TARGET_OS AND NOT GENYDL_TARGET_OS STREQUAL "")
    string(TOLOWER "${GENYDL_TARGET_OS}" GENYDL_OS)
else()
    if(APPLE)
        set(GENYDL_OS "macos")
    elseif(WIN32)
        set(GENYDL_OS "windows")
    else()
        set(GENYDL_OS "linux")
    endif()
endif()

set(GENYDL_ARCH_RAW "")

if(GENYDL_TARGET_ARCH AND NOT GENYDL_TARGET_ARCH STREQUAL "")
    set(GENYDL_ARCH_RAW "${GENYDL_TARGET_ARCH}")
elseif(APPLE AND CMAKE_OSX_ARCHITECTURES)
    list(GET CMAKE_OSX_ARCHITECTURES 0 GENYDL_ARCH_RAW)
elseif(DEFINED CMAKE_SYSTEM_PROCESSOR AND CMAKE_SYSTEM_PROCESSOR)
    set(GENYDL_ARCH_RAW "${CMAKE_SYSTEM_PROCESSOR}")
else()
    set(GENYDL_ARCH_RAW "x86_64")
endif()

string(TOLOWER "${GENYDL_ARCH_RAW}" GENYDL_ARCH)

if(GENYDL_ARCH MATCHES "^(arm64|aarch64|arm64-v8a)$")
    set(GENYDL_ARCH "arm64")
elseif(GENYDL_ARCH MATCHES "^(x86_64|amd64|x64|64)$")
    set(GENYDL_ARCH "x86_64")
endif()

if(GENYDL_OUTPUT_NAME AND NOT GENYDL_OUTPUT_NAME STREQUAL "")
    set(GENYDL_FINAL_OUTPUT_NAME "${GENYDL_OUTPUT_NAME}")
else()
    set(GENYDL_FINAL_OUTPUT_NAME "${APP_NAME}")
endif()

message(STATUS "GENYDL build: OS='${GENYDL_OS}' ARCH='${GENYDL_ARCH}'")
message(STATUS "GENYDL output name: ${GENYDL_FINAL_OUTPUT_NAME}")

# -------------------------
# Final packages folder
# -------------------------
set(GENYDL_FINAL_ROOT "${CMAKE_BINARY_DIR}/final")
set(GENYDL_FINAL_DIR "${GENYDL_FINAL_ROOT}/${GENYDL_OS}-${GENYDL_ARCH}")
file(MAKE_DIRECTORY "${GENYDL_FINAL_DIR}")
message(STATUS "GENYDL final output folder: ${GENYDL_FINAL_DIR}")

# -------------------------
# Metadata
# -------------------------
set(GENYDL_VENDOR "Genyleap")
set(GENYDL_PACKAGE_CONTACT "info@genyleap.com")
set(GENYDL_PACKAGE_SUMMARY "GENYDL Internet Download Manager")
set(GENYDL_COPYRIGHT "Copyright 2026 by Genyleap LLC")
set(GENYDL_BUNDLE_IDENTIFIER "com.genyleap.genydl")

set(GENYDL_MACOS_ICON_FILE "GenyDL.icns")
set(GENYDL_MACOS_ICON_ICNS "${CMAKE_CURRENT_SOURCE_DIR}/GenyDL.icns")
set(GENYDL_WINDOWS_ICON_ICO "${CMAKE_CURRENT_SOURCE_DIR}/GenyDL.ico")
set(GENYDL_LINUX_ICON_PNG "${CMAKE_CURRENT_SOURCE_DIR}/GenyDL.png")

set(GENYDL_MACOS_INFO_PLIST_IN "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/Info.plist.in")
set(GENYDL_MACOS_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/generated/Info.plist")

set(GENYDL_WINDOWS_RC_IN "${CMAKE_CURRENT_SOURCE_DIR}/properties/Windows/app.rc.in")
set(GENYDL_WINDOWS_RC "${CMAKE_CURRENT_BINARY_DIR}/generated/genydl_app.rc")

set(GENYDL_RC_FILE_VERSION "${PROJECT_VERSION_MAJOR},${PROJECT_VERSION_MINOR},${PROJECT_VERSION_PATCH},0")
set(GENYDL_RC_PRODUCT_VERSION "${PROJECT_VERSION_MAJOR},${PROJECT_VERSION_MINOR},${PROJECT_VERSION_PATCH},0")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated")

if(EXISTS "${GENYDL_MACOS_INFO_PLIST_IN}")
    configure_file("${GENYDL_MACOS_INFO_PLIST_IN}" "${GENYDL_MACOS_INFO_PLIST}" @ONLY)
endif()

if(WIN32 AND EXISTS "${GENYDL_WINDOWS_RC_IN}")
    file(TO_CMAKE_PATH "${GENYDL_WINDOWS_ICON_ICO}" GENYDL_WINDOWS_ICON_ICO_RC)
    configure_file("${GENYDL_WINDOWS_RC_IN}" "${GENYDL_WINDOWS_RC}" @ONLY)
endif()

# -------------------------
# macOS SDK for Homebrew LLVM
# -------------------------
if(APPLE)
    execute_process(
        COMMAND xcrun --sdk macosx --show-sdk-path
        OUTPUT_VARIABLE GENYDL_MACOS_SDK
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(GENYDL_MACOS_SDK)
        set(CMAKE_OSX_SYSROOT "${GENYDL_MACOS_SDK}" CACHE PATH "macOS SDK" FORCE)
    endif()
endif()

# -------------------------
# Compiler / module checks
# -------------------------
set(GENYDL_LLVM_HINTS "")

if(GENYDL_LLVM_AUTO_SCAN)
    if(DEFINED ENV{LLVM_ROOT})
        list(APPEND GENYDL_LLVM_HINTS "$ENV{LLVM_ROOT}/bin")
    endif()

    if(DEFINED ENV{LLVM_HOME})
        list(APPEND GENYDL_LLVM_HINTS "$ENV{LLVM_HOME}/bin")
    endif()

    if(DEFINED ENV{LLVM_DIR})
        list(APPEND GENYDL_LLVM_HINTS "$ENV{LLVM_DIR}/bin")
    endif()

    find_program(GENYDL_BREW brew HINTS /opt/homebrew/bin /usr/local/bin)

    if(GENYDL_BREW)
        execute_process(
            COMMAND "${GENYDL_BREW}" --prefix llvm
            OUTPUT_VARIABLE GENYDL_BREW_LLVM_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(GENYDL_BREW_LLVM_PREFIX)
            list(APPEND GENYDL_LLVM_HINTS "${GENYDL_BREW_LLVM_PREFIX}/bin")
        endif()
    endif()
endif()

find_program(GENYDL_CLANG NAMES clang HINTS ${GENYDL_LLVM_HINTS})
find_program(GENYDL_CLANGXX NAMES clang++ clang-cl HINTS ${GENYDL_LLVM_HINTS})
find_program(GENYDL_CLANG_SCAN_DEPS NAMES clang-scan-deps HINTS ${GENYDL_LLVM_HINTS})

if(NOT GENYDL_CLANG_SCAN_DEPS AND CMAKE_CXX_COMPILER)
    get_filename_component(GENYDL_CXX_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)

    if(GENYDL_CXX_DIR)
        find_program(GENYDL_CLANG_SCAN_DEPS
            NAMES clang-scan-deps
            HINTS "${GENYDL_CXX_DIR}"
        )
    endif()
endif()

set(GENYDL_CLANGXX_IS_APPLE_PATH FALSE)

if(GENYDL_CLANGXX MATCHES "^/usr/bin/clang\\+\\+$" OR
   GENYDL_CLANGXX MATCHES "XcodeDefault\\.xctoolchain")
    set(GENYDL_CLANGXX_IS_APPLE_PATH TRUE)
endif()

if(GENYDL_CLANG_SCAN_DEPS AND NOT DEFINED CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS)
    set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS
        "${GENYDL_CLANG_SCAN_DEPS}"
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

if(GENYDL_USE_MODULES)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        if(GENYDL_CLANGXX AND GENYDL_CLANG_SCAN_DEPS AND NOT GENYDL_CLANGXX_IS_APPLE_PATH)
            message(FATAL_ERROR
                "AppleClang is active in this build directory. Delete build directory and reconfigure with LLVM clang:\n"
                "  -DCMAKE_C_COMPILER=${GENYDL_CLANG}\n"
                "  -DCMAKE_CXX_COMPILER=${GENYDL_CLANGXX}\n"
                "  -DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${GENYDL_CLANG_SCAN_DEPS}\n"
                "or set -DGENYDL_USE_MODULES=OFF."
            )
        else()
            message(FATAL_ERROR
                "AppleClang does not provide stable module scanning here. "
                "Install LLVM clang or set -DGENYDL_USE_MODULES=OFF."
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
        "GENYDL_USE_MODULES=OFF is not supported in this source tree because backend sources import project modules. "
        "Build with GENYDL_USE_MODULES=ON and a compiler that supports module dependency scanning."
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

if(GENYDL_QT_AUTO_SCAN AND NOT Qt6_DIR)
    set(genydl_qt_candidates "")

    set(genydl_home "${CMAKE_USER_HOME_DIRECTORY}")

    if(NOT genydl_home AND DEFINED ENV{HOME})
        set(genydl_home "$ENV{HOME}")
    endif()

    if(APPLE)
        file(GLOB genydl_qt_candidates
            "${genydl_home}/Qt/*/macos"
            "${genydl_home}/Qt/*/clang_64"
            "/opt/Qt/*/macos"
            "/usr/local/Qt/*/macos"
        )
    elseif(WIN32)
        if(GENYDL_TARGET_BUILD_ARCH STREQUAL "arm64")
            file(GLOB genydl_qt_candidates
                "C:/Qt/*/msvc*_arm64"
                "C:/Qt/*/msvc*arm64"
                "C:/Qt/*/msvc*_64"
                "C:/Qt/*/mingw*_64"
                "C:/Qt/*/clang_64"
            )
        else()
            file(GLOB genydl_qt_candidates
                "C:/Qt/*/msvc*_64"
                "C:/Qt/*/mingw*_64"
                "C:/Qt/*/clang_64"
                "C:/Qt/*/msvc*_arm64"
                "C:/Qt/*/msvc*arm64"
            )
        endif()
    else()
        file(GLOB genydl_qt_candidates
            "${genydl_home}/Qt/*/gcc_64"
            "${genydl_home}/Qt/*/linux_gcc_64"
            "${genydl_home}/Qt/*/clang_64"
            "/opt/Qt/*/gcc_64"
            "/opt/Qt/*/clang_64"
        )
    endif()

    foreach(genydl_qt_prefix IN LISTS genydl_qt_candidates)
        if(EXISTS "${genydl_qt_prefix}/lib/cmake/Qt6/Qt6Config.cmake")
            list(APPEND CMAKE_PREFIX_PATH "${genydl_qt_prefix}")

            if(NOT Qt6_DIR)
                set(Qt6_DIR "${genydl_qt_prefix}/lib/cmake/Qt6" CACHE PATH "Qt6 config directory" FORCE)
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
# BitTorrent (libtorrent-rasterbar) — optional
# -------------------------
# Uses a system-installed libtorrent-rasterbar (which already pulls in its own
# Boost dependency transitively — nothing for us to fetch or build). When it is
# not found, BitTorrent support compiles as a no-op stub so the app still builds.
option(GENYDL_ENABLE_TORRENT "Enable BitTorrent support via libtorrent-rasterbar" ON)

set(GENYDL_HAVE_LIBTORRENT FALSE)

if(GENYDL_ENABLE_TORRENT)
    # 1) libtorrent 2.x ships a CMake package named LibtorrentRasterbar.
    find_package(LibtorrentRasterbar QUIET CONFIG)

    if(NOT LibtorrentRasterbar_FOUND)
        # 2) Fall back to pkg-config (libtorrent-rasterbar.pc).
        find_package(PkgConfig QUIET)
        if(PkgConfig_FOUND)
            pkg_check_modules(LIBTORRENT IMPORTED_TARGET libtorrent-rasterbar)
        endif()
    endif()

    if(LibtorrentRasterbar_FOUND)
        set(GENYDL_HAVE_LIBTORRENT TRUE)
        set(GENYDL_LIBTORRENT_TARGET LibtorrentRasterbar::torrent-rasterbar)
        message(STATUS "libtorrent-rasterbar found (CMake config).")
    elseif(LIBTORRENT_FOUND)
        set(GENYDL_HAVE_LIBTORRENT TRUE)
        set(GENYDL_LIBTORRENT_TARGET PkgConfig::LIBTORRENT)
        message(STATUS "libtorrent-rasterbar found (pkg-config): ${LIBTORRENT_VERSION}")
    else()
        message(WARNING
            "GENYDL_ENABLE_TORRENT=ON but libtorrent-rasterbar was not found. "
            "BitTorrent support will be compiled as a no-op stub.\n"
            "Install it to enable torrents:\n"
            "  macOS:  brew install libtorrent-rasterbar\n"
            "  Debian: sudo apt install libtorrent-rasterbar-dev\n"
            "  Fedora: sudo dnf install rb_libtorrent-devel"
        )
    endif()
endif()

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
function(genydl_filter_existing out_var)
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
set(GENYDL_MODULE_IFS
    src/ui/tray_icon_provider.cppm
    src/core/appcontroller.cppm
    src/core/downloadertask.cppm
    src/core/torrenttask.cppm
    src/core/downloadmanager.cppm
    src/core/downloadmodel.cppm
    src/utils/download_utils.cppm
    src/utils/category_utils.cppm
    src/utils/version_utils.cppm
    src/utils/ipfs_resolver.cppm
    src/services/power_monitor.cppm
    src/services/torrent_session.cppm
    src/services/gateway_service.cppm
    src/services/github_release_service.cppm
    src/services/release_center_service.cppm
    src/services/update_client.cppm
)

set(GENYDL_IMPL_SOURCES
    src/ui/tray_icon_provider.cpp
    src/core/appcontroller.cpp
    src/core/downloadertask.cpp
    src/core/torrenttask.cpp
    src/core/downloadmanager.cpp
    src/core/downloadmodel.cpp
    src/utils/download_utils.cpp
    src/utils/category_utils.cpp
    src/utils/version_utils.cpp
    src/utils/ipfs_resolver.cpp
    src/services/power_monitor.cpp
    src/services/torrent_session.cpp
    src/services/gateway_service.cpp
    src/services/github_release_service.cpp
    src/services/release_center_service.cpp
    src/services/update_client.cpp
)

qt_add_executable(${APP_NAME}
    WIN32
    MACOSX_BUNDLE
    src/core/main.cpp
)

set_target_properties(${APP_NAME} PROPERTIES OUTPUT_NAME "${GENYDL_FINAL_OUTPUT_NAME}")

set_target_properties(${APP_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

qt_add_executable(GenyDLUpdaterHelper
    src/updaterhelper/main.cpp
)

target_link_libraries(GenyDLUpdaterHelper PRIVATE Qt6::Core)

set_target_properties(GenyDLUpdaterHelper PROPERTIES
    OUTPUT_NAME "GenyDLUpdaterHelper"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(WIN32 AND MSVC)
    target_link_options(GenyDLUpdaterHelper
        PRIVATE "/MANIFESTUAC:level='requireAdministrator' uiAccess='false'"
    )
endif()

if(APPLE)
    add_dependencies(${APP_NAME} GenyDLUpdaterHelper)
    set_target_properties(GenyDLUpdaterHelper PROPERTIES MACOSX_BUNDLE FALSE)

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:${APP_NAME}>/Contents/MacOS"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:GenyDLUpdaterHelper>"
                "$<TARGET_BUNDLE_DIR:${APP_NAME}>/Contents/MacOS/GenyDLUpdaterHelper"
        COMMENT "Copy updater helper into app bundle"
        VERBATIM
    )
else()
    add_dependencies(${APP_NAME} GenyDLUpdaterHelper)

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:GenyDLUpdaterHelper>"
                "$<TARGET_FILE_DIR:${APP_NAME}>/$<TARGET_FILE_NAME:GenyDLUpdaterHelper>"
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
    ui/Controls/MiniIconButton.qml
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
    ui/Controls/ReleaseCenterPage.qml
    ui/Controls/ReleaseDetailsDialog.qml
    ui/Controls/ReleaseCenterSettings.qml
    ui/Controls/DateTimeField.qml
    ui/Controls/ToolTip.qml
    ui/Controls/SidebarTreeItem.qml
    ui/Controls/DropZone.qml
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
    ui/Controls/TorrentDetailsDialog.qml
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

genydl_filter_existing(qml_files_existing ${qml_files})

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

genydl_filter_existing(qml_singletons_existing ${qml_singletons})

set_source_files_properties(${qml_singletons_existing}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

# -------------------------
# Resources
# -------------------------
set(qml_resource_files
    # Kept for backward compatibility: existing code references :/GenyDL.png
    # (window icon in main.cpp and qrc:/GenyDL.png in QML). Do not remove.
    GenyDL.png

    # Canonical icon assets (PREFIX /, so paths become :/resources/icons/...).
    resources/icons/app/GenyDL.png
    resources/icons/tray/GenyDL.png
    resources/icons/tray/GenyDLTemplate.png
    resources/icons/tray/GenyDLTemplate@2x.png
    resources/icons/tray/GenyDLTemplate@3x.png

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

genydl_filter_existing(qml_resource_files_existing ${qml_resource_files})

qt_add_resources(${APP_NAME} GenyDLAssets
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

genydl_filter_existing(qml_module_resources_existing ${qml_module_resources})

qt_add_qml_module(${APP_NAME}
    URI GenyDL
    VERSION 1.0
    QML_FILES
        ${qml_files_existing}
        ui/utils.js
    RESOURCES
        ${qml_module_resources_existing}
    SOURCES
        ${GENYDL_IMPL_SOURCES}
)

target_sources(${APP_NAME}
    PUBLIC
        FILE_SET CXX_MODULES
        TYPE CXX_MODULES
        BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
        FILES ${GENYDL_MODULE_IFS}
)

set_property(TARGET ${APP_NAME} PROPERTY CXX_SCAN_FOR_MODULES ON)

# -------------------------
# Platform bundle metadata
# -------------------------
if(APPLE)
    set_target_properties(${APP_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_GUI_IDENTIFIER "${GENYDL_BUNDLE_IDENTIFIER}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_ICON_FILE "${GENYDL_MACOS_ICON_FILE}"
    )

    if(EXISTS "${GENYDL_MACOS_INFO_PLIST}")
        set_target_properties(${APP_NAME} PROPERTIES
            MACOSX_BUNDLE_INFO_PLIST "${GENYDL_MACOS_INFO_PLIST}"
        )
    endif()

    if(EXISTS "${GENYDL_MACOS_ICON_ICNS}")
        set_source_files_properties("${GENYDL_MACOS_ICON_ICNS}"
            PROPERTIES MACOSX_PACKAGE_LOCATION "Resources"
        )

        target_sources(${APP_NAME} PRIVATE "${GENYDL_MACOS_ICON_ICNS}")
    endif()
elseif(WIN32)
    set_target_properties(${APP_NAME} PROPERTIES
        WIN32_EXECUTABLE TRUE
    )

    if(EXISTS "${GENYDL_WINDOWS_RC}")
        target_sources(${APP_NAME} PRIVATE "${GENYDL_WINDOWS_RC}")
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

if(GENYDL_HAVE_LIBTORRENT)
    target_link_libraries(${APP_NAME} PRIVATE ${GENYDL_LIBTORRENT_TARGET})
    target_compile_definitions(${APP_NAME} PRIVATE GENYDL_USE_LIBTORRENT=1)
endif()

target_include_directories(${APP_NAME}
    PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

# -------------------------
# Tests
# -------------------------
if(GENYDL_BUILD_TESTS)
    enable_testing()

    find_package(Qt6 6.8 REQUIRED COMPONENTS Core Test Gui Network Concurrent Widgets)

    qt_add_executable(genydl_backend_tests
        tests/backend_tests.cpp
    )

    target_sources(genydl_backend_tests
        PUBLIC
            FILE_SET CXX_MODULES
            TYPE CXX_MODULES
            BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
            FILES ${GENYDL_MODULE_IFS}
    )

    set_property(TARGET genydl_backend_tests PROPERTY CXX_SCAN_FOR_MODULES ON)

    target_sources(genydl_backend_tests PRIVATE ${GENYDL_IMPL_SOURCES})

    target_link_libraries(genydl_backend_tests
        PRIVATE
            Qt6::Core
            Qt6::Test
            Qt6::Network
            Qt6::Concurrent
            Qt6::Gui
            Qt6::Widgets
    )

    if(GENYDL_HAVE_LIBTORRENT)
        target_link_libraries(genydl_backend_tests PRIVATE ${GENYDL_LIBTORRENT_TARGET})
        target_compile_definitions(genydl_backend_tests PRIVATE GENYDL_USE_LIBTORRENT=1)
    endif()

    target_include_directories(genydl_backend_tests
        PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )

    add_test(NAME genydl_backend_tests COMMAND genydl_backend_tests)
endif()

# -----------------------------------------------------------------------------
# macOS: POST_BUILD macdeployqt + codesign
# -----------------------------------------------------------------------------
if(APPLE AND GENYDL_MACOS_POSTBUILD_DEPLOY)
    find_program(GENYDL_MACDEPLOYQT_EXECUTABLE
        NAMES macdeployqt
        HINTS
            "$ENV{QTDIR}/bin"
            "${Qt6_DIR}/../../../bin"
            "${CMAKE_USER_HOME_DIRECTORY}/Qt/*/macos/bin"
            "$ENV{QT_DIR}/bin"
            "$ENV{Qt6_ROOT}/bin"
            "$ENV{QT_ROOT}/bin"
    )

    find_program(GENYDL_CODESIGN_EXECUTABLE NAMES codesign)

    if(NOT GENYDL_MACDEPLOYQT_EXECUTABLE)
        message(FATAL_ERROR "macdeployqt not found. Set QTDIR or ensure Qt bin is in PATH.")
    endif()

    if(NOT GENYDL_CODESIGN_EXECUTABLE AND GENYDL_MACOS_CODESIGN)
        message(FATAL_ERROR "codesign not found.")
    endif()

    set(genydl_bundle_dir "$<TARGET_BUNDLE_DIR:${APP_NAME}>")
    set(genydl_bundle_macos "${genydl_bundle_dir}/Contents/MacOS")

    set(genydl_macdeployqt_args "")

    if(GENYDL_MACDEPLOYQT_ALWAYS_OVERWRITE)
        list(APPEND genydl_macdeployqt_args "-always-overwrite")
    endif()

    if(GENYDL_MACDEPLOYQT_NO_STRIP)
        list(APPEND genydl_macdeployqt_args "-no-strip")
    endif()

    if(GENYDL_CODESIGN_IDENTITY STREQUAL "-")
        set(genydl_codesign_common
            "--force"
            "--deep"
            "--sign" "${GENYDL_CODESIGN_IDENTITY}"
        )
    else()
        set(genydl_codesign_common
            "--force"
            "--deep"
            "--options" "runtime"
            "--timestamp"
            "--sign" "${GENYDL_CODESIGN_IDENTITY}"
        )
    endif()

    set(genydl_codesign_ent "")

    if(GENYDL_CODESIGN_ENTITLEMENTS AND EXISTS "${GENYDL_CODESIGN_ENTITLEMENTS}")
        set(genydl_codesign_ent "--entitlements" "${GENYDL_CODESIGN_ENTITLEMENTS}")
    endif()

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND $<${GENYDL_IS_RELEASE}:${CMAKE_COMMAND}> -E make_directory "${genydl_bundle_macos}"

        COMMAND $<${GENYDL_IS_RELEASE}:${CMAKE_COMMAND}> -E copy_if_different
                "$<TARGET_FILE:GenyDLUpdaterHelper>"
                "${genydl_bundle_macos}/GenyDLUpdaterHelper"

        COMMAND $<${GENYDL_IS_RELEASE}:${CMAKE_COMMAND}> -E echo "Running macdeployqt on GenyDL bundle..."

        COMMAND $<${GENYDL_IS_RELEASE}:${GENYDL_MACDEPLOYQT_EXECUTABLE}>
                "${genydl_bundle_dir}"
                -verbose=3
                -qmldir=${CMAKE_CURRENT_SOURCE_DIR}
                -executable=${genydl_bundle_macos}/GenyDLUpdaterHelper
                ${genydl_macdeployqt_args}

        COMMAND $<${GENYDL_IS_RELEASE}:${CMAKE_COMMAND}> -E echo "Codesigning after macdeployqt..."

        COMMAND $<$<AND:${GENYDL_IS_RELEASE},$<BOOL:${GENYDL_MACOS_CODESIGN}>>:${GENYDL_CODESIGN_EXECUTABLE}>
                ${genydl_codesign_common} ${genydl_codesign_ent}
                "${genydl_bundle_dir}"

        COMMAND $<$<AND:${GENYDL_IS_RELEASE},$<BOOL:${GENYDL_MACOS_CODESIGN}>>:${GENYDL_CODESIGN_EXECUTABLE}>
                --verify --deep --strict --verbose=2
                "${genydl_bundle_dir}"

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
    foreach(genydl_runtime_lib IN LISTS CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        message(STATUS "  ${genydl_runtime_lib}")
    endforeach()

    if(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        install(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}
            CONFIGURATIONS Release RelWithDebInfo
            DESTINATION "."
        )
    endif()

    set(GENYDL_MSVC_REDIST_ARCH "")
    if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64$")
        set(GENYDL_MSVC_REDIST_ARCH "arm64")
    elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$|^[Ww]in64$|^[Aa][Mm][Dd]64$")
        set(GENYDL_MSVC_REDIST_ARCH "x64")
    elseif(GENYDL_TARGET_BUILD_ARCH STREQUAL "arm64")
        set(GENYDL_MSVC_REDIST_ARCH "arm64")
    else()
        set(GENYDL_MSVC_REDIST_ARCH "x64")
    endif()

    set(GENYDL_MSVC_REDIST_DLLS "")

    if(DEFINED ENV{VCToolsRedistDir} AND NOT "$ENV{VCToolsRedistDir}" STREQUAL "")
        file(TO_CMAKE_PATH "$ENV{VCToolsRedistDir}" GENYDL_VC_REDIST_DIR)

        file(GLOB GENYDL_MSVC_CRT_DLLS
            "${GENYDL_VC_REDIST_DIR}/${GENYDL_MSVC_REDIST_ARCH}/Microsoft.VC*.CRT/*.dll"
        )

        file(GLOB GENYDL_MSVC_OPENMP_DLLS
            "${GENYDL_VC_REDIST_DIR}/${GENYDL_MSVC_REDIST_ARCH}/Microsoft.VC*.OpenMP/*.dll"
        )

        list(APPEND GENYDL_MSVC_REDIST_DLLS
            ${GENYDL_MSVC_CRT_DLLS}
            ${GENYDL_MSVC_OPENMP_DLLS}
        )
    endif()

    if(NOT GENYDL_MSVC_REDIST_DLLS AND DEFINED ENV{VCINSTALLDIR} AND NOT "$ENV{VCINSTALLDIR}" STREQUAL "")
        file(TO_CMAKE_PATH "$ENV{VCINSTALLDIR}" GENYDL_VC_INSTALL_DIR)

        file(GLOB_RECURSE GENYDL_MSVC_CRT_DLLS
            "${GENYDL_VC_INSTALL_DIR}/Redist/MSVC/*/${GENYDL_MSVC_REDIST_ARCH}/Microsoft.VC*.CRT/*.dll"
        )

        file(GLOB_RECURSE GENYDL_MSVC_OPENMP_DLLS
            "${GENYDL_VC_INSTALL_DIR}/Redist/MSVC/*/${GENYDL_MSVC_REDIST_ARCH}/Microsoft.VC*.OpenMP/*.dll"
        )

        list(APPEND GENYDL_MSVC_REDIST_DLLS
            ${GENYDL_MSVC_CRT_DLLS}
            ${GENYDL_MSVC_OPENMP_DLLS}
        )
    endif()

    list(REMOVE_DUPLICATES GENYDL_MSVC_REDIST_DLLS)

    message(STATUS "GENYDL MSVC redist arch: ${GENYDL_MSVC_REDIST_ARCH}")
    message(STATUS "GENYDL explicit MSVC redist DLLs:")
    foreach(genydl_redist_dll IN LISTS GENYDL_MSVC_REDIST_DLLS)
        message(STATUS "  ${genydl_redist_dll}")
    endforeach()

    if(GENYDL_MSVC_REDIST_DLLS)
        install(FILES ${GENYDL_MSVC_REDIST_DLLS}
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
    set(GENYDL_RUNTIME_DEST ".")
else()
    set(GENYDL_RUNTIME_DEST "${CMAKE_INSTALL_BINDIR}")
endif()

install(TARGETS ${APP_NAME}
    CONFIGURATIONS Release RelWithDebInfo
    BUNDLE DESTINATION .
    RUNTIME DESTINATION "${GENYDL_RUNTIME_DEST}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)

if(APPLE)
    install(TARGETS GenyDLUpdaterHelper
        CONFIGURATIONS Release RelWithDebInfo
        RUNTIME DESTINATION "${GENYDL_FINAL_OUTPUT_NAME}.app/Contents/MacOS"
    )
else()
    install(TARGETS GenyDLUpdaterHelper
        CONFIGURATIONS Release RelWithDebInfo
        RUNTIME DESTINATION "${GENYDL_RUNTIME_DEST}"
    )
endif()

if(UNIX AND NOT APPLE)
    if(EXISTS "${GENYDL_LINUX_ICON_PNG}")
        install(FILES "${GENYDL_LINUX_ICON_PNG}"
            DESTINATION "share/icons/hicolor/512x512/apps"
            RENAME "genydl.png"
        )
    endif()
endif()

# -----------------------------------------------------------------------------
# Linux deploy
# -----------------------------------------------------------------------------
if(UNIX AND NOT APPLE AND GENYDL_LINUX_INSTALL_DEPLOY)
    set(genydl_linux_deploy_args "")

    if(NOT GENYDL_LINUX_DEPLOY_TRANSLATIONS)
        list(APPEND genydl_linux_deploy_args NO_TRANSLATIONS)
    endif()

    qt_generate_deploy_qml_app_script(
        TARGET ${APP_NAME}
        OUTPUT_SCRIPT GENYDL_LINUX_DEPLOY_SCRIPT
        NO_UNSUPPORTED_PLATFORM_ERROR
        ${genydl_linux_deploy_args}
    )

    install(SCRIPT ${GENYDL_LINUX_DEPLOY_SCRIPT})
endif()

# -----------------------------------------------------------------------------
# Windows deploy
# -----------------------------------------------------------------------------
if(WIN32 AND GENYDL_WINDOWS_INSTALL_DEPLOY)
    find_program(GENYDL_WINDEPLOYQT_EXECUTABLE
        NAMES windeployqt
        HINTS
            "$ENV{QTDIR}/bin"
            "${Qt6_DIR}/../../../bin"
            "C:/Qt/*/*/bin"
            "$ENV{QT_DIR}/bin"
            "$ENV{Qt6_ROOT}/bin"
            "$ENV{QT_ROOT}/bin"
    )

    if(NOT GENYDL_WINDEPLOYQT_EXECUTABLE)
        message(FATAL_ERROR "windeployqt not found. Set QTDIR or make sure Qt bin is in PATH.")
    endif()

    install(CODE
        "message(STATUS \"[deploy] Running windeployqt for GenyDL (install tree, root layout)\")\n
         set(_root \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}\")\n
         file(TO_CMAKE_PATH \"\${_root}\" _root)\n
         set(_exe \"\${_root}/${GENYDL_FINAL_OUTPUT_NAME}.exe\")\n
         if(NOT EXISTS \"\${_exe}\")\n
           message(FATAL_ERROR \"[deploy] Installed exe not found: \${_exe}\")\n
         endif()\n
         set(_args \"\${_exe}\" \"--qmldir\" \"${CMAKE_CURRENT_SOURCE_DIR}\" \"--dir\" \"\${_root}\" \"--verbose\" \"2\" \"--release\")\n
         if(${GENYDL_WINDEPLOYQT_COMPILER_RUNTIME})\n
           list(APPEND _args \"--compiler-runtime\")\n
         endif()\n
         if(${GENYDL_WINDEPLOYQT_TRANSLATIONS})\n
           list(APPEND _args \"--translations\")\n
         else()\n
           list(APPEND _args \"--no-translations\")\n
         endif()\n
         execute_process(\n
           COMMAND \"${GENYDL_WINDEPLOYQT_EXECUTABLE}\" \${_args}\n
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

set(GENYDL_DOC_README_SRC "")
set(GENYDL_DOC_LICENSE_SRC "")

if(GENYDL_BUNDLE_DOCS)
    foreach(genydl_doc_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/README.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/README.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/README"
    )
        if(EXISTS "${genydl_doc_candidate}")
            set(GENYDL_DOC_README_SRC "${genydl_doc_candidate}")
            break()
        endif()
    endforeach()

    foreach(genydl_doc_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/COPYING"
    )
        if(EXISTS "${genydl_doc_candidate}")
            set(GENYDL_DOC_LICENSE_SRC "${genydl_doc_candidate}")
            break()
        endif()
    endforeach()

    if(GENYDL_DOC_README_SRC)
        set(GENYDL_DOC_README_TXT "${CMAKE_BINARY_DIR}/NSIS_README.txt")
        configure_file("${GENYDL_DOC_README_SRC}" "${GENYDL_DOC_README_TXT}" COPYONLY)
        install(FILES "${GENYDL_DOC_README_TXT}" DESTINATION "." RENAME "README.txt")
    else()
        message(WARNING "No README file found to bundle.")
    endif()

    if(GENYDL_DOC_LICENSE_SRC)
        set(GENYDL_DOC_LICENSE_TXT "${CMAKE_BINARY_DIR}/NSIS_LICENSE.txt")
        configure_file("${GENYDL_DOC_LICENSE_SRC}" "${GENYDL_DOC_LICENSE_TXT}" COPYONLY)
        install(FILES "${GENYDL_DOC_LICENSE_TXT}" DESTINATION "." RENAME "LICENSE.txt")
    else()
        message(WARNING "No LICENSE file found to bundle.")
    endif()
endif()

# -----------------------------------------------------------------------------
# CPack / Installer Packaging
# -----------------------------------------------------------------------------
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VENDOR "${GENYDL_VENDOR}")
set(CPACK_PACKAGE_CONTACT "${GENYDL_PACKAGE_CONTACT}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${GENYDL_PACKAGE_SUMMARY}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")

set(CPACK_OUTPUT_FILE_PREFIX "${GENYDL_FINAL_DIR}")
set(CPACK_PACKAGE_FILE_NAME "${PROJECT_NAME}-${PROJECT_VERSION}-${GENYDL_OS}-${GENYDL_ARCH}")
set(CPACK_PACKAGING_INSTALL_PREFIX "/")

if(WIN32)
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_NSIS_DISPLAY_NAME "${APP_NAME}")
    set(CPACK_NSIS_PACKAGE_NAME "${APP_NAME}")
    set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "${APP_NAME}")

    set(GENYDL_EXE_NAME "${GENYDL_FINAL_OUTPUT_NAME}.exe")

    set(CPACK_NSIS_MENU_LINKS
        "${GENYDL_EXE_NAME}" "${APP_NAME}"
    )

    set(CPACK_NSIS_CREATE_ICONS_EXTRA
        "CreateShortCut \\\"$DESKTOP\\\\${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\${GENYDL_EXE_NAME}\\\"\n"
        "CreateDirectory \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\"\n"
        "CreateShortCut \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\${GENYDL_EXE_NAME}\\\"\n"
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

    set(GENYDL_DMG_BACKGROUND_IMAGE "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/background.png")
    set(GENYDL_DMG_DS_STORE_SETUP_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/dmg-setup.scpt")

    set(CPACK_DMG_VOLUME_NAME "${APP_NAME} ${PROJECT_VERSION}")
    set(CPACK_DMG_FORMAT "UDZO")

    if(EXISTS "${GENYDL_DMG_BACKGROUND_IMAGE}")
        set(CPACK_DMG_BACKGROUND_IMAGE "${GENYDL_DMG_BACKGROUND_IMAGE}")
    endif()

    if(EXISTS "${GENYDL_DMG_DS_STORE_SETUP_SCRIPT}")
        set(CPACK_DMG_DS_STORE_SETUP_SCRIPT "${GENYDL_DMG_DS_STORE_SETUP_SCRIPT}")
    endif()

else()
    set(CPACK_GENERATOR "TGZ")
endif()

include(CPack)

message(STATUS "Build dir: ${CMAKE_BINARY_DIR}")
message(STATUS "Packages dir: ${GENYDL_FINAL_DIR}")
message(STATUS "Packaging: run cpack. For multi-config generators use: cpack -C Release")
