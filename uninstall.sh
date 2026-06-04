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

echo "Удаление UI библиотеки"
rm -f /usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/plasmanetworkmanagement_anet-vpn_ui.so
rm -f /usr/lib/qt6/plugins/plasma/network/vpn/plasmanetworkmanagement_anet-vpn_ui.so

echo "Перезагрузка конфигурации DBus"
dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig

echo "Перезапуск NetworkManager"
systemctl restart NetworkManager
nmcli connection reload

echo "Удаление завершено"
