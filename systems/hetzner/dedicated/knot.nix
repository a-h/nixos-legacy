{ pkgs, ... }: {
  # To enable this machine to run its own DNS, set an NS record in the domain registrar.
  # e.g. cmptr.cc -> 65.109.61.232
  services.knot = {
    enable = true;

    settings = {
      server = {
        listen = [ "0.0.0.0@53" "::@53" ];
      };

      zone = [
        {
          domain = "cmptr.cc";
          file = "/etc/knot/zones/cmptr.cc.zone";
        }
      ];
    };
  };

  environment.etc."knot/zones/cmptr.cc.zone".text = ''
    $ORIGIN cmptr.cc.
    $TTL 3600

    @ IN SOA ns1.cmptr.cc. hostmaster.cmptr.cc. (
        2026011401 ; serial
        3600       ; refresh
        900        ; retry
        1209600    ; expire
        3600       ; minimum
    )

      IN NS  ns1.cmptr.cc.

    ns1   IN A 65.109.61.232
    @     IN A 65.109.61.232
    minio IN A 65.109.61.232
  '';

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  environment.systemPackages = [
    # Run dig @127.0.0.1 minio.cmptr.cc to check if the DNS server is working.
    pkgs.dnsutils
  ];
}
