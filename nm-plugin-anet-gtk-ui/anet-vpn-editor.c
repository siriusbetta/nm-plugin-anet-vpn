#include "anet-vpn-editor.h"
#include <gmodule.h>
#include <gtk/gtk.h>
#include <string.h>

#define ANET_VPN_SERVICE_TYPE "org.freedesktop.NetworkManager.anet"
#define ANET_KEY_CONFIG "config"
#define ANET_KEY_SERVICE "service"

#if !GTK_CHECK_VERSION(4, 0, 0)
#define gtk_editable_get_text(editable) gtk_entry_get_text(GTK_ENTRY(editable))
#define gtk_editable_set_text(editable, text) \
    gtk_entry_set_text(GTK_ENTRY(editable), (text))
#endif

struct _AnetVpnEditor {
    GObject parent;
    NMConnection *connection;
    GtkWidget *widget;
    GtkWidget *path_entry;
    const char *path_key;
};

static void anet_vpn_editor_interface_init(NMVpnEditorInterface *iface);
static void on_file_selected(GtkNativeDialog *dialog, gint response_id, gpointer user_data);
static void on_browse_clicked(GtkWidget *button, AnetVpnEditor *self);
static void on_edit_clicked(GtkWidget *button, AnetVpnEditor *self);
static void on_path_changed(GtkEditable *editable, AnetVpnEditor *self);

G_DEFINE_TYPE_WITH_CODE(
    AnetVpnEditor,
    anet_vpn_editor,
    G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(NM_TYPE_VPN_EDITOR, anet_vpn_editor_interface_init)
)

static void
box_append(GtkBox *box, GtkWidget *child, gboolean expand)
{
#if GTK_CHECK_VERSION(4, 0, 0)
    gtk_box_append(box, child);
#else
    gtk_box_pack_start(box, child, expand, expand, 0);
#endif
}

static void
unref_user_data(gpointer data, GClosure *closure)
{
    g_object_unref(data);
}

static void
on_path_changed(GtkEditable *editable, AnetVpnEditor *self)
{
    (void) editable;
    g_signal_emit_by_name(self, "changed");
}

static void
on_file_selected(GtkNativeDialog *dialog, gint response_id, gpointer user_data)
{
    AnetVpnEditor *self = ANET_VPN_EDITOR(user_data);
    GFile *file = NULL;

    if (response_id == GTK_RESPONSE_ACCEPT)
        file = gtk_file_chooser_get_file(GTK_FILE_CHOOSER(dialog));

    if (file && self->path_entry) {
        char *path = g_file_get_path(file);
        if (path) {
            gtk_editable_set_text(GTK_EDITABLE(self->path_entry), path);
            g_free(path);
        }
    }

    g_clear_object(&file);
    g_object_unref(dialog);
}

static void
on_browse_clicked(GtkWidget *button, AnetVpnEditor *self)
{
    GtkWindow *parent = NULL;
    GtkWidget *root;
    GtkFileChooserNative *dialog;

#if GTK_CHECK_VERSION(4, 0, 0)
    root = GTK_WIDGET(gtk_widget_get_root(self->widget));
#else
    root = gtk_widget_get_toplevel(self->widget);
#endif

    if (GTK_IS_WINDOW(root))
        parent = GTK_WINDOW(root);

    dialog = gtk_file_chooser_native_new(
        "Select Configuration File",
        parent,
        GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Open",
        "_Cancel"
    );

    g_signal_connect_data(dialog,
                          "response",
                          G_CALLBACK(on_file_selected),
                          g_object_ref(self),
                          unref_user_data,
                          0);

    gtk_native_dialog_show(GTK_NATIVE_DIALOG(dialog));
}

static void
on_edit_clicked(GtkWidget *button, AnetVpnEditor *self)
{
    const char *path;
    char *uri;
    GError *error = NULL;

    (void) button;
    path = gtk_editable_get_text(GTK_EDITABLE(self->path_entry));
    if (!path || !*path || !g_file_test(path, G_FILE_TEST_IS_REGULAR))
        return;

    uri = g_filename_to_uri(path, NULL, &error);
    if (uri) {
        if (!g_app_info_launch_default_for_uri(uri, NULL, &error))
            g_warning("Failed to open configuration file: %s",
                      error ? error->message : "unknown error");
        g_free(uri);
    }

    g_clear_error(&error);
}

static void
fill_connection(NMVpnEditor *editor, NMConnection *connection)
{
    NMSettingVpn *s_vpn;

    s_vpn = nm_connection_get_setting_vpn(connection);
    if (!s_vpn) {
        s_vpn = NM_SETTING_VPN(nm_setting_vpn_new());
        nm_connection_add_setting(connection, NM_SETTING(s_vpn));
    }

    nm_setting_vpn_add_data_item(s_vpn, "service-type", ANET_VPN_SERVICE_TYPE);
}

static GObject *
get_widget(NMVpnEditor *editor)
{
    AnetVpnEditor *self = ANET_VPN_EDITOR(editor);

    if (!self->widget) {
        self->widget = g_object_ref_sink(
            gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)
        );
        gtk_widget_set_margin_start(self->widget, 12);
        gtk_widget_set_margin_end(self->widget, 12);
        gtk_widget_set_margin_top(self->widget, 12);
        gtk_widget_set_margin_bottom(self->widget, 12);

        GtkWidget *info = gtk_label_new("Please select a configuration file:");
        gtk_widget_set_halign(info, GTK_ALIGN_START);
        box_append(GTK_BOX(self->widget), info, FALSE);

        GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
        box_append(GTK_BOX(self->widget), box, FALSE);

        self->path_entry = gtk_entry_new();
        gtk_widget_set_hexpand(self->path_entry, TRUE);
        box_append(GTK_BOX(box), self->path_entry, TRUE);

        GtkWidget *button = gtk_button_new_with_label("Browse...");
        g_signal_connect(button, "clicked", G_CALLBACK(on_browse_clicked), self);
        box_append(GTK_BOX(box), button, FALSE);

        GtkWidget *edit_button = gtk_button_new_with_label("Edit...");
        g_signal_connect(edit_button, "clicked", G_CALLBACK(on_edit_clicked), self);
        box_append(GTK_BOX(box), edit_button, FALSE);

        /* Prefer config. Use service only when config is absent. */
        NMSettingVpn *s_vpn = nm_connection_get_setting_vpn(self->connection);
        if (s_vpn) {
            const char *path = nm_setting_vpn_get_data_item(s_vpn, ANET_KEY_CONFIG);

            if (path) {
                self->path_key = ANET_KEY_CONFIG;
            } else {
                path = nm_setting_vpn_get_data_item(s_vpn, ANET_KEY_SERVICE);
                if (path)
                    self->path_key = ANET_KEY_SERVICE;
            }

            if (path) {
                gtk_editable_set_text(GTK_EDITABLE(self->path_entry), path);
            }
        }

        g_signal_connect(self->path_entry,
                         "changed",
                         G_CALLBACK(on_path_changed),
                         self);

#if !GTK_CHECK_VERSION(4, 0, 0)
        gtk_widget_show_all(self->widget);
#endif
    }

    return G_OBJECT(self->widget);
}

static gboolean
update_connection(NMVpnEditor *editor, NMConnection *connection, GError **error)
{
    AnetVpnEditor *self = ANET_VPN_EDITOR(editor);
    NMSettingVpn *s_vpn;
    const char *path;

    s_vpn = nm_connection_get_setting_vpn(connection);
    if (!s_vpn) {
        s_vpn = NM_SETTING_VPN(nm_setting_vpn_new());
        nm_connection_add_setting(connection, NM_SETTING(s_vpn));
    }

    nm_setting_vpn_add_data_item(s_vpn, "service-type", ANET_VPN_SERVICE_TYPE);

    path = gtk_editable_get_text(GTK_EDITABLE(self->path_entry));
    if (path && *path != '\0') {
        if (g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
            nm_setting_vpn_remove_data_item(s_vpn, self->path_key);
            nm_setting_vpn_add_data_item(s_vpn, self->path_key, path);
        } else {
            g_set_error(error, NM_VPN_PLUGIN_ERROR, NM_VPN_PLUGIN_ERROR_BAD_ARGUMENTS,
                        "The specified configuration file does not exist or is not a regular file.");
            return FALSE;
        }
    } else {
        g_set_error(error, NM_VPN_PLUGIN_ERROR, NM_VPN_PLUGIN_ERROR_BAD_ARGUMENTS,
                    "A configuration file must be specified.");
        return FALSE;
    }

    return TRUE;
}

static void
anet_vpn_editor_interface_init(NMVpnEditorInterface *iface)
{
    iface->get_widget = get_widget;
    iface->update_connection = update_connection;
}

static void
anet_vpn_editor_init(AnetVpnEditor *self)
{
    self->connection = NULL;
    self->widget = NULL;
    self->path_entry = NULL;
    self->path_key = ANET_KEY_CONFIG;
}

static void
anet_vpn_editor_dispose(GObject *object)
{
    AnetVpnEditor *self = ANET_VPN_EDITOR(object);

    g_clear_object(&self->connection);
    self->path_entry = NULL;
    g_clear_object(&self->widget);

    G_OBJECT_CLASS(anet_vpn_editor_parent_class)->dispose(object);
}

static void
anet_vpn_editor_class_init(AnetVpnEditorClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS(klass);
    object_class->dispose = anet_vpn_editor_dispose;
}

NMVpnEditor *
anet_vpn_editor_new(NMConnection *connection, GError **error)
{
    AnetVpnEditor *self;

    self = g_object_new(ANET_TYPE_VPN_EDITOR, NULL);
    if (!self) {
        g_set_error(error, NM_VPN_PLUGIN_ERROR, NM_VPN_PLUGIN_ERROR_FAILED,
                    "Failed to create editor object");
        return NULL;
    }

    self->connection = g_object_ref(connection);

    return NM_VPN_EDITOR(self);
}

G_MODULE_EXPORT NMVpnEditor *
nm_vpn_editor_factory_anet(NMConnection *connection, GError **error)
{
    return anet_vpn_editor_new(connection, error);
}
