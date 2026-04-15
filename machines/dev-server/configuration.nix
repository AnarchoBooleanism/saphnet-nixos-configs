# NOTE: You need to set these sops-nix variables first before deploying!
# - main-password-hashed: Hash of the login password (pass this into "nix run nixpkgs#mkpasswd -- -m sha-512 -s")
# - tailscale-auth-key: Authentication key for Tailscale
# - <USER>-password-hashed: For each user defined in instance-values.toml, have a hash of the user's login password

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
    (import (../.. + "/modules/sops-nix-types/default.nix") {
      inherit inputs secretsFile;
    })
    (../.. + "/modules/virtualization/docker.nix")
    (../.. + "/modules/virtualization/docker-extras/autoprune.nix")
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
    } // lib.attrsets.mapAttrs' (name: value: lib.attrsets.nameValuePair (name + "-password-hashed") { # Auto-generate secrets names based on TOML file
        neededForUsers = true; # Setting so that password works properly
      }
    ) instanceValues.users;
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
      openssh.authorizedKeys.keys = constantsValues.authorized-keys; # Deployment key for accessibility
      extraGroups = ["wheel" "docker" "video" "render"];
    };
  
    root.hashedPassword = "!"; # Disable root login
  } // lib.attrsets.mapAttrs (name: value: { # Allows us to define users in TOML file
      hashedPasswordFile = config.sops.secrets."${name}-password-hashed".path;
      isNormalUser = true;
      openssh.authorizedKeys.keys = value.authorized-keys;
      extraGroups = ["wheel" "docker"];
    }
  ) instanceValues.users;

  time.timeZone = constantsValues.timezone;

  environment.systemPackages = with pkgs; [
    # Important tools to have for dev server, does overlap with proxmox-vm Module
    # System monitoring
    btop
    dmidecode
    htop
    iotop
    ncdu
    nvtopPackages.full
    # Network monitoring, diagnosis
    bind
    dnsutils
    ethtool
    iputils
    net-tools
    nmap
    tcpdump
    vnstat
    # Development
    ansible
    cargo
    distrobox
    elmPackages.nodejs
    gcc
    gnumake
    git
    jdk25_headless
    kubernetes
    perl
    pipx
    python314
    python314Packages.pip
    qemu_full
    rustc
    # User tools
    age
    curl
    dool
    emacs
    fzf
    gnupg
    jq
    less
    nano
    p7zip
    tmux
    rar
    rclone
    rsync
    screen
    sops
    stow
    unrar
    vim
    wget
    zsh
    # Fun
    fastfetch
    hyfetch
    # Miscellaneous
    bash-completion
    man-db
    nfs-utils
    pciutils
    samba
  ];

  system.stateVersion = "${versionLock.state-version}";
}