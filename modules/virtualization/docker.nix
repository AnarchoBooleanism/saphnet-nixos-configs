# Docker setup, with a few settings
{
  pkgs,
  ...
} @ args:
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
}