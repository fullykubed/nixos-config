{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    sqlite
  ];

  environment.sessionVariables = {
    # Used for getting the shared object file for working with sqlite databases
    SQLITE_SO_PATH = "${pkgs.sqlite.out}/lib/libsqlite3.so";
  };
}
