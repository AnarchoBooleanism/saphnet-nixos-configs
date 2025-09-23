{
  description = "Sample config file for Saphnet machines"; # SETME: Description
  
  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-XX.XX"; # SETME: Version

    # Home Manager
    home-manager.url = "github:nix-community/home-manager/release-XX.XX"; # SETME: Version
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      home-manager
      ...
    } @ inputs: let
      inherit (self) outputs;
    in {
      # Configuration for NixOS itself
      # nixos-anywhere --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations = {
        "SETME-HOSTNAME" = nixpkgs.lib.nixosSystem { # SETME: Hostname
          specialArgs = {inherit inputs outputs;};
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./configuration.nix
            ./hardware-configuration.nix
          ];
      };
      };

      homeConfigurations = {
        # SETME: Username, hostname
        "SETME-USERNAME@SETME-HOSTNAME" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = {inherit inputs outputs;};
          modules = [
            # > Our main home-manager configuration file <
            ./home-manager/home.nix
          ];
        };
    };
    };
}
