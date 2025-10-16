# saphnet-nixos-configs
A set of NixOS configuration files for various machines/VMs within the Sapphic Homelab/Home Server (organized by branch)

Hello! You are currently reading the README for the main branch. This branch contains sample files that you can customize for different configurations.
For the configurations of specific machines, make sure to checkout the branch corresponding to them.
These are designed to be deployed to machines using `nixos-anywhere` and `nixos-rebuild`.

The configuration files are inspired by Misterio77's [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs) and nix-community's [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples).

Here are some useful commands to use when writing and deploying to machines:

- For editing SOPS secrets files: `EDITOR=nano nix run nixpkgs#sops -- edit ./machines/SERVER-NAME/secrets.yaml`
    - NOTE: Make sure your age private key is in `~/.config/sops/age/key.txt`!
- For doing fresh installs: `nix run github:nix-community/nixos-anywhere -- --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --target-host root@<IP ADDRESS/HOSTNAME>`

### Notes
- Make sure that tabs are 2 spaces!
- Make sure any .sh files are marked executable

Useful links:
- https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/

TODO: Have instructions on how to create your own machine config, and have it instantiatable
TODO: Have instructions on how to instantiate a specific machine config
TODO: Have instructions on how to actually deploy a machine, from creating SSH keys and other things, to creating secrets, and finally doing stuff