# Shared constants for builder configuration.
# Imported by images/builder/inactivity-monitor.nix and
# modules/common/sway/waybar/default.nix so the values stay in sync.
{
  # Number of 1-minute idle checks before the inactivity monitor destroys the
  # builder.  Keep this in sync with the TIMEOUT_CHECKS value used inside the
  # inactivity-monitor script.
  inactivityTimeoutMinutes = 15;
}
