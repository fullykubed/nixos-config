# Helper functions for building disko device configurations.
let
  # A = 65 in ASCII; number 1 -> "A", 2 -> "B", etc.
  numToLetter = n: builtins.substring (n - 1) 1 "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
in
{
  # mkBootPartition :: int -> attrset
  # Creates a standard 4G FAT32 EFI partition for the given boot slot number.
  #   mkBootPartition 1  -> label "EFI_A", mountpoint "/boot1"
  #   mkBootPartition 2  -> label "EFI_B", mountpoint "/boot2"
  mkBootPartition = n: {
    size = "4G";
    type = "EF00";
    label = "EFI_${numToLetter n}";
    content = {
      type = "filesystem";
      format = "vfat";
      mountpoint = "/boot${toString n}";
      mountOptions = [ "nofail" ];
    };
  };
}
