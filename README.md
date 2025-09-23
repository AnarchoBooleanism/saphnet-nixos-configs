# saphnet-nixos-configs
A set of NixOS configuration files for various machines/VMs within the Sapphic Homelab/Home Server (organized by branch)

Hello! You are currently reading the README for the main branch. This branch contains sample files that you can customize for different configurations.
For the configurations of specific machines, make sure to checkout the branch corresponding to them.
These are designed to be deployed to machines using `nixos-anywhere` and `nixos-rebuild`.

Here are some useful commands to use when writing and deploying to machines:

- For doing fresh installs: `nix run github:nix-community/nixos-anywhere -- --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --target-host root@<IP ADDRESS/HOSTNAME>`
