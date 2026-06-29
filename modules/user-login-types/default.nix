# Default setup, with a default user to log in with, and a dedicated CI/CD user for automation purposes
# This assumes you have sops-nix set up!

# Even with this module imported, you are still able to configure other users (under users.users) and
# their secrets (under sops.secrets) in your Machine's configuration!

# NOTE: Make sure, in your secrets file, that you have a "main-password-hashed" entry.
#       (You can create this with "nix run nixpkgs#mkpasswd -- -m sha-512 -s")
# To add this Module, in your imports section, import this file like this:
# (import (../.. + "/modules/user-login-types/default.nix") {
#   # Note: This expects you to have something for the "main-password-hashed" sops-nix secret
#   inherit inputs secretsFile;
#   defaultUsername = constantsValues.default-username;
#   authorizedKeys = constantsValues.authorized-keys;
#   cicdUsername = constantsValues.cicd-username;
#   cicdAuthorizedKeys = instanceValues.cicd-authorized-keys;
# })
{
  defaultUsername, # Typically "saphnet-user"
  authorizedKeys,
  cicdUsername, # Typically "cicd"
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
        {
          # TODO: NOPASSWD on ALL commands is dangerous, but we kind of need this for our Ansible
          # playbook, so find ways to make this more secure! So whether separate Ansible keys for
          # each instance, auto-rotation, or whatnot.
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}