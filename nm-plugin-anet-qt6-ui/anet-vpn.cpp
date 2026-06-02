
#include "anet-vpn.h"
#include "anet-vpn_widget.h"

#include <KPluginFactory>

K_PLUGIN_CLASS_WITH_JSON(AnetVpnUiPlugin, "plasmanetworkmanagement_anet-vpn_ui.json")
 

AnetVpnUiPlugin::AnetVpnUiPlugin(QObject *parent, const QVariantList &)
    : VpnUiPlugin(parent)
{
}

AnetVpnUiPlugin::~AnetVpnUiPlugin() = default;

SettingWidget *AnetVpnUiPlugin::widget(const NetworkManager::VpnSetting::Ptr &setting, QWidget *parent)
{
    return new AnetVpnWidget(setting, parent);
}

SettingWidget *AnetVpnUiPlugin::askUser(const NetworkManager::VpnSetting::Ptr &setting, const QStringList &hints, QWidget *parent)
{
	Q_UNUSED(setting);
	Q_UNUSED(hints);
	Q_UNUSED(parent);
    return NULL;
}

QString AnetVpnUiPlugin::suggestedFileName(const NetworkManager::ConnectionSettings::Ptr &connection) const
{
    Q_UNUSED(connection);
    return {};
}

#include "anet-vpn.moc"

