_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Lua 5.2 security patch
      # CVE-2021-43519 (CVSS 5.5 Medium): Stack overflow in lua_resume
      # Allows DoS via crafted Lua script using nested coroutines with pcall
      # Affects Lua 5.1.0 through 5.4.4, fixed in 5.3.5 and 5.4.4+
      # Lua 5.2.4 is the last release of the 5.2 branch - no upstream fix available
      # Backported fix from: https://github.com/lua/lua/commit/74d99057a5146755e737c479850f87fd0e3b6868
      # See: https://nvd.nist.gov/vuln/detail/CVE-2021-43519
      lua5_2 = prev.lua5_2.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2021-43519.patch
        ];
      });
    })
  ];
}
