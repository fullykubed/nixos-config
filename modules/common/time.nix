{ pkgs, ... }:
{
  services.timesyncd = {
    enable = false;
  };

  services.chrony = {
    enable = true;

    extraFlags = [

    ];
    # Enable seccomp filter for chronyd (-F 1) and reload server history on
    # restart (-r). The -r flag is added to match GrapheneOS's original
    # chronyd configuration.

    enableRTCTrimming = false;
    # Disable 'rtcautotrim' so that 'rtcsync' can be used instead. Either
    # this or 'rtcsync' must be disabled to complete a successful rebuild,
    # or an error will be thrown due to these options conflicting with
    # eachother.

    servers = [ ];
    # Since servers are declared by the fetched chrony config, set the
    # NixOS option to [ ] to prevent the default values from interfering.

    initstepslew.enabled = false;
    # Initstepslew "is deprecated in favour of the makestep directive"
    # according to:
    # https://chrony-project.org/doc/4.6/chrony.conf.html#initstepslew.
    # The fetched chrony config already has makestep enabled, so
    # initstepslew is disabled (it is enabled by default).

    # Configuration with NTS-enabled time servers
    extraConfig = ''
      server time.cloudflare.com iburst nts
      server ntppool1.time.nl iburst nts
      server nts.netnod.se iburst nts
      server ptbtime1.ptb.de iburst nts
      server time.dfm.dk iburst nts
      server time.cifelli.xyz iburst nts

      minsources 3
      authselectmode require

      # EF
      dscp 46

      driftfile /var/lib/chrony/drift
      dumpdir /var/lib/chrony
      ntsdumpdir /var/lib/chrony

      leapseclist ${pkgs.tzdata}/share/zoneinfo/leap-seconds.list
      makestep 1.0 3

      rtconutc
      rtcsync

      cmdport 0

      noclientlog
    '';
    # Override the leapseclist path with the NixOS-compatible path to
    # leap-seconds.list using the tzdata package. This is necessary because
    # NixOS doesn't use standard FHS paths like /usr/share/zoneinfo.
  };
}
