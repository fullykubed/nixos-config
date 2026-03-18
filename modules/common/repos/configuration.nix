{
  repos.nixos-config = {
    url = "git@github.com:fullykubed/nixos-config.git";
    path = "nixos-config";
    branch = "main";
    tmuxSession = "nixos-config";
    direnv = true;
  };
}
