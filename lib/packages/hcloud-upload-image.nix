{
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "hcloud-upload-image";
  version = "1.3.0";
  src = fetchFromGitHub {
    owner = "apricote";
    repo = "hcloud-upload-image";
    rev = "v${version}";
    hash = "sha256-1u9tpzciYjB/EgBI81pg9w0kez7hHZON7+AHvfKW7k0=";
  };
  vendorHash = "sha256-IdOAUBPg0CEuHd2rdc7jOlw0XtnAhr3PVPJbnFs2+x4=";
  env.GOWORK = "off";
  subPackages = [ "." ];
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];
}
