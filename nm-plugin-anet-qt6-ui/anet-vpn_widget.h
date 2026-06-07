#pragma once

#include <NetworkManagerQt/VpnSetting>
#include <NetworkManagerQt/ConnectionSettings>
#include <QWidget>
#include <QLineEdit>
#include <QPushButton>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QFileDialog>
#include <QMessageBox>
#include <QFileInfo> 
#include "vpnuiplugin.h"

class AnetVpnWidget : public SettingWidget
{
    Q_OBJECT

public:
    explicit AnetVpnWidget(const NetworkManager::VpnSetting::Ptr &setting, QWidget *parent = nullptr);

    void loadConfig(const NetworkManager::Setting::Ptr &setting) override;
    void loadSecrets(const NetworkManager::Setting::Ptr &setting) override;
    virtual QVariantMap setting() const override;

private slots:
    void onBrowseClicked(); 
        
    void onEditClicked(); 

private:
    NetworkManager::VpnSetting::Ptr m_setting;
    QLineEdit* lineEditPath;
    QPushButton* buttonBrowse;
    QPushButton* buttonEdit;
};
