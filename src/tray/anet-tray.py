#!/usr/bin/env python3
"""ANet VPN tray (PyQt6 port of the original PyQt5 script).

Shows current connection state and active Anet node, allows connect/disconnect
of the `anet-vpn` NetworkManager profile.

Requires: python-pyqt6, nmcli, gdbus.
"""

import re
import subprocess
import sys
from datetime import datetime

from PyQt6.QtCore import QProcess, QTimer
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

CONN_NAME = "anet-vpn"
LOG_PATH = "/tmp/anet-tray.log"

NM_DEST = "org.freedesktop.NetworkManager"
NM_PATH = "/org/freedesktop/NetworkManager"
NM_ACTIVE_IFACE = "org.freedesktop.NetworkManager.Connection.Active"
NM_VPN_IFACE = "org.freedesktop.NetworkManager.VPN.Connection"

BANNER_PREFIX = "anet VPN connected — "


def log(msg):
    line = f"{datetime.now():%Y-%m-%d %H:%M:%S} {msg}"
    print(line, file=sys.stderr)
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def _gdbus_get(object_path, interface, prop):
    """Read a D-Bus property via gdbus, return raw stdout or None."""
    try:
        result = subprocess.run(
            [
                "gdbus",
                "call",
                "--system",
                "--dest",
                NM_DEST,
                "--object-path",
                object_path,
                "--method",
                "org.freedesktop.DBus.Properties.Get",
                interface,
                prop,
            ],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if result.returncode != 0:
            log(f"gdbus {prop} failed: {result.stderr.strip()}")
            return None
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        log(f"gdbus {prop} timeout")
        return None
    except OSError as exc:
        log(f"gdbus {prop} error: {exc}")
        return None


def _parse_variant_string(raw):
    """Extract a string from gdbus output like (<'value'>,) or ('value',)."""
    if not raw:
        return None
    match = re.search(r"['\"]([^'\"]*)['\"]", raw)
    return match.group(1) if match else None


def active_node():
    """Return active Anet node name, or None when unknown/absent."""
    raw = _gdbus_get(NM_PATH, NM_DEST, "ActiveConnections")
    if not raw:
        return None

    for path in re.findall(
        r"/org/freedesktop/NetworkManager/ActiveConnection/\d+", raw
    ):
        conn_type = _parse_variant_string(_gdbus_get(path, NM_ACTIVE_IFACE, "Type"))
        if conn_type != "vpn":
            continue

        conn_id = _parse_variant_string(_gdbus_get(path, NM_ACTIVE_IFACE, "Id"))
        if conn_id != CONN_NAME:
            continue

        banner = _parse_variant_string(_gdbus_get(path, NM_VPN_IFACE, "Banner"))
        if banner and banner.startswith(BANNER_PREFIX):
            node = banner[len(BANNER_PREFIX) :].strip()
            return node or None
        return None

    return None


class AnetTray:
    def __init__(self):
        self.app = QApplication(sys.argv)
        self.app.setQuitOnLastWindowClosed(False)

        self.proc = None
        self.command_running = False

        self.tray = QSystemTrayIcon(QIcon.fromTheme("network-vpn"), self.app)
        self.tray.setVisible(True)
        self.tray.setToolTip("ANet VPN: загрузка...")

        self.menu = QMenu()

        self.status_action = self.menu.addAction("ANet VPN: …")
        self.status_action.setEnabled(False)

        self.menu.addSeparator()

        self.connect_action = self.menu.addAction("🟢 Подключить")
        self.connect_action.triggered.connect(self.connect_vpn)

        self.disconnect_action = self.menu.addAction("🔴 Отключить")
        self.disconnect_action.triggered.connect(self.disconnect_vpn)

        self.menu.addSeparator()

        self.exit_action = self.menu.addAction("❌ Выход")
        self.exit_action.triggered.connect(self.quit_app)

        self.tray.setContextMenu(self.menu)

        self.timer = QTimer()
        self.timer.timeout.connect(self.update_status)
        self.timer.start(2000)

        self.update_status()

        sys.exit(self.app.exec())

    def is_connected(self):
        try:
            result = subprocess.run(
                ["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"],
                capture_output=True,
                text=True,
                timeout=2,
                check=False,
            )
            if result.returncode != 0:
                log(f"status nmcli failed: {result.stderr.strip()}")
                return False
            return CONN_NAME in [line.strip() for line in result.stdout.splitlines()]
        except subprocess.TimeoutExpired:
            log("status check timeout")
            return False
        except OSError as exc:
            log(f"status check error: {exc}")
            return False

    def set_status(self, text):
        self.tray.setToolTip(text)
        self.status_action.setText(text)

    def update_status(self):
        if self.command_running:
            self.set_status("ANet VPN: выполняется команда...")
            self.connect_action.setEnabled(False)
            self.disconnect_action.setEnabled(False)
            return

        if self.is_connected():
            node = active_node()
            if node:
                self.set_status(f"ANet VPN: подключено — {node}")
            else:
                self.set_status("ANet VPN: подключено (нода неизвестна)")
            self.connect_action.setEnabled(False)
            self.disconnect_action.setEnabled(True)
        else:
            self.set_status("ANet VPN: отключено")
            self.connect_action.setEnabled(True)
            self.disconnect_action.setEnabled(False)

    def run_nmcli_async(self, args):
        if self.command_running:
            log("command already running, ignored")
            return

        full_args = ["--wait", "0"] + args
        log("running: nmcli " + " ".join(full_args))

        self.command_running = True
        self.update_status()

        self.proc = QProcess()
        self.proc.setProgram("nmcli")
        self.proc.setArguments(full_args)

        self.proc.readyReadStandardOutput.connect(self.on_stdout)
        self.proc.readyReadStandardError.connect(self.on_stderr)
        self.proc.finished.connect(self.on_finished)

        self.proc.start()

        if not self.proc.waitForStarted(3000):
            log("failed to start nmcli")
            self.command_running = False
            self.proc = None
            self.update_status()

    def on_stdout(self):
        if not self.proc:
            return
        data = bytes(self.proc.readAllStandardOutput()).decode(errors="replace").strip()
        if data:
            log("stdout: " + data)

    def on_stderr(self):
        if not self.proc:
            return
        data = bytes(self.proc.readAllStandardError()).decode(errors="replace").strip()
        if data:
            log("stderr: " + data)

    def on_finished(self, exit_code, exit_status):
        log(f"nmcli finished: exit_code={exit_code}, exit_status={exit_status}")

        self.command_running = False
        self.proc = None

        # NetworkManager может ещё активировать VPN после возврата nmcli --wait 0.
        QTimer.singleShot(1500, self.update_status)
        QTimer.singleShot(4000, self.update_status)

    def connect_vpn(self):
        self.run_nmcli_async(["connection", "up", "id", CONN_NAME])

    def disconnect_vpn(self):
        self.run_nmcli_async(["connection", "down", "id", CONN_NAME])

    def quit_app(self):
        # При выходе из tray-приложения VPN НЕ отключается.
        log("quit app")
        self.app.quit()


if __name__ == "__main__":
    AnetTray()
