#!/bin/bash
set -e

DESKTOP_OVERRIDE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --desktop)
      if [ "$#" -lt 2 ]; then
        echo "Для --desktop требуется значение" >&2
        exit 1
      fi
      DESKTOP_OVERRIDE="$2"
      shift 2
      ;;
    --desktop=*)
      DESKTOP_OVERRIDE="${1#*=}"
      shift
      ;;
    *)
      echo "Неизвестный параметр: $1" >&2
      exit 1
      ;;
  esac
done

if [ -n "$DESKTOP_OVERRIDE" ]; then
  case "$DESKTOP_OVERRIDE" in
    gnome|unity|cinnamon|mate|xfce|kde-plasma)
      DESKTOP_VALUE="$DESKTOP_OVERRIDE"
      ;;
    *)
      echo "Неподдерживаемое значение --desktop: $DESKTOP_OVERRIDE" >&2
      echo "Допустимые значения: gnome, unity, cinnamon, mate, xfce, kde-plasma" >&2
      exit 1
      ;;
  esac
else
  DESKTOP_VALUE="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-}}}"
fi

DE=$(printf '%s' "$DESKTOP_VALUE" | tr '[:upper:]' '[:lower:]')

case "$DE" in
  *unity*)
    DE_NAME="unity"
    UI_MODE="gtk"
    ;;
  *gnome*)
    DE_NAME="gnome"
    UI_MODE="gtk"
    ;;
  *cinnamon*)
    DE_NAME="cinnamon"
    UI_MODE="gtk"
    ;;
  *mate*)
    DE_NAME="mate"
    UI_MODE="gtk"
    ;;
  *xfce*)
    DE_NAME="xfce"
    UI_MODE="gtk"
    ;;
  *kde*|*plasma*)
    DE_NAME="kde-plasma"
    UI_MODE="qt6"
    ;;
  *)
    echo "Графическое окружение не определено или не поддерживается: $DESKTOP_VALUE" >&2
    echo "Укажите его явно, например: --desktop cinnamon" >&2
    exit 1
    ;;
esac

if [ "$EUID" -ne 0 ]; then
  echo "Запустите скрипт от имени root: sudo ./install.sh --desktop cinnamon"
  exit 1
fi

echo "Предварительная проверка окружения и файлов"

if [ ! -f /etc/os-release ]; then
  echo "Файл /etc/os-release не найден" >&2
  exit 1
fi

. /etc/os-release
echo "Дистрибутив: $NAME"

case "$ID" in
  debian|ubuntu|linuxmint)
    OS_NAME="debian"
    ;;
  arch|manjaro)
    OS_NAME="arch"
    ;;
  *)
    OS_NAME="$ID"
    ;;
esac

echo "Графическое окружение: $DE_NAME"

if ! command -v ldd >/dev/null 2>&1; then
  echo "Команда ldd не найдена; совместимость UI-библиотек не может быть проверена" >&2
  exit 1
fi

if [ "$UI_MODE" = "gtk" ]; then
  NM_LIBDIR=""
  if command -v pkg-config >/dev/null 2>&1; then
    NM_LIBDIR=$(pkg-config --variable=libdir libnm 2>/dev/null || true)
  fi

  NM_UI_DIR=""
  for CANDIDATE_DIR in \
    "${NM_LIBDIR:+$NM_LIBDIR/NetworkManager}" \
    /usr/lib/x86_64-linux-gnu/NetworkManager \
    /usr/lib/NetworkManager
  do
    if [ -z "$NM_UI_DIR" ] && [ -n "$CANDIDATE_DIR" ] && [ -d "$CANDIDATE_DIR" ]; then
      NM_UI_DIR="$CANDIDATE_DIR"
    fi
  done

  if [ -z "$NM_UI_DIR" ]; then
    echo "Каталог GTK NetworkManager не найден" >&2
    exit 1
  fi

  GTK_PLUGIN_FILE="./nm-plugin-anet-gtk-ui/build/libnm-vpn-plugin-anet.so"
  GTK3_EDITOR_FILE="./nm-plugin-anet-gtk-ui/build/libnm-vpn-plugin-anet-editor.so"
  GTK4_EDITOR_FILE="./nm-plugin-anet-gtk-ui/build/libnm-gtk4-vpn-plugin-anet-editor.so"

  for GTK_LIBRARY in "$GTK_PLUGIN_FILE" "$GTK3_EDITOR_FILE" "$GTK4_EDITOR_FILE"; do
    if [ ! -f "$GTK_LIBRARY" ]; then
      echo "GTK-библиотека не найдена: $GTK_LIBRARY" >&2
      exit 1
    fi

    LDD_OUTPUT=$(ldd -r "$GTK_LIBRARY" 2>&1 || true)
    if printf '%s\n' "$LDD_OUTPUT" | grep -Eq 'not found|undefined symbol'; then
      echo "GTK-библиотека несовместима с текущей системой: $GTK_LIBRARY" >&2
      printf '%s\n' "$LDD_OUTPUT" >&2
      exit 1
    fi
  done
fi

if [ "$UI_MODE" = "qt6" ]; then
  case "$OS_NAME" in
    debian)
      QT_UI_CANDIDATES="/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn /usr/lib/qt6/plugins/plasma/network/vpn"
      ;;
    arch)
      QT_UI_CANDIDATES="/usr/lib/qt6/plugins/plasma/network/vpn"
      ;;
    *)
      echo "Qt6 UI библиотека для дистрибутива $ID не подготовлена" >&2
      exit 1
      ;;
  esac

  UI_DIR=""
  for CANDIDATE_DIR in $QT_UI_CANDIDATES; do
    if [ -z "$UI_DIR" ] && [ -d "$CANDIDATE_DIR" ]; then
      UI_DIR="$CANDIDATE_DIR"
    fi
  done

  if [ -z "$UI_DIR" ]; then
    echo "Каталог KDE Qt6 UI не найден" >&2
    exit 1
  fi

  UI_FILE="./nm-plugin-anet-qt6-ui/build/bin/plasmanetworkmanagement_anet-vpn_ui.so"
  if [ ! -f "$UI_FILE" ]; then
    echo "KDE Qt6 UI библиотека не найдена: $UI_FILE" >&2
    exit 1
  fi

  LDD_OUTPUT=$(ldd -r "$UI_FILE" 2>&1 || true)
  if printf '%s\n' "$LDD_OUTPUT" | grep -Eq 'not found|undefined symbol'; then
    echo "KDE Qt6 UI библиотека несовместима с текущей системой: $UI_FILE" >&2
    printf '%s\n' "$LDD_OUTPUT" >&2
    exit 1
  fi
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

if [ "$UI_MODE" = "gtk" ]; then
  echo "Установка GTK UI библиотек для $DE_NAME"
  install -m 755 "$GTK_PLUGIN_FILE" "$NM_UI_DIR/"
  install -m 755 "$GTK3_EDITOR_FILE" "$NM_UI_DIR/"
  install -m 755 "$GTK4_EDITOR_FILE" "$NM_UI_DIR/"
fi

if [ "$UI_MODE" = "qt6" ]; then
  echo "Установка KDE Qt6 UI библиотеки"
  install -m 755 "$UI_FILE" "$UI_DIR/"
fi

echo "Перезапуск NetworkManager"
systemctl restart NetworkManager
nmcli connection reload

echo "Установка завершена"
echo "Для подключения выполните: nmcli connection up anet-vpn"
