# Copyright (C) 2026 Genyleap LLC.
# SPDX-License-Identifier: LicenseRef-Geny-Commercial OR MIT

cmake_minimum_required(VERSION 3.28)

# -----------------------------------------------------------------------------
# RAAD CMakeLists
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
set(PROJECT_NAME "Raad")
set(PROJECT_REAL_NAME "Raad")
set(APP_NAME "${PROJECT_REAL_NAME}")

set(PROJECT_VERSION_MAJOR 1)
set(PROJECT_VERSION_MINOR 0)
set(PROJECT_VERSION_PATCH 0)
set(PROJECT_VERSION "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}.${PROJECT_VERSION_PATCH}")

# -------------------------
# Target OS / Arch
# -------------------------
set(RAAD_TARGET_BUILD_ARCH "" CACHE STRING "Override target arch for output build/package (arm64|x86_64)")

# Must be defined before project() on macOS.
set(RAAD_MACOS_DEPLOYMENT_TARGET "15.1" CACHE STRING "Minimum macOS version")

if(APPLE)
    if(NOT RAAD_TARGET_BUILD_ARCH)
        set(RAAD_TARGET_BUILD_ARCH "arm64" CACHE STRING "Override target arch for output build/package (arm64|x86_64)" FORCE)
    endif()

    set(CMAKE_OSX_ARCHITECTURES "${RAAD_TARGET_BUILD_ARCH}" CACHE STRING "Build architecture" FORCE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "${RAAD_MACOS_DEPLOYMENT_TARGET}" CACHE STRING "Minimum macOS version" FORCE)
endif()

project(${PROJECT_NAME} VERSION ${PROJECT_VERSION} LANGUAGES CXX)

if(POLICY CMP0155)
    cmake_policy(SET CMP0155 NEW)
endif()

# -------------------------
# Detect Windows generator architecture
# -------------------------
if(WIN32 AND NOT RAAD_TARGET_BUILD_ARCH)
    if(CMAKE_GENERATOR_PLATFORM MATCHES "^[Aa][Rr][Mm]64$")
        set(RAAD_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected Windows target arch" FORCE)
    elseif(CMAKE_GENERATOR_PLATFORM MATCHES "^[Xx]64$|^[Ww]in64$|^[Aa][Mm][Dd]64$")
        set(RAAD_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected Windows target arch" FORCE)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|arm64|aarch64")
        set(RAAD_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected Windows target arch" FORCE)
    else()
        set(RAAD_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected Windows target arch" FORCE)
    endif()
elseif(NOT RAAD_TARGET_BUILD_ARCH)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|arm64|aarch64")
        set(RAAD_TARGET_BUILD_ARCH "arm64" CACHE STRING "Detected target arch" FORCE)
    else()
        set(RAAD_TARGET_BUILD_ARCH "x86_64" CACHE STRING "Detected target arch" FORCE)
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
message(STATUS "RAAD target build arch: ${RAAD_TARGET_BUILD_ARCH}")

# Release/RelWithDebInfo generator-expression.
set(RAAD_IS_RELEASE "$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>>")

# -------------------------
# Options
# -------------------------
option(RAAD_USE_MODULES "Enable C++20 modules" ON)
option(RAAD_LLVM_AUTO_SCAN "Auto-detect LLVM/clang for modules" ON)
option(RAAD_QT_AUTO_SCAN "Auto-detect Qt installation prefix" ON)
option(RAAD_BUILD_TESTS "Build backend tests" ON)

option(RAAD_MACOS_POSTBUILD_DEPLOY "Run macdeployqt on the build .app in POST_BUILD" ON)
option(RAAD_MACOS_CODESIGN "Codesign the .app after macdeployqt" ON)

set(RAAD_CODESIGN_IDENTITY "-" CACHE STRING
    "macOS codesign identity. Use '-' for ad-hoc signing, or 'Developer ID Application: ...' for release."
)

set(RAAD_CODESIGN_ENTITLEMENTS "" CACHE FILEPATH
    "Optional entitlements plist path for codesign."
)

option(RAAD_MACDEPLOYQT_ALWAYS_OVERWRITE "Pass -always-overwrite to macdeployqt" OFF)
option(RAAD_MACDEPLOYQT_NO_STRIP "Pass -no-strip to macdeployqt" OFF)

option(RAAD_WINDOWS_INSTALL_DEPLOY
    "Run windeployqt during install() so CPack includes Qt/QML dependencies" ON
)

option(RAAD_WINDEPLOYQT_COMPILER_RUNTIME
    "Pass --compiler-runtime to windeployqt" ON
)

option(RAAD_WINDEPLOYQT_TRANSLATIONS
    "Include Qt translations via windeployqt" OFF
)

option(RAAD_LINUX_INSTALL_DEPLOY
    "Run Qt Linux deployment during install() so CPack TGZ includes Qt/QML dependencies" ON
)

option(RAAD_LINUX_DEPLOY_TRANSLATIONS
    "Include Qt translations in Linux deployment package" OFF
)

option(RAAD_BUNDLE_DOCS
    "Install README and LICENSE at package root and NSIS wizard" ON
)

set(RAAD_TARGET_OS "" CACHE STRING "Override target OS for output naming (macos|linux|windows)")
set(RAAD_TARGET_ARCH "${RAAD_TARGET_BUILD_ARCH}" CACHE STRING "Override target arch for output naming (arm64|x86_64)" FORCE)
set(RAAD_OUTPUT_NAME "" CACHE STRING "Optional explicit output name")

# -------------------------
# Normalize OS / Arch
# -------------------------
if(RAAD_TARGET_OS AND NOT RAAD_TARGET_OS STREQUAL "")
    string(TOLOWER "${RAAD_TARGET_OS}" RAAD_OS)
else()
    if(APPLE)
        set(RAAD_OS "macos")
    elseif(WIN32)
        set(RAAD_OS "windows")
    else()
        set(RAAD_OS "linux")
    endif()
endif()

set(RAAD_ARCH_RAW "")

if(RAAD_TARGET_ARCH AND NOT RAAD_TARGET_ARCH STREQUAL "")
    set(RAAD_ARCH_RAW "${RAAD_TARGET_ARCH}")
elseif(APPLE AND CMAKE_OSX_ARCHITECTURES)
    list(GET CMAKE_OSX_ARCHITECTURES 0 RAAD_ARCH_RAW)
elseif(DEFINED CMAKE_SYSTEM_PROCESSOR AND CMAKE_SYSTEM_PROCESSOR)
    set(RAAD_ARCH_RAW "${CMAKE_SYSTEM_PROCESSOR}")
else()
    set(RAAD_ARCH_RAW "x86_64")
endif()

string(TOLOWER "${RAAD_ARCH_RAW}" RAAD_ARCH)

if(RAAD_ARCH MATCHES "^(arm64|aarch64|arm64-v8a)$")
    set(RAAD_ARCH "arm64")
elseif(RAAD_ARCH MATCHES "^(x86_64|amd64|x64|64)$")
    set(RAAD_ARCH "x86_64")
endif()

if(RAAD_OUTPUT_NAME AND NOT RAAD_OUTPUT_NAME STREQUAL "")
    set(RAAD_FINAL_OUTPUT_NAME "${RAAD_OUTPUT_NAME}")
else()
    set(RAAD_FINAL_OUTPUT_NAME "${APP_NAME}")
endif()

message(STATUS "RAAD build: OS='${RAAD_OS}' ARCH='${RAAD_ARCH}'")
message(STATUS "RAAD output name: ${RAAD_FINAL_OUTPUT_NAME}")

# -------------------------
# Final packages folder
# -------------------------
set(RAAD_FINAL_ROOT "${CMAKE_BINARY_DIR}/final")
set(RAAD_FINAL_DIR "${RAAD_FINAL_ROOT}/${RAAD_OS}-${RAAD_ARCH}")
file(MAKE_DIRECTORY "${RAAD_FINAL_DIR}")
message(STATUS "RAAD final output folder: ${RAAD_FINAL_DIR}")

# -------------------------
# Metadata
# -------------------------
set(RAAD_VENDOR "Genyleap")
set(RAAD_PACKAGE_CONTACT "info@genyleap.com")
set(RAAD_PACKAGE_SUMMARY "RAAD Internet Download Manager")
set(RAAD_COPYRIGHT "Copyright 2026 by Genyleap LLC")
set(RAAD_BUNDLE_IDENTIFIER "com.genyleap.raad")

set(RAAD_MACOS_ICON_FILE "Raad.icns")
set(RAAD_MACOS_ICON_ICNS "${CMAKE_CURRENT_SOURCE_DIR}/Raad.icns")
set(RAAD_WINDOWS_ICON_ICO "${CMAKE_CURRENT_SOURCE_DIR}/Raad.ico")
set(RAAD_LINUX_ICON_PNG "${CMAKE_CURRENT_SOURCE_DIR}/Raad.png")

set(RAAD_MACOS_INFO_PLIST_IN "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/Info.plist.in")
set(RAAD_MACOS_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/generated/Info.plist")

set(RAAD_WINDOWS_RC_IN "${CMAKE_CURRENT_SOURCE_DIR}/properties/Windows/app.rc.in")
set(RAAD_WINDOWS_RC "${CMAKE_CURRENT_BINARY_DIR}/generated/raad_app.rc")

set(RAAD_RC_FILE_VERSION "${PROJECT_VERSION_MAJOR},${PROJECT_VERSION_MINOR},${PROJECT_VERSION_PATCH},0")
set(RAAD_RC_PRODUCT_VERSION "${PROJECT_VERSION_MAJOR},${PROJECT_VERSION_MINOR},${PROJECT_VERSION_PATCH},0")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated")

if(EXISTS "${RAAD_MACOS_INFO_PLIST_IN}")
    configure_file("${RAAD_MACOS_INFO_PLIST_IN}" "${RAAD_MACOS_INFO_PLIST}" @ONLY)
endif()

if(WIN32 AND EXISTS "${RAAD_WINDOWS_RC_IN}")
    file(TO_CMAKE_PATH "${RAAD_WINDOWS_ICON_ICO}" RAAD_WINDOWS_ICON_ICO_RC)
    configure_file("${RAAD_WINDOWS_RC_IN}" "${RAAD_WINDOWS_RC}" @ONLY)
endif()

# -------------------------
# macOS SDK for Homebrew LLVM
# -------------------------
if(APPLE)
    execute_process(
        COMMAND xcrun --sdk macosx --show-sdk-path
        OUTPUT_VARIABLE RAAD_MACOS_SDK
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(RAAD_MACOS_SDK)
        set(CMAKE_OSX_SYSROOT "${RAAD_MACOS_SDK}" CACHE PATH "macOS SDK" FORCE)
    endif()
endif()

# -------------------------
# Compiler / module checks
# -------------------------
set(RAAD_LLVM_HINTS "")

if(RAAD_LLVM_AUTO_SCAN)
    if(DEFINED ENV{LLVM_ROOT})
        list(APPEND RAAD_LLVM_HINTS "$ENV{LLVM_ROOT}/bin")
    endif()

    if(DEFINED ENV{LLVM_HOME})
        list(APPEND RAAD_LLVM_HINTS "$ENV{LLVM_HOME}/bin")
    endif()

    if(DEFINED ENV{LLVM_DIR})
        list(APPEND RAAD_LLVM_HINTS "$ENV{LLVM_DIR}/bin")
    endif()

    find_program(RAAD_BREW brew HINTS /opt/homebrew/bin /usr/local/bin)

    if(RAAD_BREW)
        execute_process(
            COMMAND "${RAAD_BREW}" --prefix llvm
            OUTPUT_VARIABLE RAAD_BREW_LLVM_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(RAAD_BREW_LLVM_PREFIX)
            list(APPEND RAAD_LLVM_HINTS "${RAAD_BREW_LLVM_PREFIX}/bin")
        endif()
    endif()
endif()

find_program(RAAD_CLANG NAMES clang HINTS ${RAAD_LLVM_HINTS})
find_program(RAAD_CLANGXX NAMES clang++ clang-cl HINTS ${RAAD_LLVM_HINTS})
find_program(RAAD_CLANG_SCAN_DEPS NAMES clang-scan-deps HINTS ${RAAD_LLVM_HINTS})

if(NOT RAAD_CLANG_SCAN_DEPS AND CMAKE_CXX_COMPILER)
    get_filename_component(RAAD_CXX_DIR "${CMAKE_CXX_COMPILER}" DIRECTORY)

    if(RAAD_CXX_DIR)
        find_program(RAAD_CLANG_SCAN_DEPS
            NAMES clang-scan-deps
            HINTS "${RAAD_CXX_DIR}"
        )
    endif()
endif()

set(RAAD_CLANGXX_IS_APPLE_PATH FALSE)

if(RAAD_CLANGXX MATCHES "^/usr/bin/clang\\+\\+$" OR
   RAAD_CLANGXX MATCHES "XcodeDefault\\.xctoolchain")
    set(RAAD_CLANGXX_IS_APPLE_PATH TRUE)
endif()

if(RAAD_CLANG_SCAN_DEPS AND NOT DEFINED CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS)
    set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS
        "${RAAD_CLANG_SCAN_DEPS}"
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
    add_compile_options(/Zc:__cplusplus /permissive-)
endif()

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

if(NOT "cppm" IN_LIST CMAKE_AUTOMOC_EXTENSIONS)
    list(APPEND CMAKE_AUTOMOC_EXTENSIONS "cppm")
endif()

if(RAAD_USE_MODULES)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        if(RAAD_CLANGXX AND RAAD_CLANG_SCAN_DEPS AND NOT RAAD_CLANGXX_IS_APPLE_PATH)
            message(FATAL_ERROR
                "AppleClang is active in this build directory. Delete build directory and reconfigure with LLVM clang:\n"
                "  -DCMAKE_C_COMPILER=${RAAD_CLANG}\n"
                "  -DCMAKE_CXX_COMPILER=${RAAD_CLANGXX}\n"
                "  -DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${RAAD_CLANG_SCAN_DEPS}\n"
                "or set -DRAAD_USE_MODULES=OFF."
            )
        else()
            message(FATAL_ERROR
                "AppleClang does not provide stable module scanning here. "
                "Install LLVM clang or set -DRAAD_USE_MODULES=OFF."
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
        "RAAD_USE_MODULES=OFF is not supported in this source tree because backend sources import project modules. "
        "Build with RAAD_USE_MODULES=ON and a compiler that supports module dependency scanning."
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

if(RAAD_QT_AUTO_SCAN AND NOT Qt6_DIR)
    set(raad_qt_candidates "")

    set(raad_home "${CMAKE_USER_HOME_DIRECTORY}")

    if(NOT raad_home AND DEFINED ENV{HOME})
        set(raad_home "$ENV{HOME}")
    endif()

    if(APPLE)
        file(GLOB raad_qt_candidates
            "${raad_home}/Qt/*/macos"
            "${raad_home}/Qt/*/clang_64"
            "/opt/Qt/*/macos"
            "/usr/local/Qt/*/macos"
        )
    elseif(WIN32)
        if(RAAD_TARGET_BUILD_ARCH STREQUAL "arm64")
            file(GLOB raad_qt_candidates
                "C:/Qt/*/msvc*_arm64"
                "C:/Qt/*/msvc*arm64"
                "C:/Qt/*/msvc*_64"
                "C:/Qt/*/mingw*_64"
                "C:/Qt/*/clang_64"
            )
        else()
            file(GLOB raad_qt_candidates
                "C:/Qt/*/msvc*_64"
                "C:/Qt/*/mingw*_64"
                "C:/Qt/*/clang_64"
                "C:/Qt/*/msvc*_arm64"
                "C:/Qt/*/msvc*arm64"
            )
        endif()
    else()
        file(GLOB raad_qt_candidates
            "${raad_home}/Qt/*/gcc_64"
            "${raad_home}/Qt/*/linux_gcc_64"
            "${raad_home}/Qt/*/clang_64"
            "/opt/Qt/*/gcc_64"
            "/opt/Qt/*/clang_64"
        )
    endif()

    foreach(raad_qt_prefix IN LISTS raad_qt_candidates)
        if(EXISTS "${raad_qt_prefix}/lib/cmake/Qt6/Qt6Config.cmake")
            list(APPEND CMAKE_PREFIX_PATH "${raad_qt_prefix}")

            if(NOT Qt6_DIR)
                set(Qt6_DIR "${raad_qt_prefix}/lib/cmake/Qt6" CACHE PATH "Qt6 config directory" FORCE)
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
function(raad_filter_existing out_var)
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
set(RAAD_MODULE_IFS
    src/core/downloadertask.cppm
    src/core/downloadmanager.cppm
    src/core/downloadmodel.cppm
    src/utils/download_utils.cppm
    src/utils/category_utils.cppm
    src/utils/version_utils.cppm
    src/services/power_monitor.cppm
    src/services/update_client.cppm
)

set(RAAD_IMPL_SOURCES
    src/core/downloadertask.cpp
    src/core/downloadmanager.cpp
    src/core/downloadmodel.cpp
    src/utils/download_utils.cpp
    src/utils/category_utils.cpp
    src/utils/version_utils.cpp
    src/services/power_monitor.cpp
    src/services/update_client.cpp
)

qt_add_executable(${APP_NAME}
    WIN32
    MACOSX_BUNDLE
    src/core/main.cpp
)

set_target_properties(${APP_NAME} PROPERTIES OUTPUT_NAME "${RAAD_FINAL_OUTPUT_NAME}")

set_target_properties(${APP_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)

qt_add_executable(RaadUpdaterHelper
    src/updaterhelper/main.cpp
)

target_link_libraries(RaadUpdaterHelper PRIVATE Qt6::Core)

set_target_properties(RaadUpdaterHelper PROPERTIES
    OUTPUT_NAME "RaadUpdaterHelper"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(WIN32 AND MSVC)
    target_link_options(RaadUpdaterHelper
        PRIVATE "/MANIFESTUAC:level='requireAdministrator' uiAccess='false'"
    )
endif()

if(APPLE)
    add_dependencies(${APP_NAME} RaadUpdaterHelper)
    set_target_properties(RaadUpdaterHelper PROPERTIES MACOSX_BUNDLE FALSE)

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:${APP_NAME}>/Contents/MacOS"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:RaadUpdaterHelper>"
                "$<TARGET_BUNDLE_DIR:${APP_NAME}>/Contents/MacOS/RaadUpdaterHelper"
        COMMENT "Copy updater helper into app bundle"
        VERBATIM
    )
else()
    add_dependencies(${APP_NAME} RaadUpdaterHelper)

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:RaadUpdaterHelper>"
                "$<TARGET_FILE_DIR:${APP_NAME}>/$<TARGET_FILE_NAME:RaadUpdaterHelper>"
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

raad_filter_existing(qml_files_existing ${qml_files})

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

raad_filter_existing(qml_singletons_existing ${qml_singletons})

set_source_files_properties(${qml_singletons_existing}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

# -------------------------
# Resources
# -------------------------
set(qml_resource_files
    Raad.png

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

raad_filter_existing(qml_resource_files_existing ${qml_resource_files})

qt_add_resources(${APP_NAME} RaadAssets
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

raad_filter_existing(qml_module_resources_existing ${qml_module_resources})

qt_add_qml_module(${APP_NAME}
    URI Raad
    VERSION 1.0
    QML_FILES
        ${qml_files_existing}
        ui/utils.js
    RESOURCES
        ${qml_module_resources_existing}
    SOURCES
        ${RAAD_IMPL_SOURCES}
)

target_sources(${APP_NAME}
    PUBLIC
        FILE_SET CXX_MODULES
        TYPE CXX_MODULES
        BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
        FILES ${RAAD_MODULE_IFS}
)

set_property(TARGET ${APP_NAME} PROPERTY CXX_SCAN_FOR_MODULES ON)

# -------------------------
# Platform bundle metadata
# -------------------------
if(APPLE)
    set_target_properties(${APP_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_GUI_IDENTIFIER "${RAAD_BUNDLE_IDENTIFIER}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
        MACOSX_BUNDLE_ICON_FILE "${RAAD_MACOS_ICON_FILE}"
    )

    if(EXISTS "${RAAD_MACOS_INFO_PLIST}")
        set_target_properties(${APP_NAME} PROPERTIES
            MACOSX_BUNDLE_INFO_PLIST "${RAAD_MACOS_INFO_PLIST}"
        )
    endif()

    if(EXISTS "${RAAD_MACOS_ICON_ICNS}")
        set_source_files_properties("${RAAD_MACOS_ICON_ICNS}"
            PROPERTIES MACOSX_PACKAGE_LOCATION "Resources"
        )

        target_sources(${APP_NAME} PRIVATE "${RAAD_MACOS_ICON_ICNS}")
    endif()
elseif(WIN32)
    set_target_properties(${APP_NAME} PROPERTIES
        WIN32_EXECUTABLE TRUE
    )

    if(EXISTS "${RAAD_WINDOWS_RC}")
        target_sources(${APP_NAME} PRIVATE "${RAAD_WINDOWS_RC}")
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
)

target_compile_definitions(${APP_NAME} PRIVATE APP_VERSION="${PROJECT_VERSION}")

target_include_directories(${APP_NAME}
    PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

# -------------------------
# Tests
# -------------------------
if(RAAD_BUILD_TESTS)
    enable_testing()

    find_package(Qt6 6.8 REQUIRED COMPONENTS Core Test Gui Network Concurrent)

    qt_add_executable(raad_backend_tests
        tests/backend_tests.cpp
    )

    target_sources(raad_backend_tests
        PUBLIC
            FILE_SET CXX_MODULES
            TYPE CXX_MODULES
            BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
            FILES ${RAAD_MODULE_IFS}
    )

    set_property(TARGET raad_backend_tests PROPERTY CXX_SCAN_FOR_MODULES ON)

    target_sources(raad_backend_tests PRIVATE ${RAAD_IMPL_SOURCES})

    target_link_libraries(raad_backend_tests
        PRIVATE
            Qt6::Core
            Qt6::Test
            Qt6::Network
            Qt6::Concurrent
            Qt6::Gui
    )

    target_include_directories(raad_backend_tests
        PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src"
    )

    add_test(NAME raad_backend_tests COMMAND raad_backend_tests)
endif()

# -----------------------------------------------------------------------------
# macOS: POST_BUILD macdeployqt + codesign
# -----------------------------------------------------------------------------
if(APPLE AND RAAD_MACOS_POSTBUILD_DEPLOY)
    find_program(RAAD_MACDEPLOYQT_EXECUTABLE
        NAMES macdeployqt
        HINTS
            "$ENV{QTDIR}/bin"
            "${Qt6_DIR}/../../../bin"
            "${CMAKE_USER_HOME_DIRECTORY}/Qt/*/macos/bin"
            "$ENV{QT_DIR}/bin"
            "$ENV{Qt6_ROOT}/bin"
            "$ENV{QT_ROOT}/bin"
    )

    find_program(RAAD_CODESIGN_EXECUTABLE NAMES codesign)

    if(NOT RAAD_MACDEPLOYQT_EXECUTABLE)
        message(FATAL_ERROR "macdeployqt not found. Set QTDIR or ensure Qt bin is in PATH.")
    endif()

    if(NOT RAAD_CODESIGN_EXECUTABLE AND RAAD_MACOS_CODESIGN)
        message(FATAL_ERROR "codesign not found.")
    endif()

    set(raad_bundle_dir "$<TARGET_BUNDLE_DIR:${APP_NAME}>")
    set(raad_bundle_macos "${raad_bundle_dir}/Contents/MacOS")

    set(raad_macdeployqt_args "")

    if(RAAD_MACDEPLOYQT_ALWAYS_OVERWRITE)
        list(APPEND raad_macdeployqt_args "-always-overwrite")
    endif()

    if(RAAD_MACDEPLOYQT_NO_STRIP)
        list(APPEND raad_macdeployqt_args "-no-strip")
    endif()

    set(raad_codesign_common "--force" "--deep" "--sign" "${RAAD_CODESIGN_IDENTITY}")

    set(raad_codesign_ent "")

    if(RAAD_CODESIGN_ENTITLEMENTS AND EXISTS "${RAAD_CODESIGN_ENTITLEMENTS}")
        set(raad_codesign_ent "--entitlements" "${RAAD_CODESIGN_ENTITLEMENTS}")
    endif()

    add_custom_command(TARGET ${APP_NAME} POST_BUILD
        COMMAND $<${RAAD_IS_RELEASE}:${CMAKE_COMMAND}> -E make_directory "${raad_bundle_macos}"

        COMMAND $<${RAAD_IS_RELEASE}:${CMAKE_COMMAND}> -E copy_if_different
                "$<TARGET_FILE:RaadUpdaterHelper>"
                "${raad_bundle_macos}/RaadUpdaterHelper"

        COMMAND $<${RAAD_IS_RELEASE}:${CMAKE_COMMAND}> -E echo "Running macdeployqt on Raad bundle..."

        COMMAND $<${RAAD_IS_RELEASE}:${RAAD_MACDEPLOYQT_EXECUTABLE}>
                "${raad_bundle_dir}"
                -verbose=3
                -qmldir=${CMAKE_CURRENT_SOURCE_DIR}
                -executable=${raad_bundle_macos}/RaadUpdaterHelper
                ${raad_macdeployqt_args}

        COMMAND $<${RAAD_IS_RELEASE}:${CMAKE_COMMAND}> -E echo "Codesigning after macdeployqt..."

        COMMAND $<$<AND:${RAAD_IS_RELEASE},$<BOOL:${RAAD_MACOS_CODESIGN}>>:${RAAD_CODESIGN_EXECUTABLE}>
                ${raad_codesign_common} ${raad_codesign_ent}
                "${raad_bundle_dir}"

        COMMAND $<$<AND:${RAAD_IS_RELEASE},$<BOOL:${RAAD_MACOS_CODESIGN}>>:${RAAD_CODESIGN_EXECUTABLE}>
                --verify --deep --strict --verbose=2
                "${raad_bundle_dir}"

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

    include(InstallRequiredSystemLibraries)

    message(STATUS "MSVC runtime libraries:")
    foreach(raad_runtime_lib IN LISTS CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
        message(STATUS "  ${raad_runtime_lib}")
    endforeach()
endif()

include(GNUInstallDirs)

# Windows: root layout.
# macOS: bundle root layout.
# Linux: bin layout, exactly like GenyConnect.
if(WIN32)
    set(RAAD_RUNTIME_DEST ".")
else()
    set(RAAD_RUNTIME_DEST "${CMAKE_INSTALL_BINDIR}")
endif()

install(TARGETS ${APP_NAME}
    CONFIGURATIONS Release RelWithDebInfo
    BUNDLE DESTINATION .
    RUNTIME DESTINATION "${RAAD_RUNTIME_DEST}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
)

if(APPLE)
    install(TARGETS RaadUpdaterHelper
        CONFIGURATIONS Release RelWithDebInfo
        RUNTIME DESTINATION "${RAAD_FINAL_OUTPUT_NAME}.app/Contents/MacOS"
    )
else()
    install(TARGETS RaadUpdaterHelper
        CONFIGURATIONS Release RelWithDebInfo
        RUNTIME DESTINATION "${RAAD_RUNTIME_DEST}"
    )
endif()

if(UNIX AND NOT APPLE)
    if(EXISTS "${RAAD_LINUX_ICON_PNG}")
        install(FILES "${RAAD_LINUX_ICON_PNG}"
            DESTINATION "share/icons/hicolor/512x512/apps"
            RENAME "raad.png"
        )
    endif()
endif()

# -----------------------------------------------------------------------------
# Linux deploy
# -----------------------------------------------------------------------------
if(UNIX AND NOT APPLE AND RAAD_LINUX_INSTALL_DEPLOY)
    set(raad_linux_deploy_args "")

    if(NOT RAAD_LINUX_DEPLOY_TRANSLATIONS)
        list(APPEND raad_linux_deploy_args NO_TRANSLATIONS)
    endif()

    qt_generate_deploy_qml_app_script(
        TARGET ${APP_NAME}
        OUTPUT_SCRIPT RAAD_LINUX_DEPLOY_SCRIPT
        NO_UNSUPPORTED_PLATFORM_ERROR
        ${raad_linux_deploy_args}
    )

    install(SCRIPT ${RAAD_LINUX_DEPLOY_SCRIPT})
endif()

# -----------------------------------------------------------------------------
# Windows deploy
# -----------------------------------------------------------------------------
if(WIN32 AND RAAD_WINDOWS_INSTALL_DEPLOY)
    find_program(RAAD_WINDEPLOYQT_EXECUTABLE
        NAMES windeployqt
        HINTS
            "$ENV{QTDIR}/bin"
            "${Qt6_DIR}/../../../bin"
            "C:/Qt/*/*/bin"
            "$ENV{QT_DIR}/bin"
            "$ENV{Qt6_ROOT}/bin"
            "$ENV{QT_ROOT}/bin"
    )

    if(NOT RAAD_WINDEPLOYQT_EXECUTABLE)
        message(FATAL_ERROR "windeployqt not found. Set QTDIR or make sure Qt bin is in PATH.")
    endif()

    install(CODE
        "message(STATUS \"[deploy] Running windeployqt for Raad (install tree, root layout)\")\n
         set(_root \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}\")\n
         file(TO_CMAKE_PATH \"\${_root}\" _root)\n
         set(_exe \"\${_root}/${RAAD_FINAL_OUTPUT_NAME}.exe\")\n
         if(NOT EXISTS \"\${_exe}\")\n
           message(FATAL_ERROR \"[deploy] Installed exe not found: \${_exe}\")\n
         endif()\n
         set(_args \"\${_exe}\" \"--qmldir\" \"${CMAKE_CURRENT_SOURCE_DIR}\" \"--dir\" \"\${_root}\" \"--verbose\" \"2\" \"--release\")\n
         if(${RAAD_WINDEPLOYQT_COMPILER_RUNTIME})\n
           list(APPEND _args \"--compiler-runtime\")\n
         endif()\n
         if(${RAAD_WINDEPLOYQT_TRANSLATIONS})\n
           list(APPEND _args \"--translations\")\n
         else()\n
           list(APPEND _args \"--no-translations\")\n
         endif()\n
         execute_process(\n
           COMMAND \"${RAAD_WINDEPLOYQT_EXECUTABLE}\" \${_args}\n
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

set(RAAD_DOC_README_SRC "")
set(RAAD_DOC_LICENSE_SRC "")

if(RAAD_BUNDLE_DOCS)
    foreach(raad_doc_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/README.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/README.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/README"
    )
        if(EXISTS "${raad_doc_candidate}")
            set(RAAD_DOC_README_SRC "${raad_doc_candidate}")
            break()
        endif()
    endforeach()

    foreach(raad_doc_candidate
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
        "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.md"
        "${CMAKE_CURRENT_SOURCE_DIR}/COPYING"
    )
        if(EXISTS "${raad_doc_candidate}")
            set(RAAD_DOC_LICENSE_SRC "${raad_doc_candidate}")
            break()
        endif()
    endforeach()

    if(RAAD_DOC_README_SRC)
        set(RAAD_DOC_README_TXT "${CMAKE_BINARY_DIR}/NSIS_README.txt")
        configure_file("${RAAD_DOC_README_SRC}" "${RAAD_DOC_README_TXT}" COPYONLY)
        install(FILES "${RAAD_DOC_README_TXT}" DESTINATION "." RENAME "README.txt")
    else()
        message(WARNING "No README file found to bundle.")
    endif()

    if(RAAD_DOC_LICENSE_SRC)
        set(RAAD_DOC_LICENSE_TXT "${CMAKE_BINARY_DIR}/NSIS_LICENSE.txt")
        configure_file("${RAAD_DOC_LICENSE_SRC}" "${RAAD_DOC_LICENSE_TXT}" COPYONLY)
        install(FILES "${RAAD_DOC_LICENSE_TXT}" DESTINATION "." RENAME "LICENSE.txt")
    else()
        message(WARNING "No LICENSE file found to bundle.")
    endif()
endif()

# -----------------------------------------------------------------------------
# CPack / Installer Packaging
# -----------------------------------------------------------------------------
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VENDOR "${RAAD_VENDOR}")
set(CPACK_PACKAGE_CONTACT "${RAAD_PACKAGE_CONTACT}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${RAAD_PACKAGE_SUMMARY}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")

set(CPACK_OUTPUT_FILE_PREFIX "${RAAD_FINAL_DIR}")
set(CPACK_PACKAGE_FILE_NAME "${PROJECT_NAME}-${PROJECT_VERSION}-${RAAD_OS}-${RAAD_ARCH}")
set(CPACK_PACKAGING_INSTALL_PREFIX "/")

if(WIN32)
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_NSIS_DISPLAY_NAME "${APP_NAME}")
    set(CPACK_NSIS_PACKAGE_NAME "${APP_NAME}")
    set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "${APP_NAME}")

    set(RAAD_EXE_NAME "${RAAD_FINAL_OUTPUT_NAME}.exe")

    set(CPACK_NSIS_MENU_LINKS
        "${RAAD_EXE_NAME}" "${APP_NAME}"
    )

    set(CPACK_NSIS_CREATE_ICONS_EXTRA
        "CreateShortCut \\\"$DESKTOP\\\\${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\${RAAD_EXE_NAME}\\\"\n"
        "CreateDirectory \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\"\n"
        "CreateShortCut \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\${APP_NAME}.lnk\\\" \\\"$INSTDIR\\\\${RAAD_EXE_NAME}\\\"\n"
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

    set(RAAD_DMG_BACKGROUND_IMAGE "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/background.png")
    set(RAAD_DMG_DS_STORE_SETUP_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/properties/macOS/dmg-setup.scpt")

    set(CPACK_DMG_VOLUME_NAME "${APP_NAME} ${PROJECT_VERSION}")
    set(CPACK_DMG_FORMAT "UDZO")

    if(EXISTS "${RAAD_DMG_BACKGROUND_IMAGE}")
        set(CPACK_DMG_BACKGROUND_IMAGE "${RAAD_DMG_BACKGROUND_IMAGE}")
    endif()

    if(EXISTS "${RAAD_DMG_DS_STORE_SETUP_SCRIPT}")
        set(CPACK_DMG_DS_STORE_SETUP_SCRIPT "${RAAD_DMG_DS_STORE_SETUP_SCRIPT}")
    endif()

else()
    set(CPACK_GENERATOR "TGZ")
endif()

include(CPack)

message(STATUS "Build dir: ${CMAKE_BINARY_DIR}")
message(STATUS "Packages dir: ${RAAD_FINAL_DIR}")
message(STATUS "Packaging: run cpack. For multi-config generators use: cpack -C Release")