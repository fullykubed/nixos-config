# currently, there is some friction between sway and gtk:
# https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
# the suggested way to set gtk settings is with gsettings
# for gsettings to work, we need to tell it where the schemas are
# using the XDG_DATA_DIR environment variable
# run at the end of sway config
{ pkgs, ... }:
(pkgs.writeShellScriptBin "configure-gtk" (
  let
    schema = pkgs.gsettings-desktop-schemas;
    datadir = "${schema}/share/gsettings-schemas/${schema.name}";
  in
  ''
    export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
    config="$${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini"
    if [ ! -f "$config" ]; then exit 1; fi

    gnome_schema="org.gnome.desktop.interface"
    gtk_theme="$(grep 'gtk-theme-name' "$config" | sed 's/.*\s*=\s*//')"
    icon_theme="$(grep 'gtk-icon-theme-name' "$config" | sed 's/.*\s*=\s*//')"
    cursor_theme="$(grep 'gtk-cursor-theme-name' "$config" | sed 's/.*\s*=\s*//')"
    font_name="$(grep 'gtk-font-name' "$config" | sed 's/.*\s*=\s*//')"
    gsettings set "$gnome_schema" gtk-theme "$gtk_theme"
    gsettings set "$gnome_schema" icon-theme "$icon_theme"
    gsettings set "$gnome_schema" cursor-theme "$cursor_theme"
    gsettings set "$gnome_schema" font-name "$font_name"
    gsettings set $gnome_schema color-scheme "prefer-dark"
  ''
))
