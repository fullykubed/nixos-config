{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (_final: _prev: {
      # Perl 5.42.0 from unstable - fixes CVE-2024-56406
      # CVE-2024-56406 (8.4 High): Heap buffer overflow in tr// operator
      # Affects 5.34-5.40 and dev versions through 5.41.10, fixed in 5.42.0
      # See: https://nvd.nist.gov/vuln/detail/CVE-2024-56406
      #
      # NOTE: Must override perl540 and perlPackages too, because in nixpkgs 25.11:
      #   perl = perl540;
      #   perlPackages = perl540Packages;  (hardcoded, doesn't follow perl override)
      # Without these, packages using perlPackages or perl540 directly still get 5.40.0
      inherit (nixpkgs-unstable) perl;
      perl540 = nixpkgs-unstable.perl; # Replace versioned perl with 5.42
      perlPackages = nixpkgs-unstable.perl5Packages; # Use unstable perl modules
      perl540Packages = nixpkgs-unstable.perl5Packages; # Stable's perl540Packages -> unstable's perlPackages
    })
  ];
}
