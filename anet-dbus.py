#!/usr/bin/env python3

import os
import re
import time
import signal
import socket
import struct
import subprocess
import threading
import traceback

import dbus
import dbus.service
import dbus.mainloop.glib

from gi.repository import GLib


BUS_NAME = "org.freedesktop.NetworkManager.anet"
OBJECT_PATH = "/org/freedesktop/NetworkManager/VPN/Plugin"
IFACE = "org.freedesktop.NetworkManager.VPN.Plugin"

LOG_FILE = "/tmp/anet-vpn-nm.log"

DEFAULT_ANET_CLIENT = "/usr/local/bin/anet-client"
DEFAULT_ANET_CONFIG = "/etc/anet/config.conf"

DEFAULT_DNS = ["1.1.1.1", "8.8.8.8"]

NM_VPN_SERVICE_STATE_INIT = 1
NM_VPN_SERVICE_STATE_SHUTDOWN = 2
NM_VPN_SERVICE_STATE_STARTING = 3
NM_VPN_SERVICE_STATE_STARTED = 4
NM_VPN_SERVICE_STATE_STOPPING = 5
NM_VPN_SERVICE_STATE_STOPPED = 6

NM_VPN_PLUGIN_FAILURE_LOGIN_FAILED = 0
NM_VPN_PLUGIN_FAILURE_CONNECT_FAILED = 1
NM_VPN_PLUGIN_FAILURE_BAD_IP_CONFIG = 2


def log(msg):
    line = f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n"
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(line)
    print(line, end="", flush=True)


def ip4_to_uint32(addr):
    return dbus.UInt32(struct.unpack("!I", socket.inet_aton(addr))[0])


def netmask_to_prefix(netmask):
    packed = socket.inet_aton(netmask)
    value = struct.unpack("!I", packed)[0]
    return bin(value).count("1")


def safe_get_vpn_data(connection):
    """
    NetworkManager обычно передаёт VPN-параметры так:

    connection = {
        'vpn': {
            'service-type': ...,
            'data': {
                'config': '/etc/anet/config.conf',
                ...
            },
            ...
        }
    }

    Но для совместимости читаем и прямые ключи из секции vpn.
    """
    result = {}

    try:
        vpn = connection.get("vpn", {})
    except Exception:
        return result

    try:
        data = vpn.get("data", {})
        for k, v in data.items():
            result[str(k)] = str(v)
    except Exception:
        pass

    try:
        for k, v in vpn.items():
            if k not in ("data", "secrets"):
                result[str(k)] = str(v)
    except Exception:
        pass

    return result


class AnetVpnPlugin(dbus.service.Object):
    def __init__(self, bus):
        self.loop = None
        self.bus_name = dbus.service.BusName(BUS_NAME, bus=bus)

        super().__init__(
            conn=bus,
            object_path=OBJECT_PATH,
            bus_name=self.bus_name,
        )

        self.proc = None
        self.reader_thread = None
        self.started = False
        self.stopping = False

        self.anet_client = DEFAULT_ANET_CLIENT
        self.anet_config = DEFAULT_ANET_CONFIG

        self.external_gateway = None

        self.vpn_ip = None
        self.vpn_prefix = 24
        self.vpn_gw = None
        self.ifname = "anet-client"
        self.mtu = None

        log("anet vpn dbus service started")

    # ------------------------------------------------------------------
    # Signals expected by NetworkManager
    # ------------------------------------------------------------------

    @dbus.service.signal(dbus_interface=IFACE, signature="u")
    def StateChanged(self, state):
        pass

    @dbus.service.signal(dbus_interface=IFACE, signature="u")
    def Failure(self, reason):
        pass

    @dbus.service.signal(dbus_interface=IFACE, signature="s")
    def LoginBanner(self, banner):
        pass

    @dbus.service.signal(dbus_interface=IFACE, signature="a{sv}")
    def Config(self, config):
        pass

    @dbus.service.signal(dbus_interface=IFACE, signature="a{sv}")
    def Ip4Config(self, config):
        pass

    @dbus.service.signal(dbus_interface=IFACE, signature="a{sv}")
    def Ip6Config(self, config):
        pass

    @dbus.service.signal(dbus_interface=IFACE, signature="sas")
    def SecretsRequired(self, message, secrets):
        pass

    # ------------------------------------------------------------------
    # Methods called by NetworkManager
    # ------------------------------------------------------------------

    @dbus.service.method(
        dbus_interface=IFACE,
        in_signature="a{sa{sv}}",
        out_signature="s",
    )
    def NeedSecrets(self, connection):
        log("NeedSecrets() called")
        return dbus.String("")

    @dbus.service.method(
        dbus_interface=IFACE,
        in_signature="a{sa{sv}}",
        out_signature="",
    )
    def Connect(self, connection):
        log("Connect() called")
        log(f"Connect connection: {repr(connection)}")

        self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STARTING))

        data = safe_get_vpn_data(connection)

        self.anet_client = data.get("program", DEFAULT_ANET_CLIENT)
        self.anet_config = data.get("config", DEFAULT_ANET_CONFIG)

        # Это внешний IP VPN-сервера.
        # Лучше указать его в nmconnection как gateway.
        self.external_gateway = data.get("gateway", None)

        log(f"anet_client={self.anet_client}")
        log(f"anet_config={self.anet_config}")
        log(f"external_gateway={self.external_gateway}")

        GLib.timeout_add(100, self.start_anet)

    @dbus.service.method(
        dbus_interface=IFACE,
        in_signature="a{sa{sv}}a{sv}",
        out_signature="",
    )
    def ConnectInteractive(self, connection, details):
        log("ConnectInteractive() called")
        self.Connect(connection)

    @dbus.service.method(
        dbus_interface=IFACE,
        in_signature="",
        out_signature="",
    )
    def Disconnect(self):
        log("Disconnect() called")

        self.stopping = True
        self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STOPPING))

        try:
            self.stop_anet()
        except Exception:
            log("stop_anet() failed:")
            log(traceback.format_exc())

        self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STOPPED))

        GLib.timeout_add(300, self.quit_loop)

    @dbus.service.method(
        dbus_interface=IFACE,
        in_signature="a{sa{sv}}",
        out_signature="",
    )
    def NewSecrets(self, connection):
        log("NewSecrets() called")

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def start_anet(self):
        try:
            log("start_anet()")

            if not os.path.exists(self.anet_client):
                raise RuntimeError(f"anet-client not found: {self.anet_client}")

            if not os.path.exists(self.anet_config):
                raise RuntimeError(f"anet config not found: {self.anet_config}")

            cmd = [
                self.anet_client,
                "-c",
                self.anet_config,
            ]

            log(f"RUN: {' '.join(cmd)}")

            self.proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True,
                preexec_fn=os.setsid,
            )

            self.reader_thread = threading.Thread(
                target=self.read_anet_log,
                daemon=True,
            )
            self.reader_thread.start()

        except Exception:
            log("start_anet() failed:")
            log(traceback.format_exc())

            self.Failure(dbus.UInt32(NM_VPN_PLUGIN_FAILURE_CONNECT_FAILED))
            self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STOPPED))

        return False

    def read_anet_log(self):
        try:
            log("read_anet_log() started")

            for line in self.proc.stdout:
                line = line.rstrip("\n")
                log(f"ANET: {line}")

                self.parse_anet_line(line)

                if "VPN Tunnel UP" in line:
                    GLib.idle_add(self.finish_connect_from_main_loop)

            rc = self.proc.wait()
            log(f"anet-client exited with code {rc}")

            if not self.stopping and not self.started:
                GLib.idle_add(self.fail_connect)

            elif not self.stopping and self.started:
                GLib.idle_add(self.unexpected_disconnect)

        except Exception:
            log("read_anet_log() failed:")
            log(traceback.format_exc())
            GLib.idle_add(self.fail_connect)

    def parse_anet_line(self, line):
        # Пример:
        # [Core] Authenticated. VPN IP: 10.0.0.204
        if "VPN IP:" in line:
            try:
                value = line.split("VPN IP:", 1)[1].strip()
                value = value.split()[0].strip()
                self.vpn_ip = value
                log(f"parsed vpn_ip={self.vpn_ip}")
            except Exception:
                log("failed to parse VPN IP line")
                log(traceback.format_exc())

        # Пример:
        # [CORE] Connecting to 45.149.234.154:8443
        # [QUIC] Connecting to 45.149.234.154:8443...
        if "Connecting to " in line and not self.external_gateway:
            try:
                value = line.split("Connecting to ", 1)[1].strip()
                value = value.split()[0].strip()
                value = value.rstrip(".")
                host = value.split(":", 1)[0].strip()
                self.external_gateway = host
                log(f"parsed external_gateway={self.external_gateway}")
            except Exception:
                log("failed to parse Connecting to line")
                log(traceback.format_exc())

        # Пример:
        # Created TUN with: [Address: 10.0.0.204, Netmask: 255.255.255.0, Destination: 10.0.0.1, Name: anet-client, MTU: 1300] (actual name: anet-client)
        if "Created TUN with:" not in line:
            return

        try:
            left = line.split("[", 1)[1]
            inside = left.split("]", 1)[0]

            values = {}
            for item in inside.split(","):
                if ":" not in item:
                    continue
                key, value = item.split(":", 1)
                values[key.strip()] = value.strip()

            if values.get("Address"):
                self.vpn_ip = values.get("Address").strip()

            netmask = values.get("Netmask")
            if netmask:
                self.vpn_prefix = netmask_to_prefix(netmask.strip())

            if values.get("Destination"):
                self.vpn_gw = values.get("Destination").strip()

            mtu = values.get("MTU")
            if mtu:
                self.mtu = int(mtu.strip())

            if "actual name:" in line:
                actual = line.split("actual name:", 1)[1]
                actual = actual.split(")", 1)[0]
                self.ifname = actual.strip()
            elif values.get("Name"):
                self.ifname = values.get("Name").strip()

            log(f"parsed tun ifname={self.ifname}")
            log(f"parsed vpn_ip={self.vpn_ip}")
            log(f"parsed vpn_prefix={self.vpn_prefix}")
            log(f"parsed vpn_gw={self.vpn_gw}")
            log(f"parsed mtu={self.mtu}")

        except Exception:
            log("failed to parse Created TUN line")
            log(traceback.format_exc())

    def finish_connect_from_main_loop(self):
        if self.started:
            return False

        try:
            log("finish_connect_from_main_loop()")

            if not self.vpn_ip:
                raise RuntimeError("VPN IP was not parsed from anet-client log")

            if not self.vpn_gw:
                # По вашему логу обычно это 10.0.0.1.
                # Если строка Created TUN не распарсилась, используем fallback.
                self.vpn_gw = "10.0.0.1"

            if not self.external_gateway:
                # NetworkManager хочет gateway.
                # Лучше указывать gateway в nmconnection.
                raise RuntimeError("external VPN gateway was not parsed/found")

            config = dbus.Dictionary(
                {
                    # Имя TUN-интерфейса, который создал anet-client.
                    "tundev": dbus.String(self.ifname),

                    # Внешний адрес VPN-сервера, НЕ адрес внутри туннеля.
                    "gateway": ip4_to_uint32(self.external_gateway),

                    "has-ip4": dbus.Boolean(True),
                    "has-ip6": dbus.Boolean(False),
                },
                signature="sv",
            )

            if self.mtu:
                config["mtu"] = dbus.UInt32(self.mtu)

            log(f"emit Config: {repr(config)}")
            self.Config(config)

            ip4_config = dbus.Dictionary(
                {
                    "address": ip4_to_uint32(self.vpn_ip),
                    "prefix": dbus.UInt32(self.vpn_prefix),

                    # Внутренний gateway/ptp туннеля.
                    "gateway": ip4_to_uint32(self.vpn_gw),
                    "ptp": ip4_to_uint32(self.vpn_gw),

                    "dns": dbus.Array(
                        [ip4_to_uint32(x) for x in DEFAULT_DNS],
                        signature="u",
                    ),
                },
                signature="sv",
            )

            log(f"emit Ip4Config: {repr(ip4_config)}")
            self.Ip4Config(ip4_config)

            self.LoginBanner(dbus.String("anet VPN connected"))

            self.started = True
            self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STARTED))

            log("VPN marked as STARTED")

        except Exception:
            log("finish_connect_from_main_loop() failed:")
            log(traceback.format_exc())

            self.Failure(dbus.UInt32(NM_VPN_PLUGIN_FAILURE_BAD_IP_CONFIG))
            self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STOPPED))

            try:
                self.stop_anet()
            except Exception:
                log(traceback.format_exc())

        return False

    def fail_connect(self):
        if self.stopping:
            return False

        log("fail_connect()")

        self.Failure(dbus.UInt32(NM_VPN_PLUGIN_FAILURE_CONNECT_FAILED))
        self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STOPPED))

        GLib.timeout_add(300, self.quit_loop)

        return False

    def unexpected_disconnect(self):
        if self.stopping:
            return False

        log("unexpected_disconnect()")

        self.StateChanged(dbus.UInt32(NM_VPN_SERVICE_STATE_STOPPED))

        GLib.timeout_add(300, self.quit_loop)

        return False

    def stop_anet(self):
        log("stop_anet()")

        if self.proc is None:
            log("no anet-client process")
            return

        if self.proc.poll() is not None:
            log("anet-client already exited")
            return

        try:
            pgid = os.getpgid(self.proc.pid)
            log(f"sending SIGTERM to process group {pgid}")
            os.killpg(pgid, signal.SIGTERM)
        except Exception:
            log("SIGTERM failed:")
            log(traceback.format_exc())

        try:
            self.proc.wait(timeout=5)
            log("anet-client stopped by SIGTERM")
            return
        except subprocess.TimeoutExpired:
            log("anet-client did not stop after SIGTERM")

        try:
            pgid = os.getpgid(self.proc.pid)
            log(f"sending SIGKILL to process group {pgid}")
            os.killpg(pgid, signal.SIGKILL)
        except Exception:
            log("SIGKILL failed:")
            log(traceback.format_exc())

    def quit_loop(self):
        log("quit_loop()")

        if self.loop is not None:
            self.loop.quit()

        return False


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    bus = dbus.SystemBus()
    plugin = AnetVpnPlugin(bus)

    loop = GLib.MainLoop()
    plugin.loop = loop

    loop.run()


if __name__ == "__main__":
    main()
