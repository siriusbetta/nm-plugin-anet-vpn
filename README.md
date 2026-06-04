
## Описание

NetworkManager плагин для клиента [**Anet**](https://github.com/ZeroTworu/anet). 


## Плагин NetworkManager
- NM configs (.nmconnection, .name, .service, .conf)
- DBus dispatcher (.py)
- UI (.so)

## Установка
Плагин упакован в архив со структурой такой же как в репозитории. Необходимо распаковать, в корень папки, рядом со скриптом install.sh положить архив с anet-client'ом в виде client-linux-amd64_xx.xx.xx.zip.
### Install

```bash
chmod +x install.sh
sudo ./install.sh
```

### Uninstall

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

## Ниже тоже самое, по шагам, что в скрипе install.sh

### nmconnection
соединение для NM, которое будет отображаться в меню аплета, и заодно там же хранится секция \[vpn\], где прописаны пути к **anet-client** и **config.toml**. NM работает с этим файлом как хранилищем настроек ВПНа. Важно чтобы права доступа были для root, иначе NM не подхватит.

```bash
cp config/anet-vpn.nmconnection /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo chmod 600 /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo chown root:root /etc/NetworkManager/system-connections/anet-vpn.nmconnection
```

### name

связывает обработчик dbus команд и NM connection с узлом DBus

```bash
cp config/anet.name  /usr/lib/NetworkManager/VPN/anet.name
```
### service

по своей структуре повторяет nmconnection. И в plasma работает и без него. Возможно это надо в среде GTK. Возможно, надо будет удалить.
```bash
cp config/org.freedesktop.NetworkManager.anet.service /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service
```
### conf
определяет политику сервиса. Позволяет работать от root
```bash
cp config/org.freedesktop.NetworkManager.anet.conf /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf
sudo dbus-send \
  --system \
  --type=method_call \
  --dest=org.freedesktop.DBus \
  / \
  org.freedesktop.DBus.ReloadConfig
```

### DBus dispatcher
Висит на шине DBus и перехватывает команды от NM (connect, disconnect). 

```bash
cp src/anet-dbus.py /usr/local/libexec/anet-dbus.py
sudo chmod +x /usr/local/libexec/anet-dbus.py
sudo chown root:root /usr/local/libexec/anet-dbus.py
```
## Зависимости
### для Debian
```bash
sudo apt update
sudo apt install python3-dbus python3-gi
```
### для Arch/Manjaro
```bash
sudo pacman -S python-dbus python-gobject
```

## UI widget

```bash
cd nm-plugin-hello-qt6-ui
sudo cp build/bin/plasmanetworkmanagement_anet-vpn_ui.so /usr/lib/qt6/plugins/plasma/network/vpn/
sudo chmod 755 /usr/lib/qt6/plugins/plasma/network/vpn/plasmanetworkmanagement_anet-vpn_ui.so
```

## anet-client

```bash
unzip client-linux-amd64_xx.xx.xx.zip
cd client-linux-amd64
cp anet-client /usr/local/bin/
cp config.toml /usr/local/etc/anet-config.toml
```

## restart NetworkManager
```bash
sudo systemctl restart NetworkManager
sudo nmcli connection reload
sudo nmcli connection up anet-vpn
```

## debug

```bash
sudo pkill -f anet-dbus.py || true
sudo rm -f /tmp/anet-vpn.log
sudo ip tuntap del dev anet-vpn0 mode tun 2>/dev/null || true
```

## Сборка UI

Сборка происходит в контейнере podman

шаблон:
```bash
TMPDIR=~/tmp-build podman build -f \<Containerfile-name\> -t \<image name\> \<src\>
```

- KDE

```bash
mkdir ~/tmp-build
cd nm-plugin-hello-qt6-ui 
TMPDIR=~/tmp-build podman build -f Container-arch -t kde-arch-dev .
```
- сборка ui виджета qt6

```bash  
TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-arch-dev 
sh -c "rm -rf build && cmake -B build && cmake --build build"
```
