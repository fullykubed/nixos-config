{ config, ... }:

let
  devices = {
    "zenbook" = {
      id = "5AO3FST-KPWRUCV-ASJQLMI-BHY2LEY-X5LKA7I-UWEZOZT-MSKLFFS-45SBFAI";
    };
    "bambee_mac" = {
      id = "CRVU545-X32YNWD-PRMIT6Z-XILLZ4C-F433UCH-VNG7SBI-CCFZAGS-UU3KNAM";
    };
    "pixel6" = {
      id = "C475M4E-JGQ6PNA-PQD5WTV-OQRBRXW-AGQO6ZI-WS4JO6U-DSJR7OK-T2RWIQN";
    };
  };
  allDevices = builtins.attrNames devices;
in
{
  services.syncthing = {
    enable = true;
    user = config.username;
    group = config.username;
    dataDir = config.homeDir;
    systemService = true;
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = devices;
      folders = {
        "keepass" = {
          id = "keepass";
          label = "Keepass";
          path = "${config.homeDir}/keepass";
          devices = allDevices;
        };
        "pixel_camera" = {
          id = "pixel_6_jgkv-photos";
          label = "S9_Camera";
          path = "${config.homeDir}/camera/pixel";
          devices = [ "pixel6" ];
          type = "receiveonly";
        };
      };
    };
  };
}
