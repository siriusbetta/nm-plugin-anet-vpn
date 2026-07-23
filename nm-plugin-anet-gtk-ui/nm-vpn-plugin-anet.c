#include "anet-vpn-plugin.h"

/* Factory function - entry point for libnm */
NMVpnEditorPlugin *
nm_vpn_editor_plugin_factory(GError **error)
{
    return anet_vpn_plugin_new();
}
