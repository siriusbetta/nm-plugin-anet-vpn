


# NetworkManager Anet VPN Plugin

Плагин NetworkManager для VPN-клиента [Anet https://github.com/ZeroTworu/anet](https://github.com/ZeroTworu/anet).

Позволяет управлять Anet VPN через NetworkManager: подключение отображается в списке соединений, поддерживаются действия `Connect` / `Disconnect`, а в настройках можно выбрать конфигурационный файл и открыть его для редактирования.

---

## Возможности

- Интеграция Anet VPN с NetworkManager.
- Управление через стандартный интерфейс NetworkManager.
- Поддержка KDE Plasma/Qt6 и Gnome/GTK.
- Настройка пути к `config.toml`.
- DBus-dispatcher для обработки команд подключения и отключения.
  
---

## Структура проекта

```text
.
├── config/                 # Конфигурации NetworkManager и DBus
├── src/                    # DBus dispatcher
├── nm-plugin-anet-gtk-ui/  # GTK3/GTK4 UI-виджет
├── nm-plugin-anet-qt6-ui/  # Qt6 UI-виджет
├── install.sh              # Установка
└── uninstall.sh            # Удаление
```
---
## Зависимости

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install python3-dbus python3-gi unzip
```

### Arch Linux / Manjaro

```bash
sudo pacman -S python-dbus python-gobject unzip
```
---
## Установка
Перед установкой положите архив с клиентом Anet рядом со скриптом install.sh.

Ожидаемое имя архива:

client-linux-amd64_xx.xx.xx.zip

Пример структуры:
```text
.
├── config/
├── src/
├── nm-plugin-anet-gtk-ui/
├── nm-plugin-anet-qt6-ui/
├── install.sh
├── uninstall.sh
└── client-linux-amd64_xx.xx.xx.zip
```
Запустите установку:

```bash
chmod +x install.sh
sudo ./install.sh
```

Подключение:

```bash
sudo nmcli connection up anet-vpn
```

Отключение:

```bash
sudo nmcli connection down anet-vpn
```

Удаление

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

После удаления:

```bash
sudo systemctl restart NetworkManager
```

Сброс состояния:

```bash
sudo pkill -f anet-dbus.py || true
sudo rm -f /tmp/anet-vpn.log
sudo ip tuntap del dev anet-vpn0 mode tun 2>/dev/null || true
```

Отладка

Логи NetworkManager:

```bash
journalctl -u NetworkManager -f
```

Лог плагина:

```bash
tail -f /tmp/anet-vpn.log
```
---
## Сборка UI-виджета
Сборка выполняется в контейнере podman.

### Сборка Qt6

```bash
mkdir -p ~/tmp-build
cd nm-plugin-anet-qt6
```

Сборка контейнера:

```bash
TMPDIR=~/tmp-build podman build -f Container-arch -t kde-arch-dev .
```

Сборка UI:

```bash
TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-arch-dev \
  sh -c "rm -rf build && cmake -B build && cmake --build build"
```
Готовый файл:

build/bin/plasmanetworkmanagement_anet-vpn_ui.so

### Сборка GTK

Сборка GTK выполняется так же, как контейнерная сборка Qt6:

```bash
cd nm-plugin-anet-gtk-ui
./build_arch.sh    # Arch Linux / Manjaro
./build_debian.sh  # Debian / Ubuntu
```
Скрипт сам создаёт Podman-контейнер, запускает CMake и оставляет GTK-библиотеки в `nm-plugin-anet-gtk-ui/build/`.

---

## Сборка библиотек

Каждая библиотека собирается отдельно в соответствующей директории проекта:

- GTK-библиотеки — в `nm-plugin-anet-gtk-ui/`;
- Qt6-библиотека — в `nm-plugin-anet-qt6-ui/`.

Установочный скрипт `install.sh` сам определяет операционную систему и графическое окружение и выбирает каталог установки для собранной библиотеки.

---

## Возможные проблемы

* NetworkManager не видит подключение

  Проверьте права:
```bash
ls -l /etc/NetworkManager/system-connections/anet-vpn.nmconnection
```

  Должно быть:

-rw------- root root

   Исправить:

```bash
sudo chmod 600 /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo chown root:root /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo nmcli connection reload
```

* UI-виджет не отображается

  Проверьте путь установки:

```bash
ls -l /usr/lib/qt6/plugins/plasma/network/vpn/
```

  В некоторых дистрибутивах путь может отличаться:

```bash
/usr/lib/qt6/plugins/plasma/network/vpn/
/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/
```
