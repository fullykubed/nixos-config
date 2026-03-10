# Theming

All theming is handled by [Stylix](https://github.com/nix-community/stylix), which applies a consistent color scheme, fonts, and cursor across the entire system. Do not hardcode colors or font names in modules — use Stylix's base16 color values instead.

## Central configuration

The theme is defined in `modules/common/theme/default.nix`. It sets:

- **Color scheme** — a base16 scheme
- **Fonts** — monospace, sans-serif, serif, emoji, and sizes
- **Cursor** — package, name, and size

Stylix is enabled for both the system and Home Manager, so most applications pick up the theme automatically.

## Using colors in modules

When a module needs to reference colors directly (e.g. for custom config that Stylix doesn't auto-style), use `config.lib.stylix.colors`:

```nix
{ config, ... }:
{
  # Access base16 colors with hash prefix
  home-manager.users.${config.username} = {
    programs.my-app.settings = {
      background = config.lib.stylix.colors.withHashtag.base00;  # default background
      foreground = config.lib.stylix.colors.withHashtag.base05;  # default foreground
      accent = config.lib.stylix.colors.withHashtag.base0D;      # functions, headings
    };
  };
}
```

The base16 palette slots:

| Slot | Role |
|------|------|
| `base00` | Default background |
| `base01` | Lighter background (status bars) |
| `base02` | Selection background |
| `base03` | Comments, line highlighting |
| `base04` | Dark foreground (status bars) |
| `base05` | Default foreground |
| `base06` | Light foreground |
| `base07` | Light background |
| `base08` | Variables, diff deleted |
| `base09` | Integers, constants |
| `base0A` | Classes, search highlight |
| `base0B` | Strings, diff inserted |
| `base0C` | Regex, escape characters |
| `base0D` | Functions, headings |
| `base0E` | Keywords, diff changed |
| `base0F` | Deprecated, embedded tags |

## Disabling Stylix for specific targets

Some applications need custom styling. Disable Stylix for a specific target in the theme module:

```nix
home-manager.users.${config.username} = {
  stylix.targets.tmux.enable = false;
};
```
