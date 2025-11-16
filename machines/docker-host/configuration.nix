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
    (../.. + "/modules/virtualization/docker.nix")
    (../.. + "/modules/virtualization/docker-extras/autoprune.nix")
  ];

  sops = {
    secrets = {
      main-password-hashed = {
        neededForUsers = true; # Setting so that password works properly
      };
      komodo-passkey = {};
    };
  };

  environment.persistence."/persist" = { # Additional files to base ones
    directories = [
      "/var/lib/docker/" # Docker
      "/etc/komodo" # Komodo
    ];
    files = [

    ];
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

  users.users = {
    "${constantsValues.default-username}" = {
      hashedPasswordFile = config.sops.secrets.main-password-hashed.path;
      isNormalUser = true;
      openssh.authorizedKeys.keys = instanceValues.authorized-keys; # Deployment key for accessibility
      extraGroups = ["wheel" "docker"];
    };
  
    root.hashedPassword = "!"; # Disable root login
  };

  time.timeZone = constantsValues.timezone;
  
  systemd.services."komodo-periphery" = {
    description = "Periphery server for Komodo";

    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = [
      "docker.service" # Docker needed, of course
      "docker.socket"
      "sops-nix.service" # Need to get secrets
      "network-online.target" # Need working internet to get things
    ];

    environment = {
      PERIPHERY_ROOT_DIRECTORY = "/etc/komodo";
      # Other secret env variables that need to be passed in directly are listed in script 
    };

    script = with pkgs; ''
      # Waiting for the network to actually come online
      sleep 5

      # Dynamically export variables from secrets files
      export KOMODO_PASSKEY=$(cat ${config.sops.secrets.komodo-passkey.path})

      ${pkgs.docker}/bin/docker compose -p komodo -f ${./komodo-periphery/periphery.compose.yaml} up
    '';
  };

  system.stateVersion = "${versionLock.state-version}";
}