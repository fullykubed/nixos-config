{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf (config.deviceType != "remote-builder") {
  age.secrets.anthropic-api-key = {
    rekeyFile = ../../../secrets/anthropic-api-key.age;
    owner = config.username;
    group = "users";
    mode = "0400";
  };

  environment.systemPackages = [ (pkgs.callPackage ./llm-summarize { }) ];
}
