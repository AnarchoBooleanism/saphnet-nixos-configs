# saphnet-nixos-configs
A set of NixOS configuration files for various machines/VMs within the Sapphic Homelab/Home Server (organized by branch)

Hello! You are currently reading the README for the main branch. This branch contains sample files that you can customize for different configurations.
For the configurations of specific machines, make sure to checkout the branch corresponding to them.
These are designed to be deployed to machines using `nixos-anywhere` and `nixos-rebuild`.

The configuration files are inspired by Misterio77's [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) and nix-community's [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples).

Here are some useful commands to use when writing and deploying to machines:

- For doing fresh installs: `nix run github:nix-community/nixos-anywhere -- --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --target-host root@<IP ADDRESS/HOSTNAME>`

### Notes
- Make sure that tabs are 2 spaces!

TODO: Learn more Nix first and really understand it