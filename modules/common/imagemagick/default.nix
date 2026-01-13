{
  lib,
  ...
}:
{
  # ===========================================================================
  # Version Options
  # ===========================================================================
  # The overlay in flake.nix uses these versions directly from the versions
  # attribute set (imported before module evaluation), not config.versions.*
  options.versions = {
    imagemagick = lib.mkOption {
      type = lib.types.str;
      description = "Version of ImageMagick (pinned for gscan2pdf compatibility)";
    };
    imagemagickSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for ImageMagick";
    };
  };
}
