cmake_minimum_required(VERSION 3.16)

project(plasma-networkmanagement)

set(PROJECT_VERSION "6.7.80")

set(PROJECT_DEP_VERSION "6.3.4")
set(QT_MIN_VERSION "6.8.0")
set(KF6_MIN_VERSION "6.8.0")
set(KDE_COMPILERSETTINGS_LEVEL "5.82")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

################# set KDE specific information #################

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(KDEClangFormat)
include(KDEGitCommitHooks)
include(ECMQtDeclareLoggingCategory)
include(ECMDeprecationSettings)

include(FeatureSummary)
include(GenerateExportHeader)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    DBus
    Gui
    Network
    Widgets
    Xml
)
find_package(Qt6Keychain 0.15.0 CONFIG REQUIRED)

find_package(Qca-qt6 REQUIRED)

find_package(PkgConfig REQUIRED)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED
    ColorScheme
    Completion
    CoreAddons
    KIO
    I18n
    NetworkManagerQt
    Notifications
    Solid
    WidgetsAddons
    ModemManagerQt
)

find_package(OpenSSL REQUIRED)

pkg_check_modules(NETWORKMANAGER IMPORTED_TARGET libnm>1.4.0 REQUIRED)
pkg_check_modules(MOBILEBROADBANDPROVIDERINFO mobile-broadband-provider-info)
pkg_get_variable(BROADBANDPROVIDER_DATABASE mobile-broadband-provider-info database)

ecm_set_disabled_deprecation_versions(QT 5.15
    KF 6.4.0
)

add_definitions(-DQT_NO_URL_CAST_FROM_STRING)

remove_definitions(-DQT_NO_CAST_FROM_ASCII -DQT_NO_CAST_FROM_BYTEARRAY)
find_package(KF6Wallet REQUIRED)
add_subdirectory(plasma-nm/libs/editor)

install(FILES org.kde.vpnimport.desktop DESTINATION ${KDE_INSTALL_APPDIR})

# add clang-format target for all our real source files
file(GLOB_RECURSE ALL_CLANG_FORMAT_SOURCE_FILES *.cpp *.h)
kde_clang_format(${ALL_CLANG_FORMAT_SOURCE_FILES})
kde_configure_git_pre_commit_hook(CHECKS CLANG_FORMAT)

ecm_qt_install_logging_categories(
        EXPORT PLASMANM
        FILE plasma-nm.categories
        DESTINATION ${KDE_INSTALL_LOGGINGCATEGORIESDIR}
        )

ki18n_install(po)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)


add_library(plasmanetworkmanagement_anet-vpn_ui MODULE)

target_sources(plasmanetworkmanagement_anet-vpn_ui PRIVATE
				anet-vpn.cpp
				anet-vpn_widget.cpp
)

target_link_libraries(plasmanetworkmanagement_anet-vpn_ui 
    plasmanm_editor
    KF6::CoreAddons
    KF6::I18n
    KF6::WidgetsAddons
)

