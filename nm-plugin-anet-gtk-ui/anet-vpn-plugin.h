#pragma once

#include <NetworkManager.h>

G_BEGIN_DECLS

#define ANET_TYPE_VPN_PLUGIN (anet_vpn_plugin_get_type())
G_DECLARE_FINAL_TYPE(AnetVpnPlugin,
                     anet_vpn_plugin,
                     ANET,
                     VPN_PLUGIN,
                     GObject)

NMVpnEditorPlugin *anet_vpn_plugin_new(void);

G_END_DECLS
