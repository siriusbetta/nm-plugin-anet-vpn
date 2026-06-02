#include "anet-vpn_widget.h"

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

}

void AnetVpnWidget::loadConfig(const NetworkManager::Setting::Ptr &setting)
{
    m_setting = setting.staticCast<NetworkManager::VpnSetting>();
}

void AnetVpnWidget::loadSecrets(const NetworkManager::Setting::Ptr &setting)
{
    Q_UNUSED(setting);
}

QVariantMap AnetVpnWidget::setting() const
{
    QVariantMap result;

    QVariantMap data;
    data.insert(QStringLiteral("gateway"), QStringLiteral("127.0.0.1"));

    result.insert(QStringLiteral("service-type"), QStringLiteral("org.freedesktop.NetworkManager.helloworld"));
    result.insert(QStringLiteral("data"), data);

    return result;
}

void AnetVpnWidget::onBrowseClicked() {
	QString filePath = QFileDialog::getOpenFileName(this, "Выберите файл");
	if (!filePath.isEmpty()) {
	    lineEditPath->setText(filePath);
	}
}

void AnetVpnWidget::onShowNameClicked() {
	QString filePath = lineEditPath->text();
	if (filePath.isEmpty()) {
	    QMessageBox::information(this, "Информация", "Сначала выберите файл.");
	    return;
	}
	QString fileName = QFileInfo(filePath).fileName();
	QMessageBox::information(this, "Имя файла", QString("Выбран файл:\n%1").arg(fileName));
}

