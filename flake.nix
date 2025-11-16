{
  description = "Config file for all Saphnet machines running NixOS";
  
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # disko: For setting up disks automatically
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # sops-nix: For secrets
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence: For keeping NixOS immutable
    impermanence.url = "github:Nix-community/impermanence";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    } @ inputs: let
      inherit (self) outputs;
    in {
      # Configuration for NixOS itself
      # nixos-anywhere --flake .#config-name --generate-hardware-config nixos-generate-config instances/<INSTANCE_NAME>/hardware-configuration.nix <hostname> # TODO: Update for secrets stuff
      nixosConfigurations = {
        "control-server" = nixpkgs.lib.nixosSystem { # Control server for Komodo
          specialArgs = {inherit inputs outputs;};
          system = "x86_64-linux";
          modules = [
            # Config-specific files
            instances/control-server/hardware-configuration.nix
            (import modules/disko-types/impermanence-btrfs.nix { device = "/dev/sda"; }) # Need to set device name here
            (import machines/control-server/configuration.nix {
              secretsFile = "${./instances/control-server/secrets.yaml}"; 
              instanceValues = builtins.fromTOML (builtins.readFile "${./instances/control-server/instance-values.toml}"); 
              constantsValues = builtins.fromTOML (builtins.readFile "${./constants/homelab-constants-values.toml}"); 
            })
          ];
        };
      };
    };
}
