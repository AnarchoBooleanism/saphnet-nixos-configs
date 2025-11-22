# Tailscale config, with space for different names and such
# NOTE: Make sure, in your secrets file, that you have a "tailscale-auth-key" entry for your Tailscale auth key.
# NOTE: If using Impermanence, make sure to have /var/lib/tailscale as persistent.
{
  config,
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
    authKeyFile = "${config.sops.secrets.tailscale-auth-key.path}";
  };

  # Configure firewall (if relevant)
  networking.firewall.allowedUDPPorts = [ tailscalePort ];
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}