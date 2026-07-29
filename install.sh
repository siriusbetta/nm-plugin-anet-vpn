#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Запустите скрипт от имени root: sudo ./install_anet.sh"
  exit 1
fi

echo "Начало установки nm-plugin-anet-vpn"

echo "Установка зависимостей"
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y python3-dbus python3-gi unzip
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm python-dbus python-gobject unzip
else
  echo "Менеджер пакетов не распознан"
  echo "Установите зависимости вручную: python3-dbus, python3-gi, unzip"
fi

echo "Поиск архива Anet client"
CLIENT_ZIP=$(ls client-linux-amd64_*.zip 2>/dev/null | head -n 1)

if [ -z "$CLIENT_ZIP" ]; then
  echo "Архив client-linux-amd64_*.zip не найден в текущей директории"
  read -r -p "Введите полный путь к архиву или нажмите Enter для отмены: " MANUAL_ZIP

  if [ -n "$MANUAL_ZIP" ] && [ -f "$MANUAL_ZIP" ]; then
    CLIENT_ZIP="$MANUAL_ZIP"
  else
    echo "Архив не указан или не найден"
    exit 1
  fi
fi

echo "Найден архив: $CLIENT_ZIP"

TEMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "Распаковка архива"
unzip -q "$CLIENT_ZIP" -d "$TEMP_DIR"

CLIENT_BIN="$TEMP_DIR/client-linux-amd64/anet-client"
CLIENT_CONF="$TEMP_DIR/client-linux-amd64/client.toml"

if [ ! -f "$CLIENT_BIN" ] || [ ! -f "$CLIENT_CONF" ]; then
  echo "В архиве не найдены client-linux-amd64/anet-client или client-linux-amd64/client.toml"
  exit 1
fi

echo "Установка Anet client"
mkdir -p /usr/local/bin
mkdir -p /usr/local/etc

CONFIG_OWNER="${SUDO_USER:-root}"
if ! id "$CONFIG_OWNER" >/dev/null 2>&1; then
  CONFIG_OWNER=root
fi
CONFIG_GROUP=$(id -gn "$CONFIG_OWNER")

cp "$CLIENT_BIN" /usr/local/bin/anet-client
chmod 755 /usr/local/bin/anet-client
chown root:root /usr/local/bin/anet-client

if [ -f /usr/local/etc/client.toml ]; then
  cp /usr/local/etc/client.toml /usr/local/etc/client.toml.bak
fi

cp "$CLIENT_CONF" /usr/local/etc/client.toml
chmod 600 /usr/local/etc/client.toml
chown "$CONFIG_OWNER:$CONFIG_GROUP" /usr/local/etc/client.toml
echo "Владелец client.toml: $CONFIG_OWNER:$CONFIG_GROUP"

echo "Установка конфигурации NetworkManager"
mkdir -p /etc/NetworkManager/system-connections
mkdir -p /usr/lib/NetworkManager/VPN
mkdir -p /usr/share/dbus-1/system-services
mkdir -p /etc/dbus-1/system.d
mkdir -p /usr/local/libexec

cp ./config/anet-vpn.nmconnection /etc/NetworkManager/system-connections/anet-vpn.nmconnection 2>/dev/null || \
cp ./anet-vpn.nmconnection /etc/NetworkManager/system-connections/anet-vpn.nmconnection

chmod 600 /etc/NetworkManager/system-connections/anet-vpn.nmconnection
chown root:root /etc/NetworkManager/system-connections/anet-vpn.nmconnection

install -m 644 ./config/anet.name /usr/lib/NetworkManager/VPN/anet.name 2>/dev/null || \
install -m 644 ./anet.name /usr/lib/NetworkManager/VPN/anet.name

install -m 644 ./config/org.freedesktop.NetworkManager.anet.service /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service 2>/dev/null || \
install -m 644 ./org.freedesktop.NetworkManager.anet.service /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service

install -m 644 ./config/org.freedesktop.NetworkManager.anet.conf /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf 2>/dev/null || \
install -m 644 ./org.freedesktop.NetworkManager.anet.conf /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf

echo "Установка DBus dispatcher"
cp ./src/anet-dbus.py /usr/local/libexec/anet-dbus.py 2>/dev/null || \
cp ./anet-dbus.py /usr/local/libexec/anet-dbus.py

chmod 755 /usr/local/libexec/anet-dbus.py
chown root:root /usr/local/libexec/anet-dbus.py

echo "Установка GNOME auth-helper"
cp ./config/anet-auth-dialog.py /usr/local/libexec/nm-anet-auth-dialog
chmod 755 /usr/local/libexec/nm-anet-auth-dialog
chown root:root /usr/local/libexec/nm-anet-auth-dialog

echo "Перезагрузка конфигурации DBus"
dbus-send --system --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig

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
UI_MODE=""
DE=$(echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]')

case "$DE" in
    *gnome*)
        echo "Запущен GNOME"
	DE_NAME="gnome"
	UI_MODE="gtk"
        ;;
    *kde*|*plasma*)
        echo "Запущен KDE Plasma"
	DE_NAME="kde-plasma"
	UI_MODE="qt6"
        ;;
    *xfce*)
        echo "Запущен XFCE"
	DE_NAME="xfce"
	UI_MODE="gtk"
        ;;
    *mate*)
        echo "Запущен MATE"
	DE_NAME="mate"
	UI_MODE="gtk"
        ;;
    *cinnamon*)
        echo "Запущен Cinnamon"
	DE_NAME="cinnamon"
	UI_MODE="gtk"
        ;;
    *)
        echo "Окружение не определено или используется консоль: $XDG_CURRENT_DESKTOP"
        ;;
esac

if [ "$OS_NAME" = "debian" ] && [ "$DE_NAME" = "kde-plasma" ]; then
	if [ -d "/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/" ]; then
	  UI_DIR="/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/"
	fi
fi

if [ "$OS_NAME" = "arch" ] && [ "$DE_NAME" = "kde-plasma" ]; then
	if [ -d "/usr/lib/qt6/plugins/plasma/network/vpn/" ]; then
	  UI_DIR="/usr/lib/qt6/plugins/plasma/network/vpn/"
	fi
fi

if [ "$UI_MODE" = "gtk" ]; then
  NM_LIBDIR=$(pkg-config --variable=libdir libnm 2>/dev/null || true)
  NM_UI_DIR=""
  if [ -n "$NM_LIBDIR" ] && [ -d "$NM_LIBDIR/NetworkManager" ]; then
    NM_UI_DIR="$NM_LIBDIR/NetworkManager"
  fi

  for CANDIDATE_DIR in \
    /usr/lib/x86_64-linux-gnu/NetworkManager \
    /usr/lib/NetworkManager
  do
    if [ -z "$NM_UI_DIR" ] && [ -d "$CANDIDATE_DIR" ]; then
      NM_UI_DIR="$CANDIDATE_DIR"
    fi
  done

  if [ -z "$NM_UI_DIR" ]; then
    echo "Каталог GTK NetworkManager не найден" >&2
    exit 1
  fi

  echo "Установка GTK UI библиотек для $DE_NAME"
  install -m 755 ./nm-plugin-anet-gtk-ui/build/libnm-vpn-plugin-anet.so "$NM_UI_DIR/"
  install -m 755 ./nm-plugin-anet-gtk-ui/build/libnm-vpn-plugin-anet-editor.so "$NM_UI_DIR/"
  install -m 755 ./nm-plugin-anet-gtk-ui/build/libnm-gtk4-vpn-plugin-anet-editor.so "$NM_UI_DIR/"
fi

if [ "$DE_NAME" = "kde-plasma" ]; then
  UI_FILE="./nm-plugin-anet-qt6-ui/build/bin/plasmanetworkmanagement_anet-vpn_ui.so"

  if [ -f "$UI_FILE" ]; then
    if [ -n "$UI_DIR" ]; then
      echo "Установка KDE Qt6 UI библиотеки"
      install -m 755 "$UI_FILE" "$UI_DIR/"
    else
      echo "Каталог KDE Qt6 UI не найден; установка UI пропущена" >&2
    fi
  else
    echo "KDE Qt6 UI библиотека не найдена; установка UI пропущена" >&2
  fi
fi

echo "Перезапуск NetworkManager"
systemctl restart NetworkManager
nmcli connection reload

echo "Установка завершена"
echo "Для подключения выполните: nmcli connection up anet-vpn"
