# Tailscale config, with space for different names and such
# NOTE: Make sure, in your secrets file, that you have a "tailscale-auth-key" entry for your Tailscale auth key.
# NOTE: If using Impermanence, make sure to have /var/lib/tailscale as persistent.
# To add this Module, in your imports section, import this file like this:
# (import (../.. + "/modules/networking/tailscale.nix") {
#   inherit inputs secretsFile;
#   routesAdvertised = [ constantsValues.networking.subnet ]; # Optional
#   isExitNode = true; # Optional
# })
{
  routesAdvertised ? [], # List of subnet routes to advertise, e.g. 192.168.8.0/23, optional
  isExitNode ? false, # Whether to advertise as exit node, optional
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  tailscalePort = 41641; # Set Tailscale port here, default is 41641
in
{
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  # services.tailscale.enable = true;
  # services.tailscale.port = tailscalePort;
  services.tailscale = {
    enable = true;
    port = tailscalePort;
    authKeyFile = config.sops.secrets.tailscale-auth-key.path;
    useRoutingFeatures = "both"; # Ensure connectivity in multiple cases
    extraUpFlags = (lib.optional (routesAdvertised != [])
      "--advertise-routes=${lib.concatStringsSep "," routesAdvertised}") ++
      (lib.optional (isExitNode) "--advertise-exit-node");
    
  };

  # Configure firewall (if relevant)
  networking.firewall.allowedUDPPorts = [ tailscalePort ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}