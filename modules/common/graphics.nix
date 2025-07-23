{ config, ... }:
{
  # Enable open gl
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
