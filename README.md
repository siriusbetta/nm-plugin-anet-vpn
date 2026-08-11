


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
├── install.sh              # Установка из дерева исходников
├── install.sh.in           # Шаблон установщика release-пакета
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
Необходимо взять релизный архив, распаковать и в корень распакованной папки положить архив с клиентом Anet рядом со скриптом install.sh.

Ожидаемое имя архива:

client-linux-amd64_xx.xx.xx.zip

Пример структуры:
```text
.
├── config/
├── src/
├── lib/
│   ├── debian-libnm-vpn-plugin-anet.so
│   ├── debian-libnm-vpn-plugin-anet-editor.so
│   ├── debian-libnm-gtk4-vpn-plugin-anet-editor.so
│   ├── arch-libnm-vpn-plugin-anet.so
│   ├── arch-libnm-vpn-plugin-anet-editor.so
│   ├── arch-libnm-gtk4-vpn-plugin-anet-editor.so
│   ├── debian-plasmanetworkmanagement_anet-vpn_ui.so
│   └── arch-plasmanetworkmanagement_anet-vpn_ui.so
├── install.sh
├── uninstall.sh
└── client-linux-amd64_xx.xx.xx.zip
```

Release-установщик выбирает GTK-библиотеки для GNOME, Unity, Cinnamon, MATE или
XFCE и Qt6-библиотеку для KDE Plasma. Для GTK и Qt6 автоматически выбирается
Debian/Ubuntu/Linux Mint либо Arch/Manjaro вариант. Distro-префикс удаляется
при установке, поэтому NetworkManager получает стандартные имена библиотек.

Установка перезапускает NetworkManager и может временно прервать активное
сетевое соединение.
Запустите установку:

```bash
chmod +x install.sh
sudo ./install.sh --desktop cinnamon
```

Допустимые значения `--desktop`: `gnome`, `unity`, `cinnamon`, `mate`, `xfce`,
`kde-plasma`. Без параметра установщик пытается определить окружение
автоматически по переменным desktop session.

### Проверено

- Linux Mint (Cinnamon, MATE, Xfce)
- Ubuntu (GNOME)
- Xubuntu
- Kubuntu
- Arch Linux (KDE, GNOME)
- Manjaro (KDE)

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

Необходимо скачать исходники 

```bash
git clone --recurse-submodules https://github.com/siriusbetta/nm-plugin-anet-vpn.git 
```

Сборка выполняется в контейнере podman.

## Сборка библиотек

Каждая библиотека собирается отдельно в соответствующей директории проекта:

- GTK-библиотеки — в `nm-plugin-anet-gtk-ui/`;
- Qt6-библиотека — в `nm-plugin-anet-qt6-ui/`.

### Сборка Qt6

Для сборки Qt6 требуется Podman. Скрипты сами выбирают совместимую ревизию
`plasma-nm`, собирают container image, запускают CMake и после завершения
восстанавливают исходное состояние submodule:

```bash
cd nm-plugin-anet-qt6-ui
./build_debian.sh  # Debian / Ubuntu и производные
# или
./build_arch.sh    # Arch Linux / Manjaro
```

Результат сборки:

```text
build/bin/plasmanetworkmanagement_anet-vpn_ui.so
```

### Сборка GTK

Для сборки GTK требуется Podman. Скрипты сами собирают нужный container image,
запускают CMake в контейнере и сохраняют результат в `build/`:

```bash
cd nm-plugin-anet-gtk-ui
./build_debian.sh  # Debian / Ubuntu / Linux Mint
# или
./build_arch.sh    # Arch Linux / Manjaro
```

Результат сборки:

```text
build/libnm-vpn-plugin-anet.so
build/libnm-vpn-plugin-anet-editor.so
build/libnm-gtk4-vpn-plugin-anet-editor.so
```

Каждый скрипт перед сборкой удаляет текущий `build/`, поэтому после
последовательного запуска двух скриптов в каталоге остаются библиотеки только
для последнего выбранного дистрибутива.

---

Установочный скрипт `install.sh` определяет операционную систему, использует
явный параметр `--desktop` или автоматическое определение окружения и выбирает
подходящую UI-библиотеку и каталог установки.

---

## Возможные проблемы

### Графическое окружение не определено

Укажите desktop environment явно:

```bash
sudo ./install.sh --desktop cinnamon
```

Допустимые значения: `gnome`, `unity`, `cinnamon`, `mate`, `xfce`, `kde-plasma`.

### NetworkManager не видит подключение

Проверьте наличие и права connection profile:

```bash
ls -l /etc/NetworkManager/system-connections/anet-vpn.nmconnection
```

Ожидаемые права и владелец:

```text
-rw------- root root
```

Исправление:

```bash
sudo chmod 600 /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo chown root:root /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo nmcli connection reload
```

### GTK UI не отображается

Определите каталог плагинов NetworkManager и проверьте три библиотеки:

```bash
NM_LIBDIR=$(pkg-config --variable=libdir libnm)
ls -l "$NM_LIBDIR/NetworkManager"/libnm-vpn-plugin-anet.so
ls -l "$NM_LIBDIR/NetworkManager"/libnm-vpn-plugin-anet-editor.so
ls -l "$NM_LIBDIR/NetworkManager"/libnm-gtk4-vpn-plugin-anet-editor.so
```

Если `pkg-config` не вернул путь, проверьте каталоги:

```text
/usr/lib/x86_64-linux-gnu/NetworkManager/
/usr/lib/NetworkManager/
```

Проверьте динамические зависимости каждой найденной библиотеки:

```bash
ldd -r /путь/к/libnm-vpn-plugin-anet.so
ldd -r /путь/к/libnm-vpn-plugin-anet-editor.so
ldd -r /путь/к/libnm-gtk4-vpn-plugin-anet-editor.so
```

Также проверьте metadata-файл; он должен читаться обычным пользователем:

```bash
ls -l /usr/lib/NetworkManager/VPN/anet.name
```

Ожидаемый режим — `644` (`-rw-r--r--`).

### В Xfce недоступен пункт `VPN Settings` после установки

Xfce `nm-applet` может сохранить список VPN editor plugins, загруженный до
установки Anet. Installer пытается перезапустить `nm-applet` только для
пользователя, который запустил его через `sudo`.

Если автоматическое обновление не сработало, перезапустите applet вручную из
пользовательской сессии:

```bash
pkill nm-applet
nohup nm-applet >/tmp/nm-applet-anet.log 2>&1 &
```

Профиль также можно открыть напрямую:

```bash
nm-connection-editor
```

### Qt6 UI не отображается

Проверьте путь установки:

```bash
ls -l /usr/lib/qt6/plugins/plasma/network/vpn/
```

В Debian/Ubuntu и производных путь может отличаться:

```text
/usr/lib/qt6/plugins/plasma/network/vpn/
/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/network/vpn/
```

Проверьте динамические зависимости Qt6-библиотеки:

```bash
ldd -r /путь/к/plasmanetworkmanagement_anet-vpn_ui.so
```

### После удаления осталось соединение `anet-vpn`

Проверьте сохранённые NetworkManager profiles:

```bash
nmcli -f NAME,UUID,TYPE connection show | grep -i anet
```

Если профиль остался, удалите его по UUID:

```bash
sudo nmcli connection delete uuid aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
sudo nmcli connection reload
```
