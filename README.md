# saphnet-nixos-configs
A set of NixOS configuration files for various machines/VMs within the Sapphic Homelab/Home Server (organized by branch)

Hello! These are the various configuration files for the NixOS machines within the Sapphic Homelab/Home Server, with different sections for instances (the values for actual machines), machines (blueprints for actual machines, to be instantiated), and the different modules that the machines use. These are designed to be deployed to virtual (and bare-metal) machines using `nixos-anywhere` and `nixos-rebuild`, indirectly through Ansible ([see my Ansible playbook](https://github.com/AnarchoBooleanism/saphnet-ansible-playbook)).

It is recommended that you use [nixos-cloud-init-installer](https://github.com/AnarchoBooleanism/nixos-cloud-init-installer), in combination with a cloud-init drive, as a driver to deploy these configuration files with `nixos-anywhere`.

The configuration files are inspired by god464's [flake](https://github.com/god464/flake), Swarsel's [.dotfiles](https://github.com/Swarsel/.dotfiles/), Misterio77's [nix-starter-configs](https://github.com/Misterio77/nix-starter-configs), and nix-community's [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples), among many, many other NixOS configuration repositories.

### Index of contents (of the documentation):
- [Explanation of the repository](docs/explanation.md)
- [Guide for creating a Module](docs/module-howto.md)
- [Guide for creating a Machine](docs/machine-howto.md)
- [Guide for creating an Instance](docs/instance-howto.md)
- [Guide for deploying an Instance](docs/deployment-howto.md)
- [Style guide for writing and structuring configuration files](docs/style-guide.md)
- Machine-specific write-ups
  - [control-server (first and most important machine to deploy!)](machines/control-server/README.md)

Here are some useful commands to use when writing and deploying to machines:

- For editing SOPS secrets files: `EDITOR=nano nix run nixpkgs#sops -- edit ./machines/SERVER-NAME/secrets.yaml`
    - NOTE: Make sure your age private key is in `~/.config/sops/age/key.txt`!
- For doing fresh installs: `nix run github:nix-community/nixos-anywhere -- --flake .#generic --generate-hardware-config nixos-generate-config ./hardware-configuration.nix --target-host root@<IP ADDRESS/HOSTNAME>`

### Notes
- Make sure that tabs are 2 spaces!
- Make sure any .sh files are marked executable

Useful links that have helped with the creation of this repository:
- https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix/
- https://bmcgee.ie/posts/2022/11/getting-nixos-to-keep-a-secret/

TODO: Have instructions on how to create your own machine config, and have it instantiatable

TODO: Have instructions on how to instantiate a specific machine config

TODO: Have instructions on how to actually deploy a machine, from creating SSH keys and other things, to creating secrets, and finally doing stuff