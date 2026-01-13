{
  pkgs,
  ...
}:
let
  scripts = pkgs.stdenv.mkDerivation rec {
    pname = "custom-scripts";
    version = "1.0";

    src = ./scripts;

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin

      # Find all .sh files in the source directory
      for script in $(find ${src} -name "*.sh"); do
        script_name=$(basename $script .sh)
        cp $script $out/bin/$script_name
        chmod +x $out/bin/$script_name
      done
    '';
  };
in
{

  environment.systemPackages = [
    scripts
  ];
}
