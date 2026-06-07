#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Запустите скрипт от имени root: sudo ./uninstall_anet.sh"
  exit 1
fi

echo "Начало удаления nm-plugin-anet-vpn"

echo "Остановка соединения и процессов"
nmcli connection down anet-vpn 2>/dev/null || true
pkill -f anet-dbus.py 2>/dev/null || true
pkill -f anet-client 2>/dev/null || true
rm -f /tmp/anet-vpn.log
ip tuntap del dev anet-vpn0 mode tun 2>/dev/null || true

echo "Удаление файлов NetworkManager и DBus"
rm -f /etc/NetworkManager/system-connections/anet-vpn.nmconnection
rm -f /usr/lib/NetworkManager/VPN/anet.name
rm -f /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service
rm -f /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf
rm -f /usr/local/libexec/anet-dbus.py

echo "Удаление Anet client"
rm -f /usr/local/bin/anet-client
rm -f /usr/local/etc/client.toml
rm -f /usr/local/etc/client.toml.bak

UI_DIR=""
if [ -f /etc/os-release ]; then
	source /etc/os-release
	echo "Дистрибутив: $NAME"
else
	echo "Файл /ect/os-release не найден"
fi

OS_NAME="$ID"

if [ "$ID" = "arch" ] || [ "$ID" = "manjaro" ]; then
	OS_NAME="arch"
fi

DE_NAME=""
DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

case "$DE" in
    *gnome*)
        echo "Запущен GNOME"
	DE_NAME="gnome"
        ;;
    *kde*|*plasma*)
        echo "Запущен KDE Plasma"
	DE_NAME="kde-plasma"
        ;;
    *xfce*)
        echo "Запущен XFCE"
	DE_NAME="xfce"
        ;;
    *mate*)
        echo "Запущен MATE"
	DE_NAME="mate"
        ;;
    *cinnamon*)
        echo "Запущен Cinnamon"
	DE_NAME="cinnamon"
        ;;
    *)
        echo "Окружение не определено или используется консоль: $XDG_CURRENT_DESKTOP"
        ;;
esac

if [ "$OS_NAME"=="debian" ] && [ "$DE_NAME"=="kde-plasma" ]; then
	if [ -d "/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/" ]; then
	  UI_DIR="/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/"
	fi
fi

if [ "$OS_NAME"=="arch" ] && [ "$DE_NAME"=="kde-plasma" ]; then
	if [ -d "/usr/lib/qt6/plugins/plasma/network/vpn/" ]; then
	  UI_DIR="/usr/lib/qt6/plugins/plasma/network/vpn/"
	fi
fi
echo "Удаление UI библиотеки"
rm -f "$UI_DIR/plasmanetworkmanagement_anet-vpn_ui.so"

echo "Перезагрузка конфигурации DBus"
dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig

echo "Перезапуск NetworkManager"
systemctl restart NetworkManager
nmcli connection reload

echo "Удаление завершено"
