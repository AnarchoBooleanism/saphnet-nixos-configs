# Impermanence settings for Docker
# NOTE: Make sure that an impermanence-types Modules is imported in your same configuration!
{
  ...
}:
{
  # The rest of Docker's data (e.g. images) can simply be persisted between reboots
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/docker"
    ];
  };

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/docker/volumes"
    ];
  };
}