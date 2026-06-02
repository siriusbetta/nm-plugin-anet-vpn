
#ifndef PLASMA_NM_ANET_VPN_H 
#define PLASMA_NM_ANET_VPN_H 

#include "vpnuiplugin.h"

#include <QVariant>

class Q_DECL_EXPORT AnetVpnUiPlugin : public VpnUiPlugin
{
    Q_OBJECT
public:
    explicit AnetVpnUiPlugin(QObject *parent = nullptr, const QVariantList & = QVariantList());
    ~AnetVpnUiPlugin() override;
    SettingWidget *widget(const NetworkManager::VpnSetting::Ptr &setting, QWidget *parent) override;
    SettingWidget *askUser(const NetworkManager::VpnSetting::Ptr &setting, const QStringList &hints, QWidget *parent) override;

    QString suggestedFileName(const NetworkManager::ConnectionSettings::Ptr &connection) const override;
};

#endif //  PLASMA_NM_ANET_VPN_H
