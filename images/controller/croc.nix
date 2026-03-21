{ pkgs, ... }:
{
  systemd.services.croc = {
    description = "Croc relay server";
    after = [ "cloud-init.service" ];
    wants = [ "cloud-init.service" ];
    wantedBy = [ "multi-user.target" ];
    environment.HOME = "/root";
    path = [ pkgs.croc ];
    script = ''
      pass=$(cat /run/croc-relay-password)
      exec croc --pass "$pass" relay --ports 19009,19010,19011,19012,19013
    '';
  };

  networking.firewall.allowedTCPPorts = [
    19009
    19010
    19011
    19012
    19013
  ];
}
