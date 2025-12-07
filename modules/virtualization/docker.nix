# Docker setup, with a few settings
{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
  ];

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = true;
  virtualisation.docker.daemon.settings = {
    # ipv6 = true;
  };

  networking.firewall = {
    # Allow Docker bridge networks, doing this fixes connections from containers to host (e.g. Nginx Proxy Manager)
    trustedInterfaces = [ 
      "docker0" 
      "br-+" # Wildcard
    ];
  };
}