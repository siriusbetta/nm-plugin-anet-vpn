#include "anet-vpn_widget.h"
#include <QDesktopServices>
#include <QUrl>

#include <QVBoxLayout>
#include <QLabel>

AnetVpnWidget::AnetVpnWidget(const NetworkManager::VpnSetting::Ptr &setting, QWidget *parent)
    : SettingWidget(setting, parent)
    , m_setting(setting)
{

    m_lineEditPath = new QLineEdit(this);
    m_lineEditPath->setReadOnly(true);
    m_lineEditPath->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);

    m_buttonBrowse = new QPushButton("Browse...", this);
    m_buttonEdit = new QPushButton("Edit...", this);

    auto* pathLayout = new QHBoxLayout;
    pathLayout->addWidget(m_lineEditPath);
    pathLayout->addWidget(m_buttonBrowse);
    pathLayout->addWidget(m_buttonEdit);

    auto* mainLayout = new QVBoxLayout(this);
    mainLayout->addWidget(new QLabel("Please select a configuration file:", this));
    mainLayout->addLayout(pathLayout);
    mainLayout->setContentsMargins(12, 12, 12, 12);
    mainLayout->setSpacing(10);

    connect(m_buttonBrowse, &QPushButton::clicked, this, &AnetVpnWidget::onBrowseClicked);
    connect(m_buttonEdit, &QPushButton::clicked, this, &AnetVpnWidget::onEditClicked);

    setLayout(mainLayout);
    setWindowTitle("Select Configuration File");
    if (setting && !setting->isNull()) {
	    loadConfig(setting);
    }
}

void AnetVpnWidget::loadConfig(const NetworkManager::Setting::Ptr &setting)
{
    Q_UNUSED(setting);
    const NMStringMap data = m_setting->data();

    QString savedPath = data.value(QStringLiteral("config"));
    m_lineEditPath->setText(savedPath);
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
	    settingChanged();
	}
}

void AnetVpnWidget::onEditClicked() {
	QString filePath = m_lineEditPath->text();
	QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
}
