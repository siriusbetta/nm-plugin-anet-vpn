#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Запустите скрипт от имени root: sudo ./uninstall_anet.sh"
  exit 1
fi

echo "Начало удаления nm-plugin-anet-vpn"

echo "Остановка соединения и процессов"
nmcli connection down anet-vpn 2>/dev/null || true
nmcli connection delete uuid aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee 2>/dev/null || true
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
rm -f /usr/local/libexec/nm-anet-auth-dialog

echo "Удаление Anet client"
rm -f /usr/local/bin/anet-client
rm -f /usr/local/etc/client.toml
rm -f /usr/local/etc/client.toml.bak

if [ -f /etc/os-release ]; then
	source /etc/os-release
	echo "Дистрибутив: $NAME"
else
	echo "Файл /ect/os-release не найден"
fi

case "$ID" in
  debian|ubuntu|linuxmint)
    QT_UI_CANDIDATES="/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn /usr/lib/qt6/plugins/plasma/network/vpn"
    ;;
  arch|manjaro)
    QT_UI_CANDIDATES="/usr/lib/qt6/plugins/plasma/network/vpn"
    ;;
  *)
    QT_UI_CANDIDATES=""
    ;;
esac

DE_NAME=""
DESKTOP_VALUE="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-}}}"
DE=$(printf '%s' "$DESKTOP_VALUE" | tr '[:upper:]' '[:lower:]')

case "$DE" in
    *unity*)
        echo "Запущен Unity"
	DE_NAME="unity"
        ;;
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
        echo "Окружение не определено или используется консоль: $DESKTOP_VALUE"
        ;;
esac

echo "Удаление UI библиотеки"
for UI_DIR in $QT_UI_CANDIDATES; do
  rm -f "$UI_DIR/plasmanetworkmanagement_anet-vpn_ui.so"
done

NM_LIBDIR=""
if command -v pkg-config >/dev/null 2>&1; then
  NM_LIBDIR=$(pkg-config --variable=libdir libnm 2>/dev/null || true)
fi

for NM_UI_DIR in \
  "${NM_LIBDIR:+$NM_LIBDIR/NetworkManager}" \
  /usr/lib/x86_64-linux-gnu/NetworkManager \
  /usr/lib/NetworkManager
do
  if [ -n "$NM_UI_DIR" ]; then
    rm -f "$NM_UI_DIR/libnm-vpn-plugin-anet.so"
    rm -f "$NM_UI_DIR/libnm-vpn-plugin-anet-editor.so"
    rm -f "$NM_UI_DIR/libnm-gtk4-vpn-plugin-anet-editor.so"
  fi
done

echo "Перезагрузка конфигурации DBus"
dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig

echo "Перезапуск NetworkManager"
systemctl restart NetworkManager
nmcli connection reload

echo "Удаление завершено"
