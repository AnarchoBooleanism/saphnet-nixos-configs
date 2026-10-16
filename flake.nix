{
  description = "Config file for all Saphnet machines running NixOS";
  
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    # disko: For setting up disks automatically
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # sops-nix: For secrets
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence: For keeping NixOS immutable
    impermanence.url = "github:Nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    } @ inputs: let
      inherit (self) outputs;
      versionLock = nixpkgs.lib.importTOML ./version-lock.toml;

      qmDisk = id: "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi${toString id}";
      standardDualDiskModule = import modules/disko-types/impermanence-btrfs-split-hostzfs.nix {
        rootDevice = qmDisk 0;
        dataDevice = qmDisk 1;
      };
    in {
      # Configuration for NixOS itself
      # nix run github:nix-community/nixos-anywhere -- \
      # --flake .#<INSTANCE_NAME> \
      # --generate-hardware-config nixos-generate-config ./instances/INSTANCE_NAME/hardware-configuration.nix \
      # --target-host root@<IP ADDRESS/HOSTNAME>
      nixosConfigurations = {
        "control-server" = nixpkgs.lib.nixosSystem { # Control server for Komodo
          specialArgs = {inherit inputs outputs versionLock;};
          modules = [
            # Config-specific files
            instances/control-server/hardware-configuration.nix
            standardDualDiskModule
            (import machines/control-server/configuration.nix {
              secretsFile = "${./instances/control-server/secrets.enc.yaml}"; 
              instanceValues = nixpkgs.lib.importTOML "${./instances/control-server/instance-values.toml}"; 
              constantsValues = nixpkgs.lib.importTOML "${./constants/homelab-constants-values.toml}"; 
            })
          ];
        };
        "dev-server" = nixpkgs.lib.nixosSystem { # Development server
          specialArgs = {inherit inputs outputs versionLock;};
          modules = [
            # Config-specific files
            instances/dev-server/hardware-configuration.nix
            (import modules/disko-types/btrfs-subvolumes-separate-home-hostzfs.nix {
              rootDevice = qmDisk 0;
              dataDevice = qmDisk 1;
            }) # Need to set device name here
            (import machines/dev-server/configuration.nix {
              secretsFile = "${./instances/dev-server/secrets.enc.yaml}"; 
              instanceValues = nixpkgs.lib.importTOML "${./instances/dev-server/instance-values.toml}"; 
              constantsValues = nixpkgs.lib.importTOML "${./constants/homelab-constants-values.toml}"; 
            })
          ];
        };
        "docker-host-core" = nixpkgs.lib.nixosSystem { # Docker host for reverse proxy and various web services
          specialArgs = {inherit inputs outputs versionLock;};
          modules = [
            # Config-specific files
            instances/docker-host-core/hardware-configuration.nix
            standardDualDiskModule
            (import machines/docker-host/configuration.nix {
              secretsFile = "${./instances/docker-host-core/secrets.enc.yaml}"; 
              instanceValues = nixpkgs.lib.importTOML "${./instances/docker-host-core/instance-values.toml}"; 
              constantsValues = nixpkgs.lib.importTOML "${./constants/homelab-constants-values.toml}"; 
            })
          ];
        };
        "docker-host-pve3" = nixpkgs.lib.nixosSystem { # Docker host on node pve3
          specialArgs = {inherit inputs outputs versionLock;};
          modules = [
            # Config-specific files
            instances/docker-host-pve3/hardware-configuration.nix
            modules/system-extras/intel-arc-gpu.nix # Since the target system has an Intel Arc A310
            standardDualDiskModule
            (import machines/docker-host/configuration.nix {
              secretsFile = "${./instances/docker-host-pve3/secrets.enc.yaml}"; 
              instanceValues = nixpkgs.lib.importTOML "${./instances/docker-host-pve3/instance-values.toml}"; 
              constantsValues = nixpkgs.lib.importTOML "${./constants/homelab-constants-values.toml}"; 
            })
          ];
        };
        "docker-host-pve4" = nixpkgs.lib.nixosSystem { # Docker host on node pve4
          specialArgs = {inherit inputs outputs versionLock;};
          modules = [
            # Config-specific files
            instances/docker-host-pve4/hardware-configuration.nix
            standardDualDiskModule
            (import machines/docker-host/configuration.nix {
              secretsFile = "${./instances/docker-host-pve4/secrets.enc.yaml}"; 
              instanceValues = nixpkgs.lib.importTOML "${./instances/docker-host-pve4/instance-values.toml}"; 
              constantsValues = nixpkgs.lib.importTOML "${./constants/homelab-constants-values.toml}"; 
            })
          ];
        };
        "vpn-server-1" = nixpkgs.lib.nixosSystem { # Server to connect to as a VPN node
          specialArgs = {inherit inputs outputs versionLock;};
          modules = [
            # Config-specific files
            instances/vpn-server-1/hardware-configuration.nix
            standardDualDiskModule
            (import machines/vpn-server/configuration.nix {
              secretsFile = "${./instances/vpn-server-1/secrets.enc.yaml}"; 
              instanceValues = nixpkgs.lib.importTOML "${./instances/vpn-server-1/instance-values.toml}"; 
              constantsValues = nixpkgs.lib.importTOML "${./constants/homelab-constants-values.toml}"; 
            })
          ];
        };
      };
    };
}
