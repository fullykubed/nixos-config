# currently, there is some friction between sway and gtk:
# https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
# the suggested way to set gtk settings is with gsettings
# for gsettings to work, we need to tell it where the schemas are
# using the XDG_DATA_DIR environment variable
# run at the end of sway config
{ pkgs, ... }: (pkgs.writeShellScriptBin "configure-gtk"
  (
    let
      schema = pkgs.gsettings-desktop-schemas;
      datadir = "${schema}/share/gsettings-schemas/${schema.name}";
    in
    ''
      export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
      gnome_schema=org.gnome.desktop.interface
      gsettings set $gnome_schema gtk-theme 'Dracula'
    ''
  )
)


