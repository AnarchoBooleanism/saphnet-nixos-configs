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
  versionLock,
  ...
}:
{
  imports = [
    # NixOS modules
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    # Internal modules
    (../.. + "/modules/nix-setup-types/default.nix")
    (../.. + "/modules/system-types/proxmox-vm.nix")
    (import (../.. + "/modules/user-login-types/default.nix") {
      # Note: This expects you to have something for the "main-password-hashed" sops-nix secret
      inherit inputs secretsFile;
      defaultUsername = constantsValues.default-username;
      authorizedKeys = constantsValues.authorized-keys;
      cicdUsername = constantsValues.cicd-username;
      cicdAuthorizedKeys = instanceValues.cicd-authorized-keys;
    })
    (../.. + "/modules/impermanence-types/default.nix")
    (import (../.. + "/modules/sops-nix-types/default-impermanence.nix") {
      inherit inputs secretsFile;
    })
    (import (../.. + "/modules/networking/tailscale.nix") {
      inherit inputs secretsFile;
      routesAdvertised = [ constantsValues.networking.subnet ];
      isExitNode = true;
    })
  ];

  sops = {
    secrets = {
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

  time.timeZone = constantsValues.timezone;

  system.stateVersion = "${versionLock.state-version}";
}