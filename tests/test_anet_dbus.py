import importlib.util
import sys
import types
import unittest
from pathlib import Path


def load_dispatcher_module():
    dbus = types.ModuleType("dbus")
    dbus.UInt32 = int
    dbus.String = str
    dbus.Boolean = bool
    dbus.Array = list
    dbus.Dictionary = dict
    dbus.SystemBus = object

    service = types.ModuleType("dbus.service")
    service.Object = object
    service.BusName = object

    def decorator(*args, **kwargs):
        del args, kwargs

        def wrap(func):
            return func

        return wrap

    service.signal = decorator
    service.method = decorator
    dbus.service = service

    mainloop = types.ModuleType("dbus.mainloop")
    mainloop_glib = types.ModuleType("dbus.mainloop.glib")
    mainloop_glib.DBusGMainLoop = object
    mainloop.glib = mainloop_glib
    dbus.mainloop = mainloop

    gi = types.ModuleType("gi")
    repository = types.ModuleType("gi.repository")
    repository.GLib = types.SimpleNamespace()
    gi.repository = repository

    modules = {
        "dbus": dbus,
        "dbus.service": service,
        "dbus.mainloop": mainloop,
        "dbus.mainloop.glib": mainloop_glib,
        "gi": gi,
        "gi.repository": repository,
    }

    previous = {name: sys.modules.get(name) for name in modules}
    sys.modules.update(modules)
    try:
        path = Path(__file__).parents[1] / "src" / "anet-dbus.py"
        spec = importlib.util.spec_from_file_location("anet_dbus", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        for name, old_module in previous.items():
            if old_module is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = old_module


anet_dbus = load_dispatcher_module()
anet_dbus.log = lambda message: None


def parser():
    plugin = anet_dbus.AnetVpnPlugin.__new__(anet_dbus.AnetVpnPlugin)
    plugin.external_gateway = None
    plugin.vpn_ip = None
    plugin.vpn_prefix = 24
    plugin.vpn_gw = None
    plugin.ifname = "anet-client"
    plugin.mtu = None
    return plugin


class AnetLogParserTests(unittest.TestCase):
    def test_old_tunnel_line_is_supported(self):
        self.assertTrue(anet_dbus.is_tunnel_up_line("[Core] VPN Tunnel UP"))

    def test_new_tunnel_line_is_supported(self):
        line = "[Core] VPN interface configured. Tunnel UP. Active node: Primary"
        self.assertTrue(anet_dbus.is_tunnel_up_line(line))

    def test_old_tun_line_without_timestamp_is_parsed(self):
        plugin = parser()
        plugin.parse_anet_line(
            "Created TUN with: [Address: 10.0.0.204, "
            "Netmask: 255.255.255.0, Destination: 10.0.0.1, "
            "Name: anet-client, MTU: 1300] (actual name: anet-client)"
        )

        self.assertEqual(plugin.vpn_ip, "10.0.0.204")
        self.assertEqual(plugin.vpn_prefix, 24)
        self.assertEqual(plugin.vpn_gw, "10.0.0.1")
        self.assertEqual(plugin.ifname, "anet-client")
        self.assertEqual(plugin.mtu, 1300)

    def test_new_tun_line_with_timestamp_is_parsed(self):
        plugin = parser()
        plugin.parse_anet_line(
            "[2026-09-05T19:49:59Z INFO anet_common::atun] "
            "Created TUN with: [Address: 10.2.0.3, Netmask: 255.255.0.0, "
            "Destination: 10.2.0.1, Name: anet-client, MTU: 1300] "
            "(actual name: anet-client)"
        )

        self.assertEqual(plugin.vpn_ip, "10.2.0.3")
        self.assertEqual(plugin.vpn_prefix, 16)
        self.assertEqual(plugin.vpn_gw, "10.2.0.1")

    def test_old_vpn_ip_and_new_assigned_ip_are_supported(self):
        plugin = parser()
        plugin.parse_anet_line("[Core] Authenticated. VPN IP: 10.0.0.204")
        self.assertEqual(plugin.vpn_ip, "10.0.0.204")

        plugin.parse_anet_line("[SSH] ASTP authenticated; assigned IP 10.2.0.3")
        self.assertEqual(plugin.vpn_ip, "10.2.0.3")

    def test_failover_replaces_gateway_with_latest_valid_endpoint(self):
        plugin = parser()
        plugin.external_gateway = "198.51.100.1"  # nmconnection fallback

        plugin.parse_anet_line(
            "[Core] Connecting to server 'Primary [QUIC]' "
            "(quic://192.0.2.10:8443)"
        )
        self.assertEqual(plugin.external_gateway, "192.0.2.10")

        plugin.parse_anet_line(
            "[Core] Connecting to server 'Backup [SSH]' "
            "(ssh://192.0.2.20:8222)"
        )
        self.assertEqual(plugin.external_gateway, "192.0.2.20")

    def test_old_connecting_line_is_supported(self):
        plugin = parser()
        plugin.parse_anet_line("[QUIC] Connecting to 192.0.2.30:8443...")
        self.assertEqual(plugin.external_gateway, "192.0.2.30")

    def test_server_label_is_not_treated_as_gateway(self):
        self.assertIsNone(
            anet_dbus.extract_external_gateway(
                "[Core] Connecting to server 'Primary' without a DSN"
            )
        )


if __name__ == "__main__":
    unittest.main()
