# Default setup, with a default user to log in with, and a dedicated CI/CD user for automation purposes
# This assumes you have sops-nix set up! TODO: Write documentation on sops secrets
{
  defaultUsername, # Typically saphnet-user
  authorizedKeys,
  cicdUsername, # Typically cicd
  cicdAuthorizedKeys,
  ...
}:
{
  config,
  ...
}:
{
  sops = {
    secrets = {
      main-password-hashed = {
        neededForUsers = true; # Setting so that password works properly
      };
    };
  };

  users.mutableUsers = false; # Since we're handling passwords with sops-nix
  users.users = {
    "${defaultUsername}" = {
      hashedPasswordFile = config.sops.secrets.main-password-hashed.path;
      isNormalUser = true;
      openssh.authorizedKeys.keys = authorizedKeys;
      extraGroups = ["wheel" "docker" "video" "render"];
    };

    "${cicdUsername}" = {
      hashedPassword = "!";
      isNormalUser = true;
      openssh.authorizedKeys.keys = cicdAuthorizedKeys;
      extraGroups = ["wheel"];
    };

    root.hashedPassword = "!"; # Disable root login
  };

  security.sudo.extraRules = [
    {
      users = ["${cicdUsername}"];
      commands = [
        # All commands needed for nixos-rebuild
        # Thanks to https://www.reddit.com/r/NixOS/comments/1ktcaqq/comment/mtt91a1/
        {
          command = "/run/current-system/sw/bin/systemd-run";
          options = ["NOPASSWD"];
        }
        {
          command = "/nix/store/*/bin/switch-to-configuration";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/nix-store";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/nix-env";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/nix-build";
          options = ["NOPASSWD"];
        }
        {
          command = ''/bin/sh -c "readlink -e /nix/var/nix/profiles/system || readlink -e /run/current-system"'';
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/nix-collect-garbage";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}