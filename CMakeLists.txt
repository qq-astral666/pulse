cmake_minimum_required(VERSION 3.21)

project(Pulse
    VERSION 1.0.0
    DESCRIPTION "Menu-bar system monitor for macOS"
    LANGUAGES CXX)

if(APPLE)
    enable_language(OBJCXX)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(PULSE_BUILD_TESTS "Build unit tests" ON)

find_package(Qt6 6.9 REQUIRED COMPONENTS Core Gui Quick)
qt_standard_project_setup(REQUIRES 6.9)

# --------------------------------------------------------------------------
# Core: math + formatting, no UI, no OS calls -> unit-tested.
# --------------------------------------------------------------------------
qt_add_library(pulse_core STATIC
    src/core/Metrics.h
    src/core/Metrics.cpp
)
target_include_directories(pulse_core PUBLIC src/core)
target_link_libraries(pulse_core PUBLIC Qt6::Core)

# --------------------------------------------------------------------------
# Application
# --------------------------------------------------------------------------
qt_add_executable(Pulse MACOSX_BUNDLE
    src/main.cpp
    src/app/AppController.h
    src/app/AppController.cpp
    src/app/SystemMonitor.h
    src/app/SystemMonitor.cpp
    src/app/MenuBarRenderer.h
    src/app/MenuBarRenderer.cpp
    src/app/ProcessIcons.h
    src/app/ProcessIcons.cpp
    src/platform/Probe.h
    src/platform/Native.h
)
target_include_directories(Pulse PRIVATE src/app src/platform)
target_compile_definitions(Pulse PRIVATE PROJECT_VERSION_STRING="${PROJECT_VERSION}")

if(APPLE)
    target_sources(Pulse PRIVATE src/platform/Probe_mac.mm src/platform/Native_mac.mm)
    set_source_files_properties(src/platform/Probe_mac.mm src/platform/Native_mac.mm
        PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
    target_link_libraries(Pulse PRIVATE
        "-framework AppKit"
        "-framework IOKit"
        "-framework ServiceManagement")
else()
    target_sources(Pulse PRIVATE src/platform/Platform_stub.cpp)
endif()

set(PULSE_QML_FILES
    qml/Main.qml
    qml/Theme.qml
    qml/Icon.qml
    qml/Card.qml
    qml/Chip.qml
    qml/Dashboard.qml
    qml/SettingsView.qml
    qml/Sparkline.qml
    qml/RingGauge.qml
    qml/SegmentBar.qml
    qml/CoreBars.qml
    qml/LegendRow.qml
    qml/ProcessRow.qml
    qml/Toggle.qml
    qml/Segmented.qml
    qml/SettingRow.qml
    qml/PillButton.qml
)

# Flatten qml/ into the module root next to the generated qmldir.
foreach(qml_file IN LISTS PULSE_QML_FILES)
    get_filename_component(qml_name "${qml_file}" NAME)
    set_source_files_properties("${qml_file}" PROPERTIES QT_RESOURCE_ALIAS "${qml_name}")
endforeach()
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(Pulse
    URI Pulse
    VERSION 1.0
    QML_FILES ${PULSE_QML_FILES}
)

target_link_libraries(Pulse PRIVATE pulse_core Qt6::Gui Qt6::Quick)

set_target_properties(Pulse PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Info.plist.in"
    MACOSX_BUNDLE_GUI_IDENTIFIER "app.pulsebar.Pulse"
    MACOSX_BUNDLE_BUNDLE_NAME "Pulse"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}"
)

# resources/AppIcon.icns is generated from AppIcon.png by scripts/package.sh
# (iconutil exists only on macOS).
if(APPLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/resources/AppIcon.icns")
    set(app_icon "${CMAKE_CURRENT_SOURCE_DIR}/resources/AppIcon.icns")
    set_source_files_properties(${app_icon} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    target_sources(Pulse PRIVATE ${app_icon})
    set_target_properties(Pulse PROPERTIES MACOSX_BUNDLE_ICON_FILE "AppIcon.icns")
endif()

# --------------------------------------------------------------------------
# Tests
# --------------------------------------------------------------------------
if(PULSE_BUILD_TESTS)
    enable_testing()
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(tst_metrics tests/tst_metrics.cpp)
    target_link_libraries(tst_metrics PRIVATE pulse_core Qt6::Test)
    add_test(NAME metrics COMMAND tst_metrics)
endif()
