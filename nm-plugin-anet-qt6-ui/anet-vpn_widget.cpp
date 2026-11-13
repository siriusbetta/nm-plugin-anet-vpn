#include "anet-vpn_widget.h"
#include <QDesktopServices>
#include <QUrl>

#include <QVBoxLayout>
#include <QLabel>
#include <NetworkManagerQt/Manager>
#include <NetworkManagerQt/VpnConnection>
#include <NetworkManagerQt/Connection>

AnetVpnWidget::AnetVpnWidget(const NetworkManager::VpnSetting::Ptr &setting, QWidget *parent)
    : SettingWidget(setting, parent)
    , m_setting(setting)
{

    m_lineEditPath = new QLineEdit(this);
    m_lineEditPath->setReadOnly(true);
    m_lineEditPath->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    m_lineEditPath->setMinimumWidth(360);

    m_buttonBrowse = new QPushButton("Browse...", this);
    m_buttonEdit = new QPushButton("Edit...", this);

    auto* pathLayout = new QHBoxLayout;
    pathLayout->addWidget(m_lineEditPath);
    pathLayout->addWidget(m_buttonBrowse);
    pathLayout->addWidget(m_buttonEdit);

    auto* mainLayout = new QVBoxLayout(this);
    mainLayout->addWidget(new QLabel("Please select a configuration file:", this));
    mainLayout->addLayout(pathLayout);
    m_connectedNodeLabel = new QLabel(this);
    m_connectedNodeLabel->setTextFormat(Qt::PlainText);
    mainLayout->addWidget(m_connectedNodeLabel);
    mainLayout->addStretch();
    mainLayout->setContentsMargins(12, 12, 12, 12);
    mainLayout->setSpacing(10);

    connect(m_buttonBrowse, &QPushButton::clicked, this, &AnetVpnWidget::onBrowseClicked);
    connect(m_buttonEdit, &QPushButton::clicked, this, &AnetVpnWidget::onEditClicked);

    setLayout(mainLayout);
    setWindowTitle("Select Configuration File");
    if (setting && !setting->isNull()) {
	    loadConfig(setting);
    }

    connect(NetworkManager::notifier(), &NetworkManager::Notifier::activeConnectionsChanged,
            this, &AnetVpnWidget::refreshConnectedNode);
    connect(NetworkManager::notifier(), &NetworkManager::Notifier::serviceAppeared,
            this, &AnetVpnWidget::refreshConnectedNode);
    connect(NetworkManager::notifier(), &NetworkManager::Notifier::serviceDisappeared,
            this, &AnetVpnWidget::refreshConnectedNode);
    refreshConnectedNode();
}

void AnetVpnWidget::loadConfig(const NetworkManager::Setting::Ptr &setting)
{
    Q_UNUSED(setting);
    const NMStringMap data = m_setting->data();

    QString savedPath = data.value(QStringLiteral("config"));
    m_lineEditPath->setText(savedPath);
    refreshConnectedNode();
    m_lineEditPath->setToolTip(savedPath);
}

void AnetVpnWidget::loadSecrets(const NetworkManager::Setting::Ptr &setting)
{
    Q_UNUSED(setting);
}

QVariantMap AnetVpnWidget::setting() const
{
    NetworkManager::VpnSetting setting;
    setting.setServiceType(QLatin1String("org.freedesktop.NetworkManager.anet"));

    NMStringMap data = m_setting->data();
    QString pathToSave = m_lineEditPath->text();
    data.insert("config", pathToSave);
    setting.setData(data);

    return setting.toMap(); 
}

void AnetVpnWidget::onBrowseClicked() {
	QString filePath = QFileDialog::getOpenFileName(this, "Select Configuration File");
	if (!filePath.isEmpty()) {
	    m_lineEditPath->setText(filePath);
	    refreshConnectedNode();
	    m_lineEditPath->setToolTip(filePath);
	    settingChanged();
	}
}

void AnetVpnWidget::onEditClicked() {
	QString filePath = m_lineEditPath->text();
	QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
}

void AnetVpnWidget::refreshConnectedNode()
{
    const QString configPath = m_lineEditPath->text();
    m_connectedNodeLabel->setText(tr("Connected node: Not connected"));
    if (configPath.isEmpty()) {
        return;
    }

    for (const auto &active : NetworkManager::activeConnections()) {
        const auto vpn = active.dynamicCast<NetworkManager::VpnConnection>();
        if (!vpn) {
            continue;
        }

        connect(vpn.data(), &NetworkManager::VpnConnection::bannerChanged,
                this, &AnetVpnWidget::refreshConnectedNode, Qt::UniqueConnection);
        connect(vpn.data(),
                static_cast<void (NetworkManager::VpnConnection::*)(NetworkManager::VpnConnection::State,
                                                                     NetworkManager::VpnConnection::StateChangeReason)>(
                    &NetworkManager::VpnConnection::stateChanged),
                this, &AnetVpnWidget::refreshConnectedNode, Qt::UniqueConnection);

        const auto connection = vpn->connection();
        if (!connection || !connection->settings()) {
            continue;
        }
        const auto vpnSetting = connection->settings()->setting(NetworkManager::Setting::Vpn)
                                    .dynamicCast<NetworkManager::VpnSetting>();
        if (!vpnSetting || vpnSetting->serviceType() != QLatin1String("org.freedesktop.NetworkManager.anet")
            || vpnSetting->data().value(QStringLiteral("config")) != configPath) {
            continue;
        }

        if (vpn->state() != NetworkManager::VpnConnection::Activated) {
            continue;
        }
        const QString prefix = QStringLiteral("anet VPN connected — ");
        const QString banner = vpn->banner();
        if (banner.startsWith(prefix) && banner.size() > prefix.size()) {
            m_connectedNodeLabel->setText(tr("Connected node: %1").arg(banner.mid(prefix.size())));
        } else {
            m_connectedNodeLabel->setText(tr("Connected node: Unavailable"));
        }
        return;
    }
}
