#!/bin/bash
# Скрипт установки nm-plugin-anet-vpn
# Запускать из корневой директории репозитория с правами root: sudo ./install.sh

set -e

# 1. Проверка прав суперпользователя
if [ "$EUID" -ne 0 ]; then
    echo "❌ Пожалуйста, запустите этот скрипт от имени root (используйте sudo)."
    exit 1
fi

echo "🚀 Начало установки nm-helloworldvpn-plugin..."

# 2. Установка зависимостей (Python D-Bus и GI)
echo "📦 Проверка и установка зависимостей..."
if command -v apt-get &> /dev/null; then
    apt-get update -qq
    apt-get install -y python3-dbus python3-gi
elif command -v pacman &> /dev/null; then
    pacman -Sy --noconfirm python-dbus python-gobject
else
    echo "⚠️ Менеджер пакетов не распознан. Убедитесь, что пакеты python3-dbus и python3-gi (или их аналоги) установлены вручную."
fi

# 3. Установка файлов конфигурации и службы
echo "📁 Копирование файлов конфигурации..."

cp ./config/anet-vpn.nmconnection /etc/NetworkManager/system-connections/anet-vpn.nmconnection 2>/dev/null || \
cp ./anet-vpn.nmconnection /etc/NetworkManager/system-connections/anet-vpn.nmconnection
chmod 600 /etc/NetworkManager/system-connections/anet-vpn.nmconnection
chown root:root /etc/NetworkManager/system-connections/anet-vpn.nmconnection

cp ./config/anet.name /usr/lib/NetworkManager/VPN/anet.name 2>/dev/null || \
cp ./anet.name /usr/lib/NetworkManager/VPN/anet.name

cp ./config/org.freedesktop.NetworkManager.anet.service /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service 2>/dev/null || \
cp ./org.freedesktop.NetworkManager.anet.service /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service

cp ./config/org.freedesktop.NetworkManager.anet.conf /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf 2>/dev/null || \
cp ./org.freedesktop.NetworkManager.anet.conf /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf

# 4. Перезагрузка конфигурации D-Bus
echo "🔄 Перезагрузка конфигурации D-Bus..."
dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig

# 5. Установка DBus скрипта
echo "📁 Копирование DBus скрипта..."
cp ./src/anet-dbus.py /usr/local/libexec/anet-dbus.py 2>/dev/null || \
cp ./anet-dbus.py /usr/local/libexec/anet-dbus.py
chmod +x /usr/local/libexec/anet-dbus.py
chown root:root /usr/local/libexec/anet-dbus.py

# 6. Определение пути установки UI библиотеки (multiarch для Debian/Ubuntu или стандартный для Arch)
UI_DIR=""
if [ -d "/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/" ]; then
    UI_DIR="/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/"
elif [ -d "/usr/lib/qt6/plugins/plasma/network/vpn/" ]; then
    UI_DIR="/usr/lib/qt6/plugins/plasma/network/vpn/"
fi

# 7. Установка UI библиотеки (Qt6)
echo "🎨 Установка UI библиотеки..."
if [ -f "./nm-plugin-anet-qt6-ui/build/bin/plasmanetworkmanagement_anet-vpn_ui.so" ]; then
    if [ -n "$UI_DIR" ]; then
        cp ./nm-plugin-anet-qt6-ui/build/bin/plasmanetworkmanagement_anet-vpn_ui.so "$UI_DIR"
        chmod 755 "$UI_DIR/plasmanetworkmanagement_anet-vpn_ui.so"
        echo "✅ UI библиотека для Qt6 успешно установлена в $UI_DIR"
    else
        echo "⚠️ Не удалось определить директорию для установки UI библиотеки."
        echo "💡 Создайте директорию вручную и скопируйте файл plasmanetworkmanagement_anet-vpn_ui.so"
    fi
else
    echo "⚠️ Файл UI библиотеки (plasmanetworkmanagement_anet-vpn_ui.so) не найден."
    echo "💡 Возможно, вам нужно сначала скомпилировать его (см. раздел 'build lib for plugin' в README)."
fi

# 8. Перезапуск NetworkManager и перезагрузка соединений
echo "🔄 Перезапуск NetworkManager..."
systemctl restart NetworkManager
nmcli connection reload

echo "✅ Установка успешно завершена!"
echo "💡 Для подключения используйте команду: nmcli connection up anet-vpn"
