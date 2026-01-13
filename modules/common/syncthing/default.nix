{ config, ... }:

let
  devices = {
    "zenbook" = {
      id = "5AO3FST-KPWRUCV-ASJQLMI-BHY2LEY-X5LKA7I-UWEZOZT-MSKLFFS-45SBFAI";
    };
    "bambee_mac" = {
      id = "ZXFSFRZ-TV3AZHA-AWMPGNN-GNNPY2P-UABF33O-AE2KH4U-CR6OKF4-2JPY4QU";
    };
    "pixel6" = {
      id = "C475M4E-JGQ6PNA-PQD5WTV-OQRBRXW-AGQO6ZI-WS4JO6U-DSJR7OK-T2RWIQN";
    };
    "jack-mini-pc" = {
      id = "PO336DS-TESQS3N-YKFS4RY-YEDAGJD-S2GSLOT-XRAQTGX-LQPOIBP-R5FTYAC";
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
      inherit devices;
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
