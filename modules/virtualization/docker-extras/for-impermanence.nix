# Impermanence settings for Docker
# NOTE: Make sure that an impermanence-types Modules is imported in your same configuration!
{
  ...
}:
{
  # Note that, for many Disko configs, that /var/lib/docker/volumes is handled by a separate
  # @docker-volumes subvolume, so that its data can persist between reinstalls.

  # The rest of Docker's data (e.g. images) can simply be persisted between reboots
  environment.persistence."/persist" = {
    files = [
      "/var/lib/docker"
    ];
  };
}