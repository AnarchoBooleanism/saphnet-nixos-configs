# Impermanence settings for Tailscale
# NOTE: Make sure that an impermanence-types Modules is imported in your same configuration!
{
  ...
}:
{
  # We want to avoid having to reauthenticate with the key every single time, between reboots
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/tailscale"
    ];
  };
}