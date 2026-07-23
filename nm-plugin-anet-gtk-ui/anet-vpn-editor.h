#pragma once

#include <NetworkManager.h>

G_BEGIN_DECLS

#define ANET_TYPE_VPN_EDITOR (anet_vpn_editor_get_type())
G_DECLARE_FINAL_TYPE(AnetVpnEditor, anet_vpn_editor, ANET, VPN_EDITOR, GObject)

NMVpnEditor *anet_vpn_editor_new(NMConnection *connection, GError **error);
NMVpnEditor *nm_vpn_editor_factory_anet(NMConnection *connection,
                                              GError **error);

G_END_DECLS
