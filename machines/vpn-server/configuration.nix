# NOTE: You need to set these sops-nix variables first before deploying!
# - main-password-hashed: Hash of the login password (pass this into "nix run nixpkgs#mkpasswd -- -m sha-512 -s")
# - tailscale-auth-key: Authentication key for Tailscale

{ # Custom args
  secretsFile ? throw "Set this to the path of your instance's secrets file",
  instanceValues ? throw "Set this to the contents of your instance's values file",
  constantsValues ? throw "Set this to the contents of a constants values file",
}:
{
  inputs,
  config,
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
  versionLock = lib.importTOML ./version-lock.toml;
in
{
  imports = [
    # NixOS modules
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    # Internal modules
    (../.. + "/modules/nix-setup-types/default.nix")
    (../.. + "/modules/system-types/proxmox-vm.nix")
    (../.. + "/modules/impermanence-types/default.nix")
    (import (../.. + "/modules/sops-nix-types/default-impermanence.nix") {
      inherit inputs secretsFile;
    })
    (import (../.. + "/modules/networking/tailscale.nix") {
      inherit inputs secretsFile;
    })
  ];

  sops = {
    secrets = {
      main-password-hashed = {
        neededForUsers = true; # Setting so that password works properly
      };
      tailscale-auth-key = {};
    };
  };

  environment.persistence."/persist" = { # Additional files to base ones
    directories = [
      "/var/lib/tailscale/" # Tailscale
    ];
    files = [];
  };

  networking.hostName = instanceValues.hostname;
  networking.domain = instanceValues.domain;
  networking.defaultGateway = constantsValues.networking.gateway;
  networking.nameservers = constantsValues.networking.nameservers;
  networking.interfaces."${instanceValues.networking.interface}" = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = instanceValues.networking.ip-address;
        prefixLength = instanceValues.networking.ip-prefix-length;
      }
    ];
  };

  users.mutableUsers = false; # Since we're handling passwords with sops-nix
  users.users = {
    "${constantsValues.default-username}" = {
      hashedPasswordFile = config.sops.secrets.main-password-hashed.path;
      isNormalUser = true;
      openssh.authorizedKeys.keys = constantsValues.authorized-keys; # Deployment key for accessibility
      extraGroups = ["wheel"];
    };

    root.hashedPassword = "!"; # Disable root login
  };

  time.timeZone = constantsValues.timezone;

  system.stateVersion = "${versionLock.state-version}";
}