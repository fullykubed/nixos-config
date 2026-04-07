{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "prek";
  version = "0.3.8";

  src = fetchFromGitHub {
    owner = "j178";
    repo = "prek";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0mddrCEGQHFm4zW5nQ7HHFK826XcYSymr9AfVd5P+eg=";
  };

  cargoHash = "sha256-YZqIx6P2nkaKaJUW6IPboiHVDlaDvPCpLMlX0swJYyU=";

  # Upstream tests require network access / repo checkouts / locale; we rely
  # on upstream CI to vet the release.
  doCheck = false;

  meta = {
    homepage = "https://github.com/j178/prek";
    description = "Better pre-commit, re-engineered in Rust";
    mainProgram = "prek";
    changelog = "https://github.com/j178/prek/releases/tag/v${finalAttrs.version}";
    license = [ lib.licenses.mit ];
  };
})
