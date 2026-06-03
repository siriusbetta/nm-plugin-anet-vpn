#include "anet-vpn_widget.h"
#include <QDesktopServices>
#include <QUrl>

#include <QVBoxLayout>
#include <QLabel>

AnetVpnWidget::AnetVpnWidget(const NetworkManager::VpnSetting::Ptr &setting, QWidget *parent)
    : SettingWidget(setting, parent)
    , m_setting(setting)
{

    lineEditPath = new QLineEdit(this);
    lineEditPath->setReadOnly(true);
    lineEditPath->setPlaceholderText("Путь к файлу не выбран");
    lineEditPath->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);

    buttonBrowse = new QPushButton("Выбрать файл", this);
    buttonShowName = new QPushButton("Показать имя файла", this);

    auto* pathLayout = new QHBoxLayout;
    pathLayout->addWidget(lineEditPath);
    pathLayout->addWidget(buttonBrowse);

    auto* mainLayout = new QVBoxLayout(this);
    mainLayout->addLayout(pathLayout);
    mainLayout->addWidget(buttonShowName);
    mainLayout->setContentsMargins(12, 12, 12, 12);
    mainLayout->setSpacing(10);

    connect(buttonBrowse, &QPushButton::clicked, this, &AnetVpnWidget::onBrowseClicked);
    connect(buttonShowName, &QPushButton::clicked, this, &AnetVpnWidget::onShowNameClicked);

    setLayout(mainLayout);
    setWindowTitle("Выбор файла");
    if (setting && !setting->isNull()) {
	    loadConfig(setting);
    }
}

void AnetVpnWidget::loadConfig(const NetworkManager::Setting::Ptr &setting)
{
    Q_UNUSED(setting);
    const NMStringMap data = m_setting->data();

    QString savedPath = data.value(QStringLiteral("config"));
    lineEditPath->setText(savedPath);
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
    QString pathToSave = lineEditPath->text();
    data.insert("config", pathToSave);
    setting.setData(data);

    return setting.toMap(); // Возвращаем правильный тип Ptr!
}

void AnetVpnWidget::onBrowseClicked() {
	QString filePath = QFileDialog::getOpenFileName(this, "Выберите файл");
	if (!filePath.isEmpty()) {
	    lineEditPath->setText(filePath);
	    settingChanged();
	}
}

void AnetVpnWidget::onShowNameClicked() {
	QString filePath = lineEditPath->text();
	QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
}

