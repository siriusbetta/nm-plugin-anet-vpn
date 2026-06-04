
## Description

NM plugin for **Anet** created by [ZeroTworu](https://github.com/ZeroTworu/anet)

## 1 - nmconnection

```bash
cp config/anet-vpn.nmconnection /etc/NetworkManager/system-connections/anet-vpn.nmconnection

sudo chmod 600 /etc/NetworkManager/system-connections/anet-vpn.nmconnection
sudo chown root:root /etc/NetworkManager/system-connections/anet-vpn.nmconnection
```

## 2 - name

```bash
cp config/anet.name  /usr/lib/NetworkManager/VPN/anet.name
```

## 3 - service

```bash
cp config/org.freedesktop.NetworkManager.anet.service /usr/share/dbus-1/system-services/org.freedesktop.NetworkManager.anet.service
```

## 4 - conf

```bash
cp config/org.freedesktop.NetworkManager.anet.conf /etc/dbus-1/system.d/org.freedesktop.NetworkManager.anet.conf
```

## 5 - reset dbus

```bash
sudo dbus-send \
  --system \
  --type=method_call \
  --dest=org.freedesktop.DBus \
  / \
  org.freedesktop.DBus.ReloadConfig
```


## 6 - dbus dispatcher

```bash
cp src/anet-dbus.py /usr/local/libexec/anet-dbus.py
sudo chmod +x /usr/local/libexec/anet-dbus.py
sudo chown root:root /usr/local/libexec/anet-dbus.py
```
### for Debian/Ubuntu
```bash
sudo apt update
sudo apt install python3-dbus python3-gi
```
### for Arch/Manjaro
```bash
sudo pacman -S python-dbus python-gobject
```

## 7 - install UI
### Qt6 based 

```bash
cd nm-plugin-hello-qt6-ui
sudo cp build/bin/plasmanetworkmanagement_anet-vpn_ui.so /usr/lib/qt6/plugins/plasma/network/vpn/
sudo chmod 755 /usr/lib/qt6/plugins/plasma/network/vpn/plasmanetworkmanagement_anet-vpn_ui.so
```

## 8 - restart NetworkManager

```bash
sudo systemctl restart NetworkManager
sudo nmcli connection reload
```


## 9 - up connection

```bash
sudo nmcli connection up anet-vpn
```

## debug

```bash
sudo pkill -f anet-dbus.py || true
sudo rm -f /tmp/anet-vpn.log
sudo ip tuntap del dev anet-vpn0 mode tun 2>/dev/null || true
```

## build 

TMPDIR=~/tmp-build podman build -f \<Container-name\> -t \<image name\> \<src\>


### container for KDE

```bash
mkdir ~/tmp-build
cd nm-plugin-hello-qt6-ui 
TMPDIR=~/tmp-build podman build -f Container-arch -t kde-arch-dev .
```

### build lib qt6 for plugin

```bash  
TMPDIR=~/tmp-build podman run --rm -v "$PWD:/src:Z" kde-arch-dev 
sh -c "rm -rf build && cmake -B build && cmake --build build"
```

## Install

```bash
chmod +x install.sh
sudo ./install.sh
```

## Uninstall

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```
