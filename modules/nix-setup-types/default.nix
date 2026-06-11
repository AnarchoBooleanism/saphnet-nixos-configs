# Thanks to https://www.reddit.com/r/NixOS/comments/1m6y9eh/comment/n4pty1e/
# Base Nix (package manager) setup
{
  inputs,
  lib,
  ...
}: {
  nixpkgs.config.allowUnfree = true;

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes pipe-operators";
      # Opinionated: disable global registry
      flake-registry = "";
      # The VM disks don't have too much space, so we need to save wherever we can
      auto-optimise-store = true;
    };
    
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

    # Again, the VM disks don't have too much space, so conservation is important
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d"; # Keep up to 30 days, don't need too much
    };
  };
}